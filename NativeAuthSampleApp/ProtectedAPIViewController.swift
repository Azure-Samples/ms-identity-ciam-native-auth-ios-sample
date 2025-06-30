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
 * ProtectedAPIViewController class implements samples for accessing custom web APIs using Entra External ID identity tokens.
 * Learn documentation: https://learn.microsoft.com/en-us/entra/external-id/customers/sample-native-authentication-ios-sample-app-call-web-api
 */
class ProtectedAPIViewController: UIViewController {

    let protectedAPIUrl1: String? = nil // Developers should set the URL of their first web API resource here
    let protectedAPIUrl2: String? = nil // Developers should set the URL of their second web API resource here
    // Developers should set the respective scopes for their web API resources here, for example: ["api://<Resource_App_ID>/ToDoList.Read", "api://<Resource_App_ID>/ToDoList.ReadWrite"]
    let protectedAPIScopes1: [String] = []
    let protectedAPIScopes2: [String] = []
    
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var resultTextView: UITextView!

    @IBOutlet weak var signInButton: UIButton!
    @IBOutlet weak var signOutButton: UIButton!
    @IBOutlet weak var api1Button: UIButton!
    @IBOutlet weak var api2Button: UIButton!
    
    var nativeAuth: MSALNativeAuthPublicClientApplication!

    var verifyCodeViewController: VerifyCodeViewController?

    var accountResult: MSALNativeAuthUserAccountResult?
    
    var accessTokenAPI1: String?
    var accessTokenAPI2: String?

    override func viewDidLoad() {
        super.viewDidLoad()

        do {
            let config = try MSALNativeAuthPublicClientApplicationConfig(
                clientId: Configuration.clientId,
                tenantSubdomain: Configuration.tenantSubdomain,
                challengeTypes: [.OOB, .password]
            )
            nativeAuth = try MSALNativeAuthPublicClientApplication(nativeAuthConfiguration: config)
        } catch {
            print("Unable to initialize MSAL \(error)")
            showResultText("Unable to initialize MSAL: \(error.localizedDescription)")
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

        let parameters = MSALNativeAuthSignInParameters(username: email)
        parameters.password = password
        parameters.scopes = []
        nativeAuth.signIn(parameters: parameters, delegate: self)
    }

    @IBAction func signOutPressed(_: Any) {
        view.endEditing(true)

        guard accountResult != nil else {
            print("signOutPressed: Not currently signed in")
            return
        }
        accountResult?.signOut()

        accountResult = nil
        accessTokenAPI1 = nil
        accessTokenAPI2 = nil

        showResultText("Signed out")
        updateUI()
    }
    
    @IBAction func protectedApi1Pressed(_: Any) {
        view.endEditing(true)

        guard let url = protectedAPIUrl1, !protectedAPIScopes1.isEmpty else {
            showResultText("API 1 not configured.")
            return
        }
        
        if let accessToken = accessTokenAPI1 {
            accessProtectedAPI(apiUrl: url, accessToken: accessToken)
        } else {
            let parameters = MSALNativeAuthGetAccessTokenParameters()
            parameters.scopes = protectedAPIScopes1
            accountResult?.getAccessToken(parameters: parameters, delegate: self)
            let message = "Retrieving access token to use with API 1..."
            showResultText(message)
            print(message)
        }
    }
    
    @IBAction func protectedApi2Pressed(_: Any) {
        view.endEditing(true)

        guard let url = protectedAPIUrl2, !protectedAPIScopes2.isEmpty else {
            showResultText("API 2 not configured.")
            return
        }
        
        if let accessToken = accessTokenAPI2 {
            accessProtectedAPI(apiUrl: url, accessToken: accessToken)
        } else {
            let parameters = MSALNativeAuthGetAccessTokenParameters()
            parameters.scopes = protectedAPIScopes2
            accountResult?.getAccessToken(parameters: parameters, delegate: self)
            let message = "Retrieving access token to use with API 2..."
            showResultText(message)
            print(message)
        }
    }
    
    func showResultText(_ text: String) {
        resultTextView.text = text
    }

    func updateUI() {
        let signedIn = (accountResult != nil)

        signInButton.isEnabled = !signedIn
        signOutButton.isEnabled = signedIn
        api1Button.isEnabled = signedIn
        api2Button.isEnabled = signedIn
    }

    func retrieveCachedAccount() {
        accountResult = nativeAuth.getNativeAuthUserAccount()
        if let accountResult = accountResult, let username = accountResult.account.username {
            self.showResultText("Account found in cache: \(username)")
            self.accountResult = accountResult
            updateUI()
        } else {
            self.showResultText("No account found in cache. Please Sign in")

            accountResult = nil

            showResultText("")

            updateUI()
        }
    }
    
    func accessProtectedAPI(apiUrl: String, accessToken: String) {
        guard let url = URL(string: apiUrl) else {
            let errorMessage = "Invalid API url"
            print(errorMessage)
            DispatchQueue.main.async {
                self.showResultText(errorMessage)
            }
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
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode)
            else {
                DispatchQueue.main.async {
                    self.showResultText("Unsuccessful response found when accessing the API")
                }
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
        showResultText("Signed in: \(result.account.username ?? "")")
        accountResult = result
        updateUI()
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

        if protectedAPIScopes1.allSatisfy(result.scopes.contains),
           let url = protectedAPIUrl1
        {
            accessTokenAPI1 = result.accessToken
            accessProtectedAPI(apiUrl: url, accessToken: result.accessToken)
        }
        
        if protectedAPIScopes2.allSatisfy(result.scopes.contains(_:)),
           let url = protectedAPIUrl2
        {
            accessTokenAPI2 = result.accessToken
            accessProtectedAPI(apiUrl: url, accessToken: result.accessToken)
        }
        
        showResultText("Signed in." + "\n\n" + "Scopes:\n\(result.scopes)" + "\n\n" + "Access Token:\n\(result.accessToken)")
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
