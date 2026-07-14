//
// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation
import MSAL

/// Identifies which cross-platform SwiftUI sheet the auth flow is currently presenting. The flows
/// populate the flow-agnostic continuation closures (``onSubmitCode`` / ``onResendCode`` /
/// ``onSubmitNewPassword`` / ``onSubmitAttributes`` / ``onSelectAuthMethod``) before setting the
/// matching sheet, so the sheets stay flow-agnostic.
enum AuthSheet: String, Identifiable
{
    case verifyCode
    case newPassword
    case collectAttributes
    case selectAuthMethod

    var id: String { rawValue }
}

/// The social identity providers offered by the browser-based ("web fallback") sign-in.
enum SocialProvider: String, CaseIterable, Identifiable
{
    case google
    case facebook
    case apple
    case linkedin

    var id: String { rawValue }

    var displayName: String
    {
        switch self
        {
        case .google: return "Google"
        case .facebook: return "Facebook"
        case .apple: return "Apple"
        case .linkedin: return "LinkedIn"
        }
    }
}

/// Drives every Native Auth flow behind the single unified SwiftUI authentication screen — sign-in
/// (password **or** email one-time-code), sign-up, self-service password reset, the browser / social
/// "web fallback", and post-sign-in protected-API access. It supports both the granular **V1** API
/// and the server-driven **V2** per-state-delegate API, chosen by ``useV2Api``; either API can also
/// be driven from Objective-C (``useObjCDriver``) to prove the public API is Obj-C-consumable.
///
/// The view model is fully SwiftUI/AppKit-agnostic (no UIKit): every interactive step is surfaced as
/// a cross-platform SwiftUI sheet selected by ``activeSheet``. The sheets are flow-agnostic — they
/// invoke the stored continuation closures that whichever flow is active populates.
class SignInViewModel: NSObject, ObservableObject
{
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var statusMessage: String?
    @Published var isSigningIn: Bool = false

    /// Selects which Native Auth API surface the flows use. `true` uses the server-driven **V2**
    /// unified-delegate API; `false` uses the granular **V1** API.
    @Published var useV2Api: Bool = true

    /// Routes the flow through an Objective-C driver (``SignInViewModelV2ObjC`` for V2,
    /// ``SignInViewModelV1ObjC`` for V1) instead of this Swift view model. This exists to verify the
    /// V1 **and** V2 public APIs are fully consumable from Objective-C; the UI stays in SwiftUI.
    @Published var useObjCDriver: Bool = false

    /// Whether a user is currently signed in. When `true` the sign-in UI is hidden and the
    /// signed-in UI (protected-API access + sign-out) is shown.
    @Published var isSignedIn: Bool = false

    /// Whether the view model is attempting to restore a previous session (silent token acquisition)
    /// on launch. Starts `true` so the sign-in form is not shown until the silent attempt resolves.
    @Published var isRestoringSession: Bool = true

    /// The sheet currently presented over the unified screen, or `nil` when none is shown.
    @Published var activeSheet: AuthSheet?

    /// Inline error shown inside the verify-code sheet, or `nil` when there is none.
    @Published var verifyCodeError: String?

    /// Inline error shown inside the new-password sheet, or `nil` when there is none.
    @Published var newPasswordError: String?

    /// The attributes the server requires during sign-up, surfaced by the collect-attributes sheet.
    @Published var requiredAttributes: [MSALNativeAuthRequiredAttribute] = []

    /// The authentication methods offered during MFA / strong-auth, surfaced by the
    /// select-auth-method sheet.
    @Published var authMethods: [MSALAuthMethod] = []

    /// The most recent protected-API response text, shown on the signed-in screen.
    @Published var protectedAPIResult: String?

    private let nativeAuth: MSALNativeAuthPublicClientApplication?

    /// Continuation callbacks wired by whichever flow (V1 per-step delegates, the V2 action router,
    /// or an Obj-C driver) is currently active, so the shared sheets stay flow-agnostic.
    var onSubmitCode: ((String) -> Void)?
    var onResendCode: (() -> Void)?
    var onSubmitNewPassword: ((String) -> Void)?
    var onSubmitAttributes: (([String: Any]) -> Void)?
    var onSelectAuthMethod: ((MSALAuthMethod) -> Void)?

    /// The account result produced by a successful flow, used to acquire tokens and sign out.
    var accountResult: MSALNativeAuthUserAccountResult?

    /// The Objective-C V2 sign-in driver, retained for the duration of a flow when
    /// ``useObjCDriver`` is enabled with V2.
    var objCDriver: SignInViewModelV2ObjC?

    /// The Objective-C V1 sign-in driver, retained for the duration of a flow when
    /// ``useObjCDriver`` is enabled with V1.
    var objCDriverV1: SignInViewModelV1ObjC?

    /// A standard (non-native) MSAL application used for the browser-based / social "web fallback"
    /// flow. Created lazily by the web-fallback code path.
    var webBrowserApp: MSALPublicClientApplication?

    /// Supplies the platform presentation anchor (a `UIWindow` on iOS, an `NSWindow` on macOS) for
    /// the browser-based flow. Set by the hosting SwiftUI view.
    var presentationAnchorProvider: (() -> Any?)?

    /// Ensures the silent session restore is attempted only once per view-model lifetime.
    private var didAttemptSessionRestore = false

    override init()
    {
        do
        {
            let config = try MSALNativeAuthPublicClientApplicationConfig(
                clientId: Configuration.clientId,
                tenantSubdomain: Configuration.tenantSubdomain,
                challengeTypes: [.OOB, .password]
            )

            config.sliceConfig = Configuration.sliceConfig
            nativeAuth = try MSALNativeAuthPublicClientApplication(nativeAuthConfiguration: config)
        }
        catch
        {
            nativeAuth = nil
            print("Unable to initialize MSAL \(error)")
        }

        super.init()

        if nativeAuth == nil
        {
            statusMessage = "Unable to initialize MSAL."
        }
    }

    /// The native-auth application, exposed to the flow extensions.
    var application: MSALNativeAuthPublicClientApplication?
    {
        nativeAuth
    }

    var isSignInDisabled: Bool
    {
        email.isEmpty || isSigningIn
    }

    var isResetPasswordDisabled: Bool
    {
        email.isEmpty || isSigningIn
    }

    var isSignUpDisabled: Bool
    {
        email.isEmpty || isSigningIn
    }

    // MARK: - Start flows

    /// Called when the screen appears. Tries to acquire an access token silently from the cache. If
    /// there is no signed-in account (the user was signed out) the sign-in UI is shown.
    func loadCachedSession()
    {
        guard !didAttemptSessionRestore else
        {
            return
        }
        didAttemptSessionRestore = true

        guard let application = nativeAuth else
        {
            isRestoringSession = false
            return
        }

        guard let account = application.getNativeAuthUserAccount() else
        {
            // No cached account — the user is signed out; show the sign-in UI.
            isRestoringSession = false
            return
        }

        accountResult = account
        statusMessage = "Restoring your session…"
        account.getAccessToken(parameters: MSALNativeAuthGetAccessTokenParameters(), delegate: self)
    }

    /// Starts a sign-in. With a password the password flow is used; with an **empty** password the
    /// email one-time-code (OTP) flow is used.
    func signIn()
    {
        guard !email.isEmpty, !isSigningIn else
        {
            return
        }

        guard let application = nativeAuth else
        {
            statusMessage = "MSAL is not initialized."
            return
        }

        resetFlowState()
        isSigningIn = true
        let usingPassword = !password.isEmpty
        statusMessage = "Signing in… (\(useV2Api ? "V2" : "V1")\(usingPassword ? "" : ", email OTP"))"

        let parameters = MSALNativeAuthSignInParameters(username: email)
        if usingPassword
        {
            parameters.password = password
        }

        if useObjCDriver
        {
            if useV2Api
            {
                let driver = SignInViewModelV2ObjC(application: application, delegate: self)
                objCDriver = driver
                driver.signIn(withUsername: email, password: password)
            }
            else
            {
                startV1ObjCSignIn(application: application)
            }
        }
        else if useV2Api
        {
            application.signInV2(parameters: parameters, delegate: self)
        }
        else
        {
            application.signIn(parameters: parameters, delegate: self)
        }
    }

    func resetPassword()
    {
        guard !email.isEmpty, !isSigningIn else
        {
            return
        }
        guard let application = nativeAuth else
        {
            statusMessage = "MSAL is not initialized."
            return
        }

        resetFlowState()
        isSigningIn = true
        statusMessage = "Resetting password… (\(useV2Api ? "V2" : "V1"))"

        if useV2Api
        {
            let parameters = MSALNativeAuthResetPasswordParametersV2(username: email)
            application.resetPasswordV2(parameters: parameters, delegate: self)
        }
        else
        {
            let parameters = MSALNativeAuthResetPasswordParameters(username: email)
            application.resetPassword(parameters: parameters, delegate: self)
        }
    }

    func resetFlowState()
    {
        onSubmitCode = nil
        onResendCode = nil
        onSubmitNewPassword = nil
        onSubmitAttributes = nil
        onSelectAuthMethod = nil
        objCDriver = nil
        objCDriverV1 = nil
        requiredAttributes = []
        authMethods = []
        verifyCodeError = nil
        newPasswordError = nil
    }

    // MARK: - Sign out

    /// Signs the current user out and restores the sign-in UI.
    func signOut()
    {
        accountResult?.signOut()
        accountResult = nil
        resetFlowState()
        password = ""
        protectedAPIResult = nil
        isSignedIn = false
        isSigningIn = false
        isRestoringSession = false
        statusMessage = "Signed out."
    }

    // MARK: - Cancel the current flow

    /// Dismisses any presented sheet and abandons the in-progress flow. Called by the sheets' cancel
    /// affordances.
    func cancelFlow()
    {
        activeSheet = nil
        isSigningIn = false
        statusMessage = "Action cancelled."
    }
}

// MARK: - CredentialsDelegate (silent access-token retrieval)

extension SignInViewModel: CredentialsDelegate
{
    @MainActor
    func onAccessTokenRetrieveCompleted(result: MSALNativeAuthTokenResult)
    {
        // A token was acquired silently — the user is already signed in.
        isRestoringSession = false
        isSignedIn = true
        statusMessage = "Signed in as \(accountResult?.account.username ?? "unknown user")."
    }

    @MainActor
    func onAccessTokenRetrieveError(error: RetrieveAccessTokenError)
    {
        // Couldn't get a token silently (e.g. the user was signed out or interaction is required) —
        // show the sign-in UI.
        accountResult = nil
        isRestoringSession = false
        isSignedIn = false
        statusMessage = nil
    }
}

// MARK: - Flow-agnostic sheet presentation
//
// These helpers keep the names used by the V1 / V2 / Obj-C-bridge flow extensions, but now drive
// cross-platform SwiftUI sheets via `activeSheet` instead of presenting UIKit modals.

extension SignInViewModel
{
    /// Whether the verify-code sheet is currently presented.
    var isVerifyCodeModalPresented: Bool
    {
        activeSheet == .verifyCode
    }

    /// Whether the new-password sheet is currently presented.
    var isNewPasswordModalPresented: Bool
    {
        activeSheet == .newPassword
    }

    /// Presents (or refreshes) the verify-code sheet. The active flow must have wired
    /// ``onSubmitCode`` / ``onResendCode`` beforehand.
    func presentVerifyCodeModal()
    {
        verifyCodeError = nil
        activeSheet = .verifyCode
    }

    /// Presents the new-password sheet. The active flow must have wired ``onSubmitNewPassword``
    /// beforehand.
    func presentNewPasswordModal()
    {
        newPasswordError = nil
        activeSheet = .newPassword
    }

    /// Presents the collect-attributes sheet. The active flow must have set ``requiredAttributes``
    /// and wired ``onSubmitAttributes`` beforehand.
    func presentCollectAttributesModal()
    {
        activeSheet = .collectAttributes
    }

    /// Presents the select-auth-method sheet. The active flow must have set ``authMethods`` and
    /// wired ``onSelectAuthMethod`` beforehand.
    func presentSelectAuthMethodModal()
    {
        activeSheet = .selectAuthMethod
    }

    /// Updates the inline error on the verify-code sheet (keeping it presented).
    func updateVerifyCodeModal(errorMessage: String?)
    {
        verifyCodeError = errorMessage
        if activeSheet != .verifyCode
        {
            activeSheet = .verifyCode
        }
    }

    /// Updates the inline error on the new-password sheet (keeping it presented).
    func updateNewPasswordModal(errorMessage: String?)
    {
        newPasswordError = errorMessage
        if activeSheet != .newPassword
        {
            activeSheet = .newPassword
        }
    }

    /// Dismisses whichever sheet is presented.
    func dismissAnyModal()
    {
        activeSheet = nil
    }
}
