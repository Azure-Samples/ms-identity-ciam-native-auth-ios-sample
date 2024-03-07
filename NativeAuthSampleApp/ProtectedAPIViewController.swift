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

class ProtectedAPIViewController: UIViewController {
    let protectedAPIUrl = "Enter_the_Protected_API_Full_URL_Here"
    let protectedAPIScopes = ["Enter_the_Protected_API_Scopes_Here"]
    
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var resultTextView: UITextView!

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

    @IBAction func signInPressed(_: Any) {
        guard let email = emailTextField.text, let password = passwordTextField.text else {
            resultTextView.text = "Email or password not set"
            return
        }

        print("Signing in with email \(email) and password")

        showResultText("Signing in...")

        nativeAuth.signIn(username: email, password: password, scopes: protectedAPIScopes, delegate: self)
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
        guard let accessToken = self.accessToken else {
            let errorMessage = "No access token found"
            print(errorMessage)
            showResultText(errorMessage)
            return
        }
        
        accessProtectedAPI(accessToken: accessToken)
    }
    
    func showResultText(_ text: String) {
        resultTextView.text = text
    }

    func updateUI() {
        let signedIn = (accountResult != nil)

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
    
    func accessProtectedAPI(accessToken: String) {
        guard let url = URL(string: protectedAPIUrl) else {
            let errorMessage = "Invalid API url"
            print(errorMessage)
            showResultText(errorMessage)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error found when accessing API: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.showResultText(error.localizedDescription)
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode)
            else {
                print("Unsuccessful response found when accessing the API")
                return
            }
            
            guard let data = data, let result = try? JSONSerialization.jsonObject(with: data, options: []) else {
                DispatchQueue.main.async {
                    self.showResultText("Couldn't deserialize result JSON")
                }
                return
            }
            
            DispatchQueue.main.async {
                self.showResultText("""
                                Accessed API successfully using access token.
                                HTTP response code: \(httpResponse.statusCode)
                                HTTP response body: \(result)
                                """)
            }
        }
        
        task.resume()
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
    func onAccessTokenRetrieveCompleted(result: MSALNativeAuthTokenResult) {
        print("Access Token: \(result.accessToken)")
        self.accessToken = result.accessToken
        showResultText("Signed in. Access Token: \(result.accessToken)")
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

