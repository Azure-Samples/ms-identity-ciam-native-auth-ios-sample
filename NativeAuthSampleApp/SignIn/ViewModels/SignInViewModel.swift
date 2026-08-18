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

#if os(iOS) && canImport(UIKit)
import UIKit
#endif

#if os(macOS) && canImport(AppKit)
import AppKit
#endif

/// Identifies which cross-platform SwiftUI sheet the auth flow is currently presenting. The flows
/// populate the flow-agnostic continuation closures (``onSubmitCode`` / ``onResendCode`` /
/// ``onSubmitNewPassword`` / ``onSubmitAttributes`` / ``onSelectAuthMethod`` /
/// ``onSubmitVerificationContact``) before setting the matching sheet, so the sheets stay
/// flow-agnostic.
enum AuthSheet: String, Identifiable
{
    case verifyCode
    case newPassword
    case collectAttributes
    case selectAuthMethod
    case verificationContact

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
/// and the server-driven **V2** per-state-delegate API, chosen by ``useV2Api``.
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

    /// The strong-auth registration method selected before entering its verification contact.
    @Published var registrationAuthMethod: MSALAuthMethod?

    /// The most recent protected-API response text, shown on the signed-in screen.
    @Published var protectedAPIResult: String?

    private let nativeAuth: MSALNativeAuthPublicClientApplication?

    /// Continuation callbacks wired by whichever flow (V1 per-step delegates or the V2 action
    /// router) is currently active, so the shared sheets stay flow-agnostic.
    var onSubmitCode: ((String) -> Void)?
    var onResendCode: (() -> Void)?
    var onSubmitNewPassword: ((String) -> Void)?
    var onSubmitAttributes: (([String: Any]) -> Void)?
    var onSelectAuthMethod: ((MSALAuthMethod) -> Void)?
    var onSubmitVerificationContact: ((String) -> Void)?

    /// The account result produced by a successful flow, used to acquire tokens and sign out.
    var accountResult: MSALNativeAuthUserAccountResult?

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
//            let config = try MSALNativeAuthPublicClientApplicationConfig(
//                clientId: Configuration.clientId,
//                tenantSubdomain: Configuration.tenantSubdomain,
//                challengeTypes: [.OOB, .password]
//            )
            
            let config = try MSALNativeAuthPublicClientApplicationConfig(clientId: Configuration.clientId,
                                                                         authority: Configuration.ciamAuthority(),
                                                                         challengeTypes: [.OOB, .password])
            config.capabilities = [.mfaRequired, .registrationRequired]

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
        
        let authenticationContextId = "c4"
        let authenticationContextRequestClaimJson = "{\"access_token\":{\"acrs\":{\"essential\":true,\"value\":\"\(authenticationContextId)\"}}}"

        parameters.claimsRequest = MSALClaimsRequest(jsonString: authenticationContextRequestClaimJson,
                                                     error: nil)

        if useV2Api
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
            let parameters = MSALNativeAuthResetPasswordParameters(username: email)
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
        onSubmitVerificationContact = nil
        requiredAttributes = []
        authMethods = []
        registrationAuthMethod = nil
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
// These helpers keep the names used by the V1 / V2 flow extensions, but now drive cross-platform
// SwiftUI sheets via `activeSheet` instead of presenting UIKit modals.

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

    /// Presents the verification-contact sheet after the user selects a strong-auth method.
    func presentVerificationContactModal()
    {
        activeSheet = .verificationContact
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


@MainActor private var protectedAPITokenDelegates: [ObjectIdentifier: ProtectedAPITokenDelegate] = [:]

private final class ProtectedAPITokenDelegate: NSObject, CredentialsDelegate
{
    private let onCompleted: @MainActor (MSALNativeAuthTokenResult) -> Void
    private let onError: @MainActor (RetrieveAccessTokenError) -> Void

    init(
        onCompleted: @escaping @MainActor (MSALNativeAuthTokenResult) -> Void,
        onError: @escaping @MainActor (RetrieveAccessTokenError) -> Void
    )
    {
        self.onCompleted = onCompleted
        self.onError = onError
    }

    @MainActor
    func onAccessTokenRetrieveCompleted(result: MSALNativeAuthTokenResult)
    {
        onCompleted(result)
    }

    @MainActor
    func onAccessTokenRetrieveError(error: RetrieveAccessTokenError)
    {
        onError(error)
    }
}

// MARK: - Protected API

extension SignInViewModel
{
    private var protectedAPIUrl: String?
    {
        nil
    }

    private var protectedAPIScopes: [String]
    {
        []
    }

    @MainActor
    func callProtectedAPI()
    {
        guard let accountResult = accountResult else
        {
            protectedAPIResult = "No signed-in account is available."
            return
        }

        guard let apiUrl = protectedAPIUrl, !protectedAPIScopes.isEmpty else
        {
            protectedAPIResult = "Protected API not configured. Set the API URL and scopes in SignInViewModel+ProtectedAPI.swift."
            return
        }

        statusMessage = "Retrieving access token to call the protected API…"
        protectedAPIResult = nil

        let parameters = MSALNativeAuthGetAccessTokenParameters()
        parameters.scopes = protectedAPIScopes

        let key = ObjectIdentifier(self)
        let delegate = ProtectedAPITokenDelegate(
            onCompleted: { [weak self] tokenResult in
                guard let self = self else { return }
                protectedAPITokenDelegates[key] = nil
                self.accessProtectedAPI(apiUrl: apiUrl, accessToken: tokenResult.accessToken)
            },
            onError: { [weak self] error in
                protectedAPITokenDelegates[key] = nil
                self?.statusMessage = "Unable to retrieve an access token."
                self?.protectedAPIResult = "Error retrieving access token: \(error.errorDescription ?? "unknown error")"
            }
        )
        protectedAPITokenDelegates[key] = delegate
        accountResult.getAccessToken(parameters: parameters, delegate: delegate)
    }

    @MainActor
    private func accessProtectedAPI(apiUrl: String, accessToken: String)
    {
        guard let url = URL(string: apiUrl) else
        {
            protectedAPIResult = "Invalid API URL."
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error
            {
                Task { @MainActor in
                    self?.statusMessage = "Protected API call failed."
                    self?.protectedAPIResult = error.localizedDescription
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else
            {
                Task { @MainActor in
                    self?.statusMessage = "Protected API call failed."
                    self?.protectedAPIResult = "No HTTP response was returned."
                }
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else
            {
                Task { @MainActor in
                    self?.statusMessage = "Protected API call failed."
                    self?.protectedAPIResult = "HTTP response code: \(httpResponse.statusCode)"
                }
                return
            }

            let body: String
            if let data = data, let text = String(data: data, encoding: .utf8)
            {
                body = text
            }
            else
            {
                body = "<empty response>"
            }

            Task { @MainActor in
                self?.statusMessage = "Accessed the protected API successfully."
                self?.protectedAPIResult = """
                Accessed API successfully using an access token.
                HTTP response code: \(httpResponse.statusCode)
                HTTP response body:
                \(body)
                """
            }
        }.resume()
    }
}



// MARK: - Browser and social sign-in

extension SignInViewModel
{
    func signInWithBrowser()
    {
        startBrowserSignIn(domainHint: nil, displayName: "browser")
    }

    func signInWithSocial(provider: SocialProvider)
    {
        startBrowserSignIn(domainHint: provider.domainHint, displayName: provider.displayName)
    }

    private func startBrowserSignIn(domainHint: String?, displayName: String)
    {
        guard !isSigningIn else
        {
            return
        }

        resetFlowState()
        isSigningIn = true
        statusMessage = "Signing in with \(displayName)…"

        guard let webviewParameters = makeWebviewParameters() else
        {
            isSigningIn = false
            statusMessage = "Unable to start browser sign-in: no presentation anchor is available."
            return
        }

        let application: MSALPublicClientApplication
        do
        {
            application = try webBrowserApplication()
        }
        catch
        {
            isSigningIn = false
            statusMessage = "Unable to initialize browser sign-in: \(error.localizedDescription)"
            return
        }

        let parameters = MSALInteractiveTokenParameters(scopes: ["User.Read"], webviewParameters: webviewParameters)
        parameters.promptType = .login
        parameters.domainHint = domainHint

        application.acquireToken(with: parameters) { [weak self] result, error in
            DispatchQueue.main.async
            {
                guard let self = self else { return }

                if let error = error
                {
                    self.isSigningIn = false
                    self.statusMessage = "Error acquiring token: \(error.localizedDescription)"
                    return
                }

                guard result?.account != nil else
                {
                    self.isSigningIn = false
                    self.statusMessage = "Could not acquire token: no account returned."
                    return
                }

                if let account = self.application?.getNativeAuthUserAccount()
                {
                    self.accountResult = account
                }

                self.isSigningIn = false
                self.isSignedIn = true
                self.statusMessage = "Signed in successfully with \(displayName)."
            }
        }
    }

    private func webBrowserApplication() throws -> MSALPublicClientApplication
    {
        if let webBrowserApp = webBrowserApp
        {
            return webBrowserApp
        }

        guard let authorityUrl = URL(string: "https://\(Configuration.tenantSubdomain).ciamlogin.com") else
        {
            throw WebSignInError.invalidAuthority
        }

        let authority = try MSALCIAMAuthority(url: authorityUrl)
        let config = MSALPublicClientApplicationConfig(
            clientId: Configuration.clientId,
            redirectUri: nil,
            authority: authority
        )
        config.sliceConfig = Configuration.sliceConfig

        let application = try MSALPublicClientApplication(configuration: config)
        webBrowserApp = application
        return application
    }

    private func makeWebviewParameters() -> MSALWebviewParameters?
    {
        guard let anchor = presentationAnchorProvider?() else
        {
            return nil
        }

        #if os(iOS) && canImport(UIKit)
        guard let window = anchor as? UIWindow, let viewController = window.rootViewController else
        {
            return nil
        }
        return MSALWebviewParameters(authPresentationViewController: viewController)
        #elseif os(macOS) && canImport(AppKit)
        guard let window = anchor as? NSWindow, let viewController = window.contentViewController else
        {
            return nil
        }
        return MSALWebviewParameters(authPresentationViewController: viewController)
        #else
        return nil
        #endif
    }
}

private extension SocialProvider
{
    var domainHint: String
    {
        switch self
        {
        case .linkedin:
            return "www.linkedin.com"
        default:
            return displayName
        }
    }
}

private enum WebSignInError: LocalizedError
{
    case invalidAuthority

    var errorDescription: String?
    {
        switch self
        {
        case .invalidAuthority:
            return "The CIAM authority URL is invalid."
        }
    }
}

// MARK: - Sign-up flow

extension SignInViewModel
{
    func signUp()
    {
        guard !email.isEmpty, !isSigningIn else
        {
            return
        }

        guard let application = application else
        {
            statusMessage = "MSAL is not initialized."
            return
        }

        resetFlowState()
        isSigningIn = true
        statusMessage = "Signing up… (\(useV2Api ? "V2" : "V1"))"

        if useV2Api
        {
            let parameters = MSALNativeAuthSignUpParametersV2(username: email)
            if !password.isEmpty
            {
                parameters.password = password
            }
            application.signUpV2(parameters: parameters, delegate: self)
        }
        else
        {
            let parameters = MSALNativeAuthSignUpParameters(username: email)
            if !password.isEmpty
            {
                parameters.password = password
            }
            application.signUp(parameters: parameters, delegate: self)
        }
    }
}
