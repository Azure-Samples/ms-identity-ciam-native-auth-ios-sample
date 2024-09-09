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

/**
 * MultiFactorAuthenticationViewController class implements samples for using Multi-Factor Authentication (MFA) via Email OTP.
 * The code shows how to sign in a user with password (1st factor), and how to request and submit an email OTP code (2nd factor).
 * In order for this flow to work properly, you must enable MFA in the Portal. Follow the link below for more information.
 * Learn documentation: TBD
 */
class MultiFactorAuthenticationViewController: UIViewController {
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var resultTextView: UITextView!

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
                challengeTypes: [.OOB, .password]
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

    @IBAction func signInPressed(_: Any) {
        view.endEditing(true)

        guard let email = emailTextField.text, let password = passwordTextField.text else {
            resultTextView.text = "Email or password not set"
            return
        }

        print("Signing in with email \(email) and password")

        showResultText("Signing in...")

        nativeAuth.signIn(username: email, password: password, delegate: self)
    }
    
    @IBAction func signOutPressed(_: Any) {
        view.endEditing(true)

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

// MARK: - Sign In delegates

// MARK: SignInStartDelegate

extension MultiFactorAuthenticationViewController: SignInStartDelegate {

    func onSignInStartError(error: MSAL.SignInStartError) {
        print("SignInStartDelegate: onSignInStartError: \(error.errorDescription ??? "No error description")")

        if error.isUserNotFound || error.isInvalidCredentials || error.isInvalidUsername {
            showResultText("Invalid username or password")
        } else {
            showResultText("Error while signing in: \(error.errorDescription ?? "No error description")")
        }
    }

    func onSignInAwaitingMFA(newState: AwaitingMFAState) {
        print("SignInStartDelegate: onSignInAwaitingMFA")

        let alert = UIAlertController(title: "MFA required", message: "Do you want to proceed with MFA?", preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            newState.requestChallenge(delegate: self)
        }))

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
            self.resultTextView.text = "Second factor authentication required"
        }))

        present(alert, animated: true)
    }
}

// MARK: MFARequestChallengeDelegate

extension MultiFactorAuthenticationViewController: MFARequestChallengeDelegate {
    
    func onMFARequestChallengeError(error: MFAError, newState: MFARequiredState?) {
        print("MFARequestChallengeDelegate: onMFARequestChallengeError: \(error.errorDescription ?? "No error description")")
        showResultText("Unexpected error while requesting challenge: \(error.errorDescription ?? "No error description")")
        dismissVerifyCodeModal()
    }

    func onMFARequestChallengeVerificationRequired(
        newState: MFARequiredState,
        sentTo: String,
        channelTargetType: MSALNativeAuthChannelType,
        codeLength: Int
    ) {
        print("MFARequestChallengeDelegate: onMFARequestChallengeVerificationRequired: \(newState)")

        guard verifyCodeViewController == nil else {
            return
        }

        showVerifyCodeModal(submitCallback: { [weak self] code in
                                guard let self = self else { return }

                                newState.submitChallenge(challenge: code, delegate: self)
                            },
                            resendCallback: { [weak self] in
                                guard let self = self else { return }

                                newState.requestChallenge(delegate: self)
                            }, cancelCallback: { [weak self] in
                                guard let self = self else { return }

                                self.dismissVerifyCodeModal()
                                showResultText("Action cancelled")
                            })
    }
}

// MARK: MFASubmitChallengeDelegate

extension MultiFactorAuthenticationViewController: MFASubmitChallengeDelegate {

    func onMFASubmitChallengeError(error: MFASubmitChallengeError, newState: MFARequiredState?) {
        print("MFASubmitChallengeDelegate: onMFASubmitChallengeError: \(error.errorDescription ?? "No error description")")

        if error.isInvalidChallenge {
            guard let newState = newState else {
                print("Unexpected state. Received invalidCode but newState is nil")

                showResultText("Internal error verifying code")
                dismissVerifyCodeModal()
                return
            }

            updateVerifyCodeModal(errorMessage: "Invalid code",
                                  submitCallback: { [weak self] code in
                                      guard let self = self else { return }

                                      newState.submitChallenge(challenge: code, delegate: self)
                                  }, resendCallback: { [weak self] in
                                      guard let self = self else { return }

                                      newState.requestChallenge(delegate: self)
                                  }, cancelCallback: { [weak self] in
                                      guard let self = self else { return }

                                      self.dismissVerifyCodeModal()
                                      showResultText("Action cancelled")
                                  })
        } else {
            showResultText("Unexpected error verifying code: \(error.errorDescription ?? "No error description")")
            dismissVerifyCodeModal()
        }
    }

    func onSignInCompleted(result: MSALNativeAuthUserAccountResult) {
        print("Signed in: \(result.account.username ?? "")")

        accountResult = result

        result.getAccessToken(delegate: self)
    }
}

// MARK: - Credentials delegates

// MARK: CredentialsDelegate

extension MultiFactorAuthenticationViewController: CredentialsDelegate {
    
    func onAccessTokenRetrieveCompleted(result: MSALNativeAuthTokenResult) {
        print("Access Token: \(result.accessToken)")
        showResultText("Signed in. Access Token: \(result.accessToken)")
        updateUI()
        dismissVerifyCodeModal()
    }

    func onAccessTokenRetrieveError(error: MSAL.RetrieveAccessTokenError) {
        showResultText("Error retrieving access token: \(error.errorDescription ?? "No error description")")
    }
}

// MARK: - Verify Code modal methods

extension MultiFactorAuthenticationViewController {

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
    }
}
