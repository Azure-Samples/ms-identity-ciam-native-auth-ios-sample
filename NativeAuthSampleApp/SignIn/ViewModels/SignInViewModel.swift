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
import UIKit
import MSAL

/// Drives the Native Auth sign-in / reset-password flows for the sign-in screen, supporting both
/// the granular **V1** API and the server-driven **V2** unified-delegate API. The active surface is
/// chosen by ``useV2Api`` (toggled from the UI).
///
/// This view model is both the unified ``MSALNativeAuthFlowDelegate`` (V2) and the granular V1
/// delegates. It keeps the latest ``MSALNativeAuthState`` (V2) so a multi-step flow can be
/// continued, routes each server-driven action, and presents the shared UIKit modals
/// (`VerifyCodeViewController`, `NewPasswordViewController`). The modals are flow-agnostic: they call
/// stored continuation callbacks that whichever flow is active populates.
///
/// Modals are presented on a weakly-held presenting `UIViewController` (set by the hosting
/// `SignInViewController`), so the view model never retains the controller.
class SignInViewModel: NSObject, ObservableObject
{
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var statusMessage: String?
    @Published var isSigningIn: Bool = false

    /// Selects which Native Auth API surface the sign-in / reset-password flows use.
    /// `true` uses the server-driven **V2** unified-delegate API; `false` uses the granular **V1** API.
    @Published var useV2Api: Bool = true

    /// Whether a user is currently signed in. When `true` the sign-in UI is hidden and only the
    /// sign-out affordance is shown.
    @Published var isSignedIn: Bool = false

    /// Whether the view model is attempting to restore a previous session (silent token acquisition)
    /// on launch. Starts `true` so the sign-in form is not shown until the silent attempt resolves;
    /// the form appears only if there is no cached account or the token can't be refreshed silently.
    @Published var isRestoringSession: Bool = true

    /// Presenting controller used to show / dismiss the shared UIKit modals. Set by the hosting
    /// view controller. Weak so the view model never retains the controller.
    weak var presenter: UIViewController?

    private let nativeAuth: MSALNativeAuthPublicClientApplication?

    /// Continuation callbacks wired by whichever flow (V1 per-step delegates or the V2 action
    /// router) is currently active, so the shared modals stay flow-agnostic.
    var onSubmitCode: ((String) -> Void)?
    var onResendCode: (() -> Void)?
    var onSubmitNewPassword: ((String) -> Void)?

    private var verifyCodeViewController: VerifyCodeViewController?
    private var newPasswordViewController: NewPasswordViewController?

    /// The account result produced by a successful flow, used to sign the user out.
    var accountResult: MSALNativeAuthUserAccountResult?

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

    var isSignInDisabled: Bool
    {
        email.isEmpty || password.isEmpty || isSigningIn
    }

    var isResetPasswordDisabled: Bool
    {
        email.isEmpty || isSigningIn
    }

    // MARK: - Start flows

    /// Called when the sign-in screen appears. Tries to acquire an access token silently from the
    /// cache. If there is no signed-in account (the user was signed out) the sign-in UI is shown.
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

    func signIn()
    {
        guard !email.isEmpty, !password.isEmpty, !isSigningIn else
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
        statusMessage = "Signing in… (\(useV2Api ? "V2" : "V1"))"

        let parameters = MSALNativeAuthSignInParameters(username: email)
        parameters.password = password

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

        let parameters = MSALNativeAuthResetPasswordParameters(username: email)

        if useV2Api
        {
            application.resetPasswordV2(parameters: parameters, delegate: self)
        }
        else
        {
            application.resetPassword(parameters: parameters, delegate: self)
        }
    }

    func resetFlowState()
    {
        onSubmitCode = nil
        onResendCode = nil
        onSubmitNewPassword = nil
    }

    // MARK: - Sign out

    /// Signs the current user out and restores the sign-in UI.
    func signOut()
    {
        accountResult?.signOut()
        accountResult = nil
        resetFlowState()
        password = ""
        isSignedIn = false
        isSigningIn = false
        isRestoringSession = false
        statusMessage = "Signed out."
    }

    // MARK: - Cancel the current flow

    private func cancelFlow()
    {
        verifyCodeViewController = nil
        newPasswordViewController = nil
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

// MARK: - Verify Code modal

extension SignInViewModel
{
    /// Whether the verify-code modal is currently presented.
    var isVerifyCodeModalPresented: Bool
    {
        verifyCodeViewController != nil
    }

    /// Whether the new-password modal is currently presented.
    var isNewPasswordModalPresented: Bool
    {
        newPasswordViewController != nil
    }

    func presentVerifyCodeModal()
    {
        if verifyCodeViewController != nil
        {
            updateVerifyCodeModal(errorMessage: nil)
        }
        else
        {
            showVerifyCodeModal()
        }
    }

    private func showVerifyCodeModal()
    {
        verifyCodeViewController = presenter?.storyboard?.instantiateViewController(
            withIdentifier: "VerifyCodeViewController") as? VerifyCodeViewController

        guard let verifyCodeViewController = verifyCodeViewController else
        {
            print("Error creating Verify Code view controller")
            return
        }

        updateVerifyCodeModal(errorMessage: nil)
        presenter?.present(verifyCodeViewController, animated: true)
    }

    func updateVerifyCodeModal(errorMessage: String?)
    {
        guard let verifyCodeViewController = verifyCodeViewController else
        {
            return
        }

        if let errorMessage = errorMessage
        {
            verifyCodeViewController.errorLabel.text = errorMessage
        }

        verifyCodeViewController.onSubmit = { [weak self] code in
            DispatchQueue.main.async
            {
                self?.onSubmitCode?(code)
            }
        }

        verifyCodeViewController.onResend = { [weak self] in
            DispatchQueue.main.async
            {
                self?.onResendCode?()
            }
        }

        verifyCodeViewController.onCancel = { [weak self] in
            DispatchQueue.main.async
            {
                self?.cancelFlow()
            }
        }
    }

    private func dismissVerifyCodeModal(completion: (() -> Void)? = nil)
    {
        guard verifyCodeViewController != nil else
        {
            completion?()
            return
        }

        presenter?.dismiss(animated: true, completion: completion)
        verifyCodeViewController = nil
    }
}

// MARK: - New Password modal

extension SignInViewModel
{
    func presentNewPasswordModal()
    {
        if verifyCodeViewController != nil
        {
            dismissVerifyCodeModal { [weak self] in
                self?.showNewPasswordModal()
            }
        }
        else
        {
            showNewPasswordModal()
        }
    }

    private func showNewPasswordModal()
    {
        newPasswordViewController = presenter?.storyboard?.instantiateViewController(
            withIdentifier: "NewPasswordViewController") as? NewPasswordViewController

        guard let newPasswordViewController = newPasswordViewController else
        {
            print("Error creating password view controller")
            return
        }

        updateNewPasswordModal(errorMessage: nil)
        presenter?.present(newPasswordViewController, animated: true)
    }

    func updateNewPasswordModal(errorMessage: String?)
    {
        guard let newPasswordViewController = newPasswordViewController else
        {
            return
        }

        if let errorMessage = errorMessage
        {
            newPasswordViewController.errorLabel.text = errorMessage
        }

        newPasswordViewController.onSubmit = { [weak self] password in
            DispatchQueue.main.async
            {
                self?.onSubmitNewPassword?(password)
            }
        }

        newPasswordViewController.onCancel = { [weak self] in
            DispatchQueue.main.async
            {
                self?.cancelFlow()
            }
        }
    }

    private func dismissNewPasswordModal()
    {
        guard newPasswordViewController != nil else
        {
            return
        }

        presenter?.dismiss(animated: true)
        newPasswordViewController = nil
    }

    func dismissAnyModal()
    {
        if verifyCodeViewController != nil
        {
            dismissVerifyCodeModal()
        }
        if newPasswordViewController != nil
        {
            dismissNewPasswordModal()
        }
    }
}
