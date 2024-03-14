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

// swiftlint:disable file_length
class EmailAndCodeViewController: UIViewController {
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var resultTextView: UITextView!

    @IBOutlet weak var signUpButton: UIButton!
    @IBOutlet weak var signInButton: UIButton!
    @IBOutlet weak var signOutButton: UIButton!

    var nativeAuth: MSALNativeAuthPublicClientApplication!

    var verifyCodeViewController: VerifyCodeViewController?

    var accountResult: MSALNativeAuthUserAccountResult?

    override func viewDidLoad() {
        super.viewDidLoad()

        do {
            nativeAuth = try MSALNativeAuthPublicClientApplication(
                clientId: Configuration.clientId,
                tenantSubdomain: Configuration.tenantSubdomain,
                challengeTypes: [.OOB]
            )
        } catch {
            print("Unable to initialize MSAL \(error)")
            showResultText("Unable to initialize MSAL")
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        retrieveCachedAccount()
    }

    @IBAction func signUpPressed(_: Any) {
        guard let email = emailTextField.text else {
            resultTextView.text = "Email not set"
            return
        }

        print("Signing up with email \(email)")

        showResultText("Signing up...")

        nativeAuth.signUp(username: email, delegate: self)
    }

    @IBAction func signInPressed(_: Any) {
        guard let email = emailTextField.text else {
            resultTextView.text = "email not set"
            return
        }

        print("Signing in with email \(email)")

        showResultText("Signing in...")

        nativeAuth.signIn(username: email, delegate: self)
    }

    @IBAction func signOutPressed(_: Any) {
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

        signUpButton.isEnabled = !signedIn
        signInButton.isEnabled = !signedIn
        signOutButton.isEnabled = signedIn
    }

    func retrieveCachedAccount() {
        accountResult = nativeAuth.getNativeAuthUserAccount()
        if let accountResult = accountResult, let homeAccountId = accountResult.account.homeAccountId?.identifier {
            print("Account found in cache: \(homeAccountId)")

            accountResult.getAccessToken(delegate: self)
        } else {
            print("No account found in cache")

            accountResult = nil

            showResultText("")

            updateUI()
        }
    }
}

// MARK: - Sign Up delegates

// MARK: SignUpStartDelegate

extension EmailAndCodeViewController: SignUpStartDelegate {
    func onSignUpStartError(error: MSAL.SignUpStartError) {
        if error.isUserAlreadyExists {
            showResultText("Unable to sign up: User already exists")
        } else if error.isInvalidUsername {
            showResultText("Unable to sign up: The username is invalid")
        } else if error.isBrowserRequired {
            showResultText("Unable to sign up: Web UX required")
        } else {
            showResultText("Unexpected error signing up: \(error.errorDescription ?? "No error description")")
        }
    }

    func onSignUpCodeRequired(
        newState: MSAL.SignUpCodeRequiredState,
        sentTo: String,
        channelTargetType: MSALNativeAuthChannelType,
        codeLength: Int
    ) {

        print("SignUpStartDelegate: onSignUpCodeRequired: \(newState)")
        showResultText("Email verification required")

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
}

// MARK: SignUpVerifyCodeDelegate

extension EmailAndCodeViewController: SignUpVerifyCodeDelegate {
    func onSignUpVerifyCodeError(error: MSAL.VerifyCodeError, newState: MSAL.SignUpCodeRequiredState?) {
        if error.isInvalidCode {
            guard let newState = newState else {
                print("Unexpected state. Received invalidCode but newState is nil")

                showResultText("Internal error verifying code")
                return
            }

            updateVerifyCodeModal(errorMessage: "Invalid code",
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
            showResultText("Unable to sign up: Web UX required")
            dismissVerifyCodeModal()
        } else {
            showResultText("Unexpected error verifying code: \(error.errorDescription ?? "No error description")")
            dismissVerifyCodeModal()
        }
    }

    func onSignUpCompleted(newState: MSAL.SignInAfterSignUpState) {
        showResultText("Signed up successfully!")
        dismissVerifyCodeModal()

        newState.signIn(delegate: self)
    }
}

// MARK: SignUpResendCodeDelegate

extension EmailAndCodeViewController: SignUpResendCodeDelegate {
    
    func onSignUpResendCodeError(error: MSAL.ResendCodeError, newState: MSAL.SignUpCodeRequiredState?) {
        print("SignUpResendCodeDelegate: onSignUpResendCodeError: \(error)")
        showResultText("Unexpected error while requesting new code")
        dismissVerifyCodeModal()
    }

    func onSignUpResendCodeCodeRequired(
        newState: MSAL.SignUpCodeRequiredState,
        sentTo _: String,
        channelTargetType _: MSAL.MSALNativeAuthChannelType,
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

// MARK: SignInAfterSignUpDelegate

extension EmailAndCodeViewController: SignInAfterSignUpDelegate {
    func onSignInAfterSignUpError(error: MSAL.SignInAfterSignUpError) {
        showResultText("Error signing in after signing up.")
    }
}

// MARK: - Sign In delegates

// MARK: SignInStartDelegate

extension EmailAndCodeViewController: SignInStartDelegate {
    func onSignInStartError(error: MSAL.SignInStartError) {
        print("SignInStartDelegate: onSignInStartError: \(error)")
        if error.isUserNotFound || error.isInvalidUsername {
            showResultText("Invalid username")
        } else if error.isBrowserRequired {
            showResultText("Unable to sign in: Web UX required")
        } else {
            showResultText("Error while signing in: \(error.errorDescription ?? "No error description")")
        }
    }

    func onSignInCodeRequired(
        newState: MSAL.SignInCodeRequiredState,
        sentTo: String,
        channelTargetType: MSAL.MSALNativeAuthChannelType,
        codeLength: Int
    ) {
        print("SignInStartDelegate: onSignInCodeRequired: \(newState)")

        showResultText("Email verification required")

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
}

// MARK: SignInVerifyCodeDelegate

extension EmailAndCodeViewController: SignInVerifyCodeDelegate {
    func onSignInVerifyCodeError(error: MSAL.VerifyCodeError, newState: MSAL.SignInCodeRequiredState?) {
        if error.isInvalidCode {
            guard let newState = newState else {
                print("Unexpected state. Received invalidCode but newState is nil")

                showResultText("Internal error verifying code")
                return
            }

            updateVerifyCodeModal(errorMessage: "Invalid code",
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
            showResultText("Unable to sign in: Web UX required")
            dismissVerifyCodeModal()
        } else {
            showResultText("Unexpected error verifying code: \(error.errorDescription ?? "No error description")")
            dismissVerifyCodeModal()
        }
    }

    func onSignInCompleted(result: MSAL.MSALNativeAuthUserAccountResult) {
        dismissVerifyCodeModal()

        print("Signed in: \(result.account.username ?? "")")

        accountResult = result

        result.getAccessToken(delegate: self)
    }
}

// MARK: SignInResendCodeDelegate

extension EmailAndCodeViewController: SignInResendCodeDelegate {
    func onSignInResendCodeError(error: MSAL.ResendCodeError, newState: MSAL.SignInCodeRequiredState?) {
        print("SignInResendCodeDelegate: onSignInResendCodeError: \(error)")

        showResultText("Unexpected error while requesting new code")
        dismissVerifyCodeModal()
    }

    func onSignInResendCodeCodeRequired(
        newState: MSAL.SignInCodeRequiredState,
        sentTo: String,
        channelTargetType: MSAL.MSALNativeAuthChannelType,
        codeLength: Int
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

// MARK: - CredentialsDelegate methods

extension EmailAndCodeViewController: CredentialsDelegate {
    func onAccessTokenRetrieveCompleted(accessToken: String) {
        print("Access Token: \(accessToken)")
        showResultText("Signed in. Access Token: \(accessToken)")
        updateUI()
    }

    func onAccessTokenRetrieveError(error: MSAL.RetrieveAccessTokenError) {
        showResultText("Error retrieving access token: \(error.errorDescription ?? "No error description")")
        dismissVerifyCodeModal()
    }
}

// MARK: - Verify Code modal methods

extension EmailAndCodeViewController {
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

    func dismissVerifyCodeModal() {
        guard verifyCodeViewController != nil else {
            print("Unexpected error: Verify Code view controller is nil")
            return
        }

        dismiss(animated: true)
        verifyCodeViewController = nil
        showResultText("Action cancelled")
    }
}
