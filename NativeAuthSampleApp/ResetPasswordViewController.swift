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

import MSAL
import UIKit

class ResetPasswordViewController: UIViewController {
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var resultTextView: UITextView!

    @IBOutlet weak var resetPasswordButton: UIButton!
    @IBOutlet weak var signOutButton: UIButton!

    var nativeAuth: MSALNativeAuthPublicClientApplication!

    var verifyCodeViewController: VerifyCodeViewController?
    var newPasswordViewController: NewPasswordViewController?

    var accountResult: MSALNativeAuthUserAccountResult?

    override func viewDidLoad() {
        super.viewDidLoad()

        do {
            let config = try MSALNativeAuthPublicClientApplicationConfig(
                clientId: Configuration.clientId,
                tenantSubdomain: Configuration.tenantSubdomain,
                challengeTypes: [.OOB, .password]
            )
            config.capabilities = [.mfaRequired, .registrationRequired]
            nativeAuth = try MSALNativeAuthPublicClientApplication(nativeAuthConfiguration: config)
        } catch {
            print("Unable to initialize MSAL \(error)")
            showResultText("Unable to initialize MSAL")
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        retrieveCachedAccount()
    }

    @IBAction func resetPasswordPressed(_: Any) {
        emailTextField.resignFirstResponder()

        guard let email = emailTextField.text, !email.isEmpty
        else {
            resultTextView.text = "Invalid email address"
            return
        }

        print("Resetting password for email \(email)")

        showResultText("Resetting password...")

        let parameters = MSALNativeAuthResetPasswordParameters(username: email)
        nativeAuth.resetPassword(parameters: parameters, delegate: self)
    }

    @IBAction func signOutPressed(_: Any) {
        emailTextField.resignFirstResponder()

        guard accountResult != nil else {
            print("signOutPressed: Not currently signed in")
            return
        }
        accountResult?.signOut()

        accountResult = nil

        showResultText("Signed out")

        updateUI()
    }

    func showResultText(_ text: String) {
        resultTextView.text = text
    }

    func updateUI() {
        let signedIn = (accountResult != nil)

        resetPasswordButton.isEnabled = !signedIn
        signOutButton.isEnabled = signedIn
    }

    func retrieveCachedAccount() {
        accountResult = nativeAuth.getNativeAuthUserAccount()
        if let _ = accountResult {
            showResultText("User signed in. Sign out to Reset Password.")
        } else {
            showResultText("")
        }

        updateUI()
    }
}

extension ResetPasswordViewController: ResetPasswordStartDelegate {
    func onResetPasswordCodeRequired(
        newState: MSAL.ResetPasswordCodeRequiredState,
        sentTo _: String,
        channelTargetType _: MSALNativeAuthChannelType,
        codeLength _: Int
    ) {
        print("ResetPasswordStartDelegate: onResetPasswordCodeRequired: \(newState)")

        showVerifyCodeModal(submitCallback: { [weak self] code in
                                guard let self = self else { return }

                                newState.submitCode(code: code, delegate: self)
                            },
                            resendCallback: { [weak self] in
                                guard let self = self else { return }

                                newState.resendCode(delegate: self)
                            }, cancelCallback: { [weak self] in
                                guard let self = self else { return }

                                showResultText("Action cancelled")
                            })
    }

    func onResetPasswordStartError(error: MSAL.ResetPasswordStartError) {
        if error.isInvalidUsername || error.isUserNotFound {
            showResultText("Unable to reset password: The email is invalid")
        } else if error.isUserDoesNotHavePassword {
            showResultText("Unable to reset password: No password associated with email address")
        } else {
            showResultText("Unable to reset password. Error: \(error.errorDescription ?? "No error description")")
        }
    }
}

extension ResetPasswordViewController: ResetPasswordResendCodeDelegate {
    func onResetPasswordResendCodeError(
        error: ResendCodeError,
        newState _: MSAL.ResetPasswordCodeRequiredState?
    ) {
        print("ResetPasswordResendCodeDelegate: onResetPasswordResendCodeError: \(error)")

        showResultText("Unexpected error while requesting new code")
        dismissVerifyCodeModal()
    }

    func onResetPasswordResendCodeRequired(
        newState: MSAL.ResetPasswordCodeRequiredState,
        sentTo _: String,
        channelTargetType _: MSALNativeAuthChannelType,
        codeLength _: Int
    ) {
        updateVerifyCodeModal(errorMessage: nil,
                              submitCallback: { [weak self] code in
                                  guard let self = self else { return }

                                  newState.submitCode(code: code, delegate: self)
                              }, resendCallback: { [weak self] in
                                  guard let self = self else { return }

                                  newState.resendCode(delegate: self)
                              }, cancelCallback: { [weak self] in
                                  guard let self = self else { return }

                                  showResultText("Action cancelled")
                              })
    }
}

extension ResetPasswordViewController: ResetPasswordVerifyCodeDelegate {
    func onResetPasswordVerifyCodeError(
        error: MSAL.VerifyCodeError,
        newState: MSAL.ResetPasswordCodeRequiredState?
    ) {
        if error.isInvalidCode {
            guard let newState = newState else {
                print("Unexpected state. Received invalidCode but newState is nil")

                showResultText("Internal error verifying code")
                return
            }

            updateVerifyCodeModal(errorMessage: "Check the code and try again",
                                  submitCallback: { [weak self] code in
                                      guard let self = self else { return }

                                      newState.submitCode(code: code, delegate: self)
                                  }, resendCallback: { [weak self] in
                                      guard let self = self else { return }

                                      newState.resendCode(delegate: self)
                                  }, cancelCallback: { [weak self] in
                                      guard let self = self else { return }

                                      showResultText("Action cancelled")
                                  })
        } else if error.isBrowserRequired {
            showResultText("Unable to reset password: Web UX required")
            dismissVerifyCodeModal()
        } else {
            showResultText("Unexpected error verifying code: \(error.errorDescription ?? "No error description")")
            dismissVerifyCodeModal()
        }
    }

    func onPasswordRequired(newState: MSAL.ResetPasswordRequiredState) {
        dismissVerifyCodeModal { [self] in
            showNewPasswordModal { [weak self] password in
                guard let self = self else { return }

                newState.submitPassword(password: password, delegate: self)
            }
        }
    }
}

extension ResetPasswordViewController: ResetPasswordRequiredDelegate {
    func onResetPasswordRequiredError(error: MSAL.PasswordRequiredError, newState: MSAL.ResetPasswordRequiredState?) {
        if error.isInvalidPassword {
            guard let newState = newState else {
                print("Unexpected state. Received invalidPassword but newState is nil")

                showResultText("Internal error verifying password")
                return
            }

            updateNewPasswordModal(errorMessage: "Invalid password",
                                   submitCallback: { password in
                                       newState.submitPassword(password: password, delegate: self)
                                   }, cancelCallback: { [weak self] in
                                       guard let self = self else { return }

                                       showResultText("Action cancelled")
                                   })
        } else {
            showResultText("Error setting password: \(error.errorDescription ?? "No error description")")
            dismissNewPasswordModal()
        }
    }

    func onResetPasswordCompleted(newState: MSAL.SignInAfterResetPasswordState) {
        showResultText("Password reset successfully")
        dismissNewPasswordModal()

        let parameters = MSALNativeAuthSignInAfterResetPasswordParameters()
        newState.signIn(parameters: parameters, delegate: self)
    }
}

// MARK: SignInAfterResetPasswordDelegate

extension ResetPasswordViewController: SignInAfterResetPasswordDelegate {
    func onSignInAfterResetPasswordError(error: MSAL.SignInAfterResetPasswordError) {
        showResultText("Error signing in after password reset: \(error.errorDescription ?? "No error description")")
    }

    func onSignInCompleted(result: MSALNativeAuthUserAccountResult) {
        dismissVerifyCodeModal()

        print("Signed in: \(result.account.username ?? "")")

        accountResult = result

        updateUI()

        showResultText("Password reset successfully and user signed in.")
    }
}

// MARK: - Verify Code modal methods

extension ResetPasswordViewController {
    func showVerifyCodeModal(
        submitCallback: @escaping (_ code: String) -> Void,
        resendCallback: @escaping () -> Void,
        cancelCallback: @escaping () -> Void
    ) {
        verifyCodeViewController = storyboard?.instantiateViewController(
            withIdentifier: "VerifyCodeViewController") as? VerifyCodeViewController

        guard let verifyCodeViewController = verifyCodeViewController else {
            print("Error creating Verify Code view controller")
            return
        }

        updateVerifyCodeModal(errorMessage: nil,
                              submitCallback: submitCallback,
                              resendCallback: resendCallback,
                              cancelCallback: cancelCallback)

        present(verifyCodeViewController, animated: true)
    }

    func updateVerifyCodeModal(
        errorMessage: String?,
        submitCallback: @escaping (_ code: String) -> Void,
        resendCallback: @escaping () -> Void,
        cancelCallback: @escaping () -> Void
    ) {
        guard let verifyCodeViewController = verifyCodeViewController else {
            return
        }

        if let errorMessage = errorMessage {
            verifyCodeViewController.errorLabel.text = errorMessage
        }

        verifyCodeViewController.onSubmit = { code in
            DispatchQueue.main.async {
                submitCallback(code)
            }
        }

        verifyCodeViewController.onResend = {
            DispatchQueue.main.async {
                resendCallback()
            }
        }

        verifyCodeViewController.onCancel = {
            DispatchQueue.main.async {
                cancelCallback()
            }
        }
    }

    func dismissVerifyCodeModal(completion: (() -> Void)? = nil) {
        guard verifyCodeViewController != nil else {
            print("Unexpected error: Verify Code view controller is nil")
            return
        }

        dismiss(animated: true, completion: completion)
        verifyCodeViewController = nil
    }
}

// MARK: - New Password modal methods

extension ResetPasswordViewController {
    func showNewPasswordModal(submittedCallback: @escaping ((_ password: String) -> Void)) {
        newPasswordViewController = storyboard?.instantiateViewController(
            withIdentifier: "NewPasswordViewController") as? NewPasswordViewController

        guard let newPasswordViewController = newPasswordViewController else {
            print("Error creating password view controller")
            return
        }

        newPasswordViewController.onSubmit = submittedCallback

        present(newPasswordViewController, animated: true)
    }

    func updateNewPasswordModal(
        errorMessage: String?,
        submitCallback: @escaping ((_ password: String) -> Void),
        cancelCallback: @escaping () -> Void
    ) {
        guard let newPasswordViewController = newPasswordViewController else {
            return
        }

        if let errorMessage = errorMessage {
            newPasswordViewController.errorLabel.text = errorMessage
        }

        newPasswordViewController.onSubmit = { password in
            DispatchQueue.main.async {
                submitCallback(password)
            }
        }

        newPasswordViewController.onCancel = {
            DispatchQueue.main.async {
                cancelCallback()
            }
        }
    }

    func dismissNewPasswordModal() {
        guard newPasswordViewController != nil else {
            print("Unexpected error: Password view controller is nil")
            return
        }

        dismiss(animated: true)

        newPasswordViewController = nil
        showResultText("Action cancelled")
    }
}
