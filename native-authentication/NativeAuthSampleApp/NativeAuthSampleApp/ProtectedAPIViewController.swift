//
//  EmailAndPasswordPrivateAPIViewController.swift
//  NativeAuthSampleApp
//
//  Created by marcos on 29/01/2024.
//

import MSAL
import UIKit

class ProtectedAPIViewController: UIViewController {
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var resultTextView: UITextView!

    @IBOutlet weak var signUpButton: UIButton!
    @IBOutlet weak var signInButton: UIButton!
    @IBOutlet weak var signOutButton: UIButton!
    @IBOutlet weak var protectedAPIButton: UIButton!

    var nativeAuth: MSALNativeAuthPublicClientApplication!

    var verifyCodeViewController: VerifyCodeViewController?

    var accountResult: MSALNativeAuthUserAccountResult?
    
    var accessToken: String?

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

    @IBAction func signUpPressed(_: Any) {
        guard let email = emailTextField.text, let password = passwordTextField.text else {
            resultTextView.text = "Email or password not set"
            return
        }

        print("Signing up with email \(email) and password")

        nativeAuth.signUp(username: email, password: password, delegate: self)
    }

    @IBAction func signInPressed(_: Any) {
        guard let email = emailTextField.text, let password = passwordTextField.text else {
            resultTextView.text = "Email or password not set"
            return
        }

        print("Signing in with email \(email) and password")

        nativeAuth.signIn(username: email, password: password, scopes: Configuration.protectedAPIScopes, delegate: self)
    }

    @IBAction func signOutPressed(_: Any) {
        guard accountResult != nil else {
            print("signOutPressed: Not currently signed in")
            return
        }
        accountResult?.signOut()

        accountResult = nil
        
        accessToken = nil

        showResultText("Signed out")

        updateUI()
    }
    
    @IBAction func protectedAPIPressed(_: Any) {
        guard let url = URL(string: Configuration.protectedAPIUrl) else {
            print("Invalid API url")
            return
        }
        
        guard let accessToken = self.accessToken else {
            print("No access token found")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        retrieveAPIData(request: request)
    }
    
    func showResultText(_ text: String) {
        resultTextView.text = text
    }

    func updateUI() {
        let signedIn = (accountResult != nil)

        signUpButton.isEnabled = !signedIn
        signInButton.isEnabled = !signedIn
        signOutButton.isEnabled = signedIn
        protectedAPIButton.isEnabled = accessToken != nil
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
    
    func retrieveAPIData(request: URLRequest) {
        let task = URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                print("Error found when accessing API: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.showResultText(error.localizedDescription)
                }
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode)
            else {
                print("Unsuccessful response found when accessing the API")
                return
            }
            
            DispatchQueue.main.async {
                self.showResultText("Http response code is: \(httpResponse.statusCode)")
            }
        }
        
        task.resume()
    }
}

// MARK: - Sign Up delegates

// MARK: SignUpStartDelegate

extension ProtectedAPIViewController: SignUpStartDelegate {
    func onSignUpStartError(error: MSAL.SignUpStartError) {
        if error.isUserAlreadyExists {
            showResultText("Unable to sign up: User already exists")
        } else if error.isInvalidPassword {
            showResultText("Unable to sign up: The password is invalid")
        } else if error.isInvalidUsername {
            showResultText("Unable to sign up: The username is invalid")
        } else {
            showResultText("Unexpected error signing up: \(error.errorDescription ?? "No error description")")
        }
    }

    func onSignUpCodeRequired(newState: MSAL.SignUpCodeRequiredState,
                              sentTo _: String,
                              channelTargetType _: MSAL.MSALNativeAuthChannelType,
                              codeLength _: Int) {
        print("SignUpStartDelegate: onSignUpCodeRequired: \(newState)")

        showVerifyCodeModal(submitCallback: { [weak self] code in
                                guard let self = self else { return }

                                newState.submitCode(code: code, delegate: self)
                            },
                            resendCallback: { [weak self] in
                                guard let self = self else { return }

                                newState.resendCode(delegate: self)
                            })
    }
}

// MARK: SignUpVerifyCodeDelegate

extension ProtectedAPIViewController: SignUpVerifyCodeDelegate {
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
                                  })
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

extension ProtectedAPIViewController: SignUpResendCodeDelegate {

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
                              })
    }
}

// MARK: SignInAfterSignUpDelegate

extension ProtectedAPIViewController: SignInAfterSignUpDelegate {
    func onSignInAfterSignUpError(error: MSAL.SignInAfterSignUpError) {
        showResultText("Error signing in after signing up.")
    }
}

// MARK: - Sign In delegates

// MARK: SignInStartDelegate

extension ProtectedAPIViewController: SignInStartDelegate {
    func onSignInCompleted(result: MSAL.MSALNativeAuthUserAccountResult) {
        print("Signed in: \(result.account.username ?? "")")

        accountResult = result

        result.getAccessToken(delegate: self)
    }

    func onSignInStartError(error: MSAL.SignInStartError) {
        print("SignInStartDelegate: onSignInStartError: \(error)")
        
        if error.isUserNotFound || error.isInvalidCredentials || error.isInvalidUsername {
            showResultText("Invalid username or password")
        } else {
            showResultText("Error while signing in: \(error.errorDescription ?? "No error description")")
        }
    }
}

// MARK: - Credentials delegates

// MARK: CredentialsDelegate

extension ProtectedAPIViewController: CredentialsDelegate {
    func onAccessTokenRetrieveCompleted(accessToken: String) {
        print("Access Token: \(accessToken)")
        self.accessToken = accessToken
        showResultText("Signed in. Access Token: \(accessToken)")
        updateUI()
    }

    func onAccessTokenRetrieveError(error: MSAL.RetrieveAccessTokenError) {
        showResultText("Error retrieving access token: \(error.errorDescription ?? "No error description")")
    }
}

// MARK: - Verify Code modal methods

extension ProtectedAPIViewController {
    func showVerifyCodeModal(
        submitCallback: @escaping (_ code: String) -> Void,
        resendCallback: @escaping () -> Void
    ) {
        verifyCodeViewController = storyboard?.instantiateViewController(
            withIdentifier: "VerifyCodeViewController") as? VerifyCodeViewController

        guard let verifyCodeViewController = verifyCodeViewController else {
            print("Error creating Verify Code view controller")
            return
        }

        updateVerifyCodeModal(errorMessage: nil,
                              submitCallback: submitCallback,
                              resendCallback: resendCallback)

        present(verifyCodeViewController, animated: true)
    }

    func updateVerifyCodeModal(
        errorMessage: String?,
        submitCallback: @escaping (_ code: String) -> Void,
        resendCallback: @escaping () -> Void
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

