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

extension EmailAndPasswordViewController: MSALNativeAuthRequestInterceptor
{
    func addAdditionalHeaderFields(_ requestUrl: URL?, completionBlock: @escaping MSALNativeAuthRequestInterceptorAddHeaderCompletionBlock)
    {
        if requestUrl?.absoluteString.contains("oauth2/v2.0/initiate") == true {
            completionBlock(
                ["value_1": "customer_header_1", // Will be ignored: doesn't start with "x-"
                 "x-client-header": "customer_header_2", // Will be ignored: starts with reserved prefix "x-client-"
                 "X-my-custom-header": "my data", // Will be added to the network request.
                 "x-test-header": "test_data" // Will be added to the network request.
                ])
            return;
        }
        
        completionBlock(nil)
    }
}

class EmailAndPasswordViewController: UIViewController {
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var resultTextView: UITextView!

    @IBOutlet weak var signUpButton: UIButton!
    @IBOutlet weak var signInButton: UIButton!
    @IBOutlet weak var signOutButton: UIButton!

    var nativeAuth: MSALNativeAuthPublicClientApplication!

    var authManager: AuthManager!

    var verifyCodeViewController: VerifyCodeViewController?
    var attributeCollectionViewController: AttributeCollectionViewController?

    /// Attributes from the most recent V2 `attributesRequired` action, kept so the
    /// collection modal can be re-presented (e.g. after `attributesInvalid`).
    var lastRequiredAttributesV2: [MSALNativeAuthRequiredAttribute] = []

    var accountResult: MSALNativeAuthUserAccountResult?

    override func viewDidLoad() {
        super.viewDidLoad()

        do {
            let config = try MSALNativeAuthPublicClientApplicationConfig(
                clientId: Configuration.clientId,
                tenantSubdomain: Configuration.tenantSubdomain,
                challengeTypes: [.OOB, .password]
            )
            
            config.requestInterceptor = self
            
            config.sliceConfig = Configuration.sliceConfig
            nativeAuth = try MSALNativeAuthPublicClientApplication(nativeAuthConfiguration: config)
            configureAuthManager()
        } catch {
            print("Unable to initialize MSAL \(error)")
            showResultText("Unable to initialize MSAL: \(error.localizedDescription)")
        }
    }

    /// Wires the V2 unified delegate (``AuthManager``) up to this screen. The manager — not
    /// `self` — is the ``MSALNativeAuthFlowDelegate``; each server-driven action is mapped onto the
    /// *same* reusable modals the V1 delegate path uses, so V2 and V1 share one UI without V1 being
    /// affected.
    func configureAuthManager() {
        authManager = AuthManager(application: nativeAuth)

        authManager.onActionRequired = { [weak self] action in
            guard let self = self else { return }

            switch action {
            case .codeRequired(let sentTo, _, let codeLength),
                 .mfaVerificationRequired(let sentTo, _, let codeLength),
                 .strongAuthVerificationRequired(let sentTo, _, let codeLength):
                self.showResultText("Code sent to \(sentTo) (\(codeLength) digits)")
                self.presentVerifyCodeModalV2()
            case .attributesRequired(let attributes):
                self.presentAttributeCollectionModalV2(attributes: attributes)
            case .attributesInvalid(let attributeNames):
                self.showResultText("Invalid attributes: \(attributeNames.joined(separator: ", "))")
                self.presentAttributeCollectionModalV2(attributes: self.lastRequiredAttributesV2)
            case .mfaRequired(let authMethods), .strongAuthRegistrationRequired(let authMethods):
                guard let method = authMethods.first else {
                    self.showResultText("No auth methods available")
                    return
                }
                self.authManager.selectAuthMethod(method, verificationContact: nil)
            default:
                self.showResultText("Action required: \(AuthManager.describe(action))")
            }
        }

        authManager.onCompleted = { [weak self] result in
            guard let self = self else { return }
            self.dismissAnyV2Modal()
            self.accountResult = result
            self.updateUI()
            self.showResultText("Signed in: \(result.account.username ?? "")")
        }

        authManager.onError = { [weak self] error in
            guard let self = self else { return }

            if error.isInvalidCode {
                self.updateVerifyCodeModal(errorMessage: "Invalid code",
                                           submitCallback: { [weak self] code in self?.submitCodeOrChallengeV2(code) },
                                           resendCallback: { [weak self] in self?.authManager.resendCode() },
                                           cancelCallback: { [weak self] in
                                               self?.dismissVerifyCodeModal()
                                               self?.showResultText("Action cancelled")
                                           })
            } else {
                self.dismissAnyV2Modal()
                self.showResultText("Error: \(error.errorDescription ?? "No error description")")
            }
        }

        authManager.onBrowserRequired = { [weak self] url in
            guard let self = self else { return }
            self.dismissAnyV2Modal()
            self.showResultText("Web UX required (\(url.absoluteString))")
        }
    }

    /// Routes a verify-code submission to the correct V2 continuation: primary OOB codes use
    /// `submitCode`, whereas MFA / strong-auth verification codes use `submitChallenge`.
    private func submitCodeOrChallengeV2(_ code: String) {
        switch authManager.latestAction {
        case .mfaVerificationRequired, .strongAuthVerificationRequired:
            authManager.submitChallenge(code)
        default:
            authManager.submitCode(code)
        }
    }

    private func presentVerifyCodeModalV2() {
        let submit: (String) -> Void = { [weak self] code in self?.submitCodeOrChallengeV2(code) }
        let resend: () -> Void = { [weak self] in self?.authManager.resendCode() }
        let cancel: () -> Void = { [weak self] in
            self?.dismissVerifyCodeModal()
            self?.showResultText("Action cancelled")
        }

        if verifyCodeViewController != nil {
            updateVerifyCodeModal(errorMessage: nil, submitCallback: submit, resendCallback: resend, cancelCallback: cancel)
            return
        }

        // If the attribute collection modal is still on screen (e.g. after submitting
        // attributes the server asks for a code), dismiss it first and only then present
        // the verify-code modal — UIKit cannot present a second modal while another is up.
        if attributeCollectionViewController != nil {
            dismissAttributeCollectionModal { [weak self] in
                self?.showVerifyCodeModal(submitCallback: submit, resendCallback: resend, cancelCallback: cancel)
            }
        } else {
            showVerifyCodeModal(submitCallback: submit, resendCallback: resend, cancelCallback: cancel)
        }
    }

    private func presentAttributeCollectionModalV2(attributes: [MSALNativeAuthRequiredAttribute]) {
        lastRequiredAttributesV2 = attributes
        guard attributeCollectionViewController == nil else { return }

        let present: () -> Void = { [weak self] in
            self?.showAttributeCollectionModal(attributes: attributes, submitCallback: { [weak self] collected in
                self?.authManager.submitAttributes(collected)
            }, cancelCallback: { [weak self] in
                self?.showResultText("Action cancelled")
            })
        }

        // If the verify-code modal is still on screen (e.g. the server asked for a code
        // before collecting attributes), dismiss it first and only then present the
        // attribute modal — UIKit cannot present a second modal while another is up.
        if verifyCodeViewController != nil {
            dismissVerifyCodeModal(completion: present)
        } else {
            present()
        }
    }

    private func dismissAnyV2Modal() {
        if verifyCodeViewController != nil { dismissVerifyCodeModal() }
        if attributeCollectionViewController != nil { dismissAttributeCollectionModal() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        retrieveCachedAccount()
    }

    @IBAction func signUpPressed(_: Any) {
        view.endEditing(true)

        guard let email = emailTextField.text, let password = passwordTextField.text else {
            resultTextView.text = "Email or password not set"
            return
        }

        print("Signing up with email \(email) and password")

        showResultText("Signing up...")

        let parameters = MSALNativeAuthSignUpParameters(username: email)
        parameters.password = password
        if Configuration.useNativeAuthV2 {
            authManager.signUp(email: email, password: password)
        } else {
            nativeAuth.signUp(parameters: parameters, delegate: self)
        }
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
        if Configuration.useNativeAuthV2 {
            authManager.signIn(email: email, password: password)
        } else {
            nativeAuth.signIn(parameters: parameters, delegate: self)
        }
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

        signUpButton.isEnabled = !signedIn
        signInButton.isEnabled = !signedIn
        signOutButton.isEnabled = signedIn
    }

    func retrieveCachedAccount() {
        accountResult = nativeAuth.getNativeAuthUserAccount()
        if let accountResult = accountResult, let homeAccountId = accountResult.account.homeAccountId?.identifier {
            print("Account found in cache: \(homeAccountId)")
            let parameters = MSALNativeAuthGetAccessTokenParameters()
            accountResult.getAccessToken(parameters: parameters, delegate: self)
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

extension EmailAndPasswordViewController: SignUpStartDelegate {
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
                            }, cancelCallback: { [weak self] in
                                guard let self = self else { return }

                                showResultText("Action cancelled")
                            })
    }
}

// MARK: SignUpVerifyCodeDelegate

extension EmailAndPasswordViewController: SignUpVerifyCodeDelegate {
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
        } else {
            showResultText("Unexpected error verifying code: \(error.errorDescription ?? "No error description")")
            dismissVerifyCodeModal()
        }
    }

    func onSignUpCompleted(newState: MSAL.SignInAfterSignUpState) {
        showResultText("Signed up successfully!")
        dismissVerifyCodeModal()
        dismissAttributeCollectionModal()
        let parameters = MSALNativeAuthSignInAfterSignUpParameters()
        newState.signIn(parameters: parameters, delegate: self)
    }

    func onSignUpAttributesRequired(attributes: [MSAL.MSALNativeAuthRequiredAttribute], newState: MSAL.SignUpAttributesRequiredState) {
        print("SignUpVerifyCodeDelegate: onSignUpAttributesRequired: \(attributes)")

        // Custom implementation for Flat Username / Alias
        if attributes.filter({$0.name == "flatusername"}).isEmpty == false && attributes.count == 1 {
            let showAttributes = { [weak self] in
                guard let self = self else { return }

                self.showAttributeCollectionModal(
                    attributes: attributes,
                    submitCallback: { [weak self] collected in
                        guard let self = self else { return }

                        let submitted: [String: Any] = collected
                        newState.submitAttributes(attributes: submitted, delegate: self)
                    },
                    cancelCallback: { [weak self] in
                        guard let self = self else { return }

                        self.showResultText("Action cancelled")
                    }
                )
            }

            if verifyCodeViewController != nil {
                dismiss(animated: true) {
                    self.verifyCodeViewController = nil
                    showAttributes()
                }
            } else {
                showAttributes()
            }
        }
    }
}

// MARK: SignUpAttributesRequiredDelegate

extension EmailAndPasswordViewController: SignUpAttributesRequiredDelegate {
    func onSignUpAttributesRequiredError(error: AttributesRequiredError) {
        showResultText("Error submitting attributes: \(error.errorDescription ?? "No error description")")
        dismissAttributeCollectionModal()
    }

    func onSignUpAttributesInvalid(attributeNames: [String], newState: SignUpAttributesRequiredState) {
        showResultText("Invalid attribute(s): \(attributeNames.joined(separator: ", "))")
        dismissAttributeCollectionModal()
    }
}

// MARK: SignUpResendCodeDelegate

extension EmailAndPasswordViewController: SignUpResendCodeDelegate {

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

extension EmailAndPasswordViewController: SignInAfterSignUpDelegate {
    func onSignInAfterSignUpError(error: MSAL.SignInAfterSignUpError) {
        showResultText("Error signing in after signing up.")
    }
}

// MARK: - Sign In delegates

// MARK: SignInStartDelegate

extension EmailAndPasswordViewController: SignInStartDelegate {
    func onSignInCompleted(result: MSAL.MSALNativeAuthUserAccountResult) {
        print("Signed in: \(result.account.username ?? "")")

        accountResult = result
        let parameters = MSALNativeAuthGetAccessTokenParameters()
        result.getAccessToken(parameters: parameters, delegate: self)
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

extension EmailAndPasswordViewController: CredentialsDelegate {
    func onAccessTokenRetrieveCompleted(result: MSALNativeAuthTokenResult) {
        print("Access Token: \(result.accessToken)")
        showResultText("Signed in. Access Token: \(result.accessToken)")
        updateUI()
    }

    func onAccessTokenRetrieveError(error: MSAL.RetrieveAccessTokenError) {
        showResultText("Error retrieving access token: \(error.errorDescription ?? "No error description")")
    }
}

// MARK: - Verify Code modal methods

extension EmailAndPasswordViewController {
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
            completion?()
            return
        }

        dismiss(animated: true, completion: completion)
        verifyCodeViewController = nil
    }
}

// MARK: - Attribute Collection modal methods

extension EmailAndPasswordViewController {
    func showAttributeCollectionModal(
        attributes: [MSALNativeAuthRequiredAttribute],
        submitCallback: @escaping (_ attributes: [String: String]) -> Void,
        cancelCallback: @escaping () -> Void
    ) {
        attributeCollectionViewController = storyboard?.instantiateViewController(
            withIdentifier: "AttributeCollectionViewContoller") as? AttributeCollectionViewController

        guard let attributeCollectionViewController = attributeCollectionViewController else {
            print("Error creating Attribute Collection view controller")
            return
        }

        attributeCollectionViewController.requiredAttributes = attributes

        attributeCollectionViewController.onSubmit = { collected in
            DispatchQueue.main.async {
                submitCallback(collected)
            }
        }

        attributeCollectionViewController.onCancel = {
            DispatchQueue.main.async {
                cancelCallback()
            }
        }

        present(attributeCollectionViewController, animated: true)
    }

    func dismissAttributeCollectionModal(completion: (() -> Void)? = nil) {
        guard attributeCollectionViewController != nil else {
            print("Unexpected error: Attribute Collection view controller is nil")
            completion?()
            return
        }

        dismiss(animated: true, completion: completion)
        attributeCollectionViewController = nil
    }
}
