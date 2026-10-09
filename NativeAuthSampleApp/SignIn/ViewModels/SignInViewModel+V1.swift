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

// MARK: - V1 flow helpers

extension SignInViewModel
{
    /// Points the shared verify-code modal callbacks at a V1 sign-in code state.
    private func wireV1SignInCodeCallbacks(_ state: SignInCodeRequiredState)
    {
        onSubmitCode = { [weak self] code in
            guard let self = self else { return }
            state.submitCode(code: code, delegate: self)
        }
        onResendCode = { [weak self] in
            guard let self = self else { return }
            state.resendCode(delegate: self)
        }
    }

    /// Points the shared verify-code modal callbacks at a V1 reset-password code state.
    private func wireV1ResetPasswordCodeCallbacks(_ state: ResetPasswordCodeRequiredState)
    {
        onSubmitCode = { [weak self] code in
            guard let self = self else { return }
            state.submitCode(code: code, delegate: self)
        }
        onResendCode = { [weak self] in
            guard let self = self else { return }
            state.resendCode(delegate: self)
        }
    }

    /// Points the shared new-password modal callback at a V1 reset-password required state.
    private func wireV1ResetPasswordNewPasswordCallback(_ state: ResetPasswordRequiredState)
    {
        onSubmitNewPassword = { [weak self] password in
            guard let self = self else { return }
            state.submitPassword(password: password, delegate: self)
        }
    }

    /// Shared completion handling for the granular V1 delegates.
    private func handleV1SignInCompleted(result: MSALNativeAuthUserAccountResult)
    {
        resetFlowState()
        accountResult = result
        dismissAnyModal()
        isSigningIn = false
        isSignedIn = true
        statusMessage = "Signed in as \(result.account.username ?? "unknown user")."
    }

    private func handleV1Error(_ message: String)
    {
        dismissAnyModal()
        isSigningIn = false
        statusMessage = message
    }
}

// MARK: - V1 Sign In delegates

extension SignInViewModel: SignInStartDelegate
{
    func onSignInStartError(error: SignInStartError)
    {
        if error.isUserNotFound || error.isInvalidCredentials || error.isInvalidUsername
        {
            handleV1Error("Invalid username or password.")
        }
        else
        {
            handleV1Error("Sign in failed: \(error.errorDescription ?? "unknown error").")
        }
    }

    func onSignInCodeRequired(
        newState: SignInCodeRequiredState,
        sentTo: String,
        channelTargetType: MSALNativeAuthChannelType,
        codeLength: Int
    )
    {
        statusMessage = "Code sent to \(sentTo) (\(codeLength) digits)."
        wireV1SignInCodeCallbacks(newState)
        presentVerifyCodeModal()
    }

    func onSignInCompleted(result: MSALNativeAuthUserAccountResult)
    {
        handleV1SignInCompleted(result: result)
    }
}

extension SignInViewModel: SignInVerifyCodeDelegate
{
    func onSignInVerifyCodeError(error: VerifyCodeError, newState: SignInCodeRequiredState?)
    {
        if error.isInvalidCode, let newState = newState
        {
            wireV1SignInCodeCallbacks(newState)
            updateVerifyCodeModal(errorMessage: "Check the code and try again")
        }
        else
        {
            handleV1Error("Sign in failed: \(error.errorDescription ?? "unknown error").")
        }
    }
}

extension SignInViewModel: SignInResendCodeDelegate
{
    func onSignInResendCodeError(error: ResendCodeError, newState: SignInCodeRequiredState?)
    {
        handleV1Error("Unable to resend the code.")
    }

    func onSignInResendCodeCodeRequired(
        newState: SignInCodeRequiredState,
        sentTo: String,
        channelTargetType: MSALNativeAuthChannelType,
        codeLength: Int
    )
    {
        wireV1SignInCodeCallbacks(newState)
        updateVerifyCodeModal(errorMessage: nil)
    }
}

// MARK: - V1 MFA flow

// These optional callbacks are declared on `SignInStartDelegate`, `SignInVerifyCodeDelegate` and
// `SignInPasswordRequiredDelegate`. They fire only when the app opts in with
// `config.capabilities = [.mfaRequired, .registrationRequired]`. A single implementation on the
// class satisfies every protocol that declares the same Obj-C selector.

extension SignInViewModel
{
    /// The server requires MFA. Pick an authentication method (auto-proceed when there is only one,
    /// otherwise let the user choose) and request the challenge for it.
    @MainActor @objc
    func onSignInAwaitingMFA(authMethods: [MSALAuthMethod], newState: AwaitingMFAState)
    {
        guard let firstMethod = authMethods.first else
        {
            handleV1Error("MFA is required but no authentication methods are available.")
            return
        }

        if authMethods.count > 1
        {
            statusMessage = "Select an authentication method."
            self.authMethods = authMethods
            onSelectAuthMethod = { [weak self] method in
                guard let self = self else { return }
                self.dismissAnyModal()
                newState.requestChallenge(authMethod: method, delegate: self)
            }
            presentSelectAuthMethodModal()
            return
        }

        statusMessage = "Sending authentication challenge…"
        newState.requestChallenge(authMethod: firstMethod, delegate: self)
    }
}

extension SignInViewModel: MFARequestChallengeDelegate
{
    func onMFARequestChallengeError(error: MFARequestChallengeError, newState: MFARequiredState?)
    {
        handleV1Error("MFA challenge failed: \(error.errorDescription ?? "unknown error").")
    }

    func onMFARequestChallengeSelectionRequired(authMethods: [MSALAuthMethod], newState: MFARequiredState)
    {
        statusMessage = "Select an authentication method."
        self.authMethods = authMethods
        onSelectAuthMethod = { [weak self] method in
            guard let self = self else { return }
            self.dismissAnyModal()
            newState.requestChallenge(authMethod: method, delegate: self)
        }
        presentSelectAuthMethodModal()
    }

    func onMFARequestChallengeVerificationRequired(
        newState: MFARequiredState,
        sentTo: String,
        channelTargetType: MSALNativeAuthChannelType,
        codeLength: Int
    )
    {
        statusMessage = "Code sent to \(sentTo) (\(codeLength) digits)."
        onSubmitCode = { [weak self] code in
            guard let self = self else { return }
            newState.submitChallenge(challenge: code, delegate: self)
        }
        onResendCode = nil
        presentVerifyCodeModal()
    }
}

extension SignInViewModel: MFASubmitChallengeDelegate
{
    func onMFASubmitChallengeError(error: MFASubmitChallengeError, newState: MFARequiredState?)
    {
        if error.isInvalidChallenge, let newState = newState
        {
            onSubmitCode = { [weak self] code in
                guard let self = self else { return }
                newState.submitChallenge(challenge: code, delegate: self)
            }
            updateVerifyCodeModal(errorMessage: "Check the code and try again")
        }
        else
        {
            handleV1Error("MFA verification failed: \(error.errorDescription ?? "unknown error").")
        }
    }

    // onSignInCompleted(result:) is implemented once in the SignInStartDelegate extension and
    // satisfies this protocol's optional completion callback as well.
}

// MARK: - V1 strong-auth registration (JIT) flow

extension SignInViewModel
{
    /// The server requires the user to register a strong authentication method. Ask the user to
    /// select a supported method and enter the email address or phone number to register.
    @MainActor @objc
    func onSignInStrongAuthMethodRegistration(authMethods: [MSALAuthMethod], newState: RegisterStrongAuthState)
    {
        let supportedMethods = authMethods.filter
        {
            $0.channelTargetType.isEmailType || $0.channelTargetType.isSMSType
        }

        guard !supportedMethods.isEmpty else
        {
            handleV1Error("Strong authentication registration is required but no supported methods are available.")
            return
        }

        statusMessage = "Select an authentication method to register."
        self.authMethods = supportedMethods
        onSelectAuthMethod = { [weak self] method in
            guard let self = self else { return }
            self.registrationAuthMethod = method
            self.statusMessage = method.channelTargetType.isSMSType
                ? "Enter the phone number to register."
                : "Enter the email address to register."
            self.onSubmitVerificationContact = { [weak self] verificationContact in
                guard let self = self else { return }
                self.dismissAnyModal()
                self.statusMessage = "Registering authentication method…"
                let parameters = MSALNativeAuthChallengeAuthMethodParameters(
                    authMethod: method,
                    verificationContact: verificationContact
                )
                newState.challengeAuthMethod(parameters: parameters, delegate: self)
            }
            self.presentVerificationContactModal()
        }
        presentSelectAuthMethodModal()
    }
}

extension SignInViewModel: RegisterStrongAuthChallengeDelegate
{
    func onRegisterStrongAuthChallengeError(error: RegisterStrongAuthChallengeError, newState: RegisterStrongAuthState?)
    {
        handleV1Error("Strong authentication registration failed: \(error.errorDescription ?? "unknown error").")
    }

    func onRegisterStrongAuthVerificationRequired(result: MSALNativeAuthRegisterStrongAuthVerificationRequiredResult)
    {
        statusMessage = "Code sent to \(result.sentTo) (\(result.codeLength) digits)."
        let verificationState = result.newState
        onSubmitCode = { [weak self] code in
            guard let self = self else { return }
            verificationState.submitChallenge(challenge: code, delegate: self)
        }
        onResendCode = nil
        presentVerifyCodeModal()
    }

    // onSignInCompleted(result:) is implemented once in the SignInStartDelegate extension and
    // satisfies this protocol's optional completion callback as well.
}

extension SignInViewModel: RegisterStrongAuthSubmitChallengeDelegate
{
    func onRegisterStrongAuthSubmitChallengeError(
        error: RegisterStrongAuthSubmitChallengeError,
        newState: RegisterStrongAuthVerificationRequiredState?
    )
    {
        if error.isInvalidChallenge, let newState = newState
        {
            onSubmitCode = { [weak self] code in
                guard let self = self else { return }
                newState.submitChallenge(challenge: code, delegate: self)
            }
            updateVerifyCodeModal(errorMessage: "Check the code and try again")
        }
        else
        {
            handleV1Error("Strong authentication verification failed: \(error.errorDescription ?? "unknown error").")
        }
    }

    // onSignInCompleted(result:) is implemented once in the SignInStartDelegate extension and
    // satisfies this protocol's optional completion callback as well.
}

// MARK: - V1 Reset Password delegates

extension SignInViewModel: ResetPasswordStartDelegate
{
    func onResetPasswordStartError(error: ResetPasswordStartError)
    {
        if error.isInvalidUsername || error.isUserNotFound
        {
            handleV1Error("Unable to reset password: the email is invalid.")
        }
        else if error.isUserDoesNotHavePassword
        {
            handleV1Error("Unable to reset password: no password associated with this email.")
        }
        else
        {
            handleV1Error("Unable to reset password: \(error.errorDescription ?? "unknown error").")
        }
    }

    func onResetPasswordCodeRequired(
        newState: ResetPasswordCodeRequiredState,
        sentTo: String,
        channelTargetType: MSALNativeAuthChannelType,
        codeLength: Int
    )
    {
        statusMessage = "Code sent to \(sentTo) (\(codeLength) digits)."
        wireV1ResetPasswordCodeCallbacks(newState)
        presentVerifyCodeModal()
    }
}

extension SignInViewModel: ResetPasswordVerifyCodeDelegate
{
    func onResetPasswordVerifyCodeError(error: VerifyCodeError, newState: ResetPasswordCodeRequiredState?)
    {
        if error.isInvalidCode, let newState = newState
        {
            wireV1ResetPasswordCodeCallbacks(newState)
            updateVerifyCodeModal(errorMessage: "Check the code and try again")
        }
        else
        {
            handleV1Error("Unable to reset password: \(error.errorDescription ?? "unknown error").")
        }
    }

    func onPasswordRequired(newState: ResetPasswordRequiredState)
    {
        wireV1ResetPasswordNewPasswordCallback(newState)
        presentNewPasswordModal()
    }
}

extension SignInViewModel: ResetPasswordResendCodeDelegate
{
    func onResetPasswordResendCodeError(error: ResendCodeError, newState: ResetPasswordCodeRequiredState?)
    {
        handleV1Error("Unable to resend the code.")
    }

    func onResetPasswordResendCodeRequired(
        newState: ResetPasswordCodeRequiredState,
        sentTo: String,
        channelTargetType: MSALNativeAuthChannelType,
        codeLength: Int
    )
    {
        wireV1ResetPasswordCodeCallbacks(newState)
        updateVerifyCodeModal(errorMessage: nil)
    }
}

extension SignInViewModel: ResetPasswordRequiredDelegate
{
    func onResetPasswordRequiredError(error: PasswordRequiredError, newState: ResetPasswordRequiredState?)
    {
        if error.isInvalidPassword, let newState = newState
        {
            wireV1ResetPasswordNewPasswordCallback(newState)
            updateNewPasswordModal(errorMessage: "Invalid password")
        }
        else
        {
            handleV1Error("Error setting password: \(error.errorDescription ?? "unknown error").")
        }
    }

    func onResetPasswordCompleted(newState: SignInAfterResetPasswordState)
    {
        dismissAnyModal()
        statusMessage = "Password reset. Signing in…"
        let parameters = MSALNativeAuthSignInAfterResetPasswordParameters()
        newState.signIn(parameters: parameters, delegate: self)
    }
}

extension SignInViewModel: SignInAfterResetPasswordDelegate
{
    func onSignInAfterResetPasswordError(error: SignInAfterResetPasswordError)
    {
        handleV1Error("Error signing in after password reset: \(error.errorDescription ?? "unknown error").")
    }
}


// MARK: - V1 sign-up helpers

extension SignInViewModel
{
    private func wireV1SignUpCodeCallbacks(_ state: SignUpCodeRequiredState)
    {
        onSubmitCode = { [weak self] code in
            guard let self = self else { return }
            state.submitCode(code: code, delegate: self)
        }
        onResendCode = { [weak self] in
            guard let self = self else { return }
            state.resendCode(delegate: self)
        }
    }

    private func wireV1SignUpPasswordCallback(_ state: SignUpPasswordRequiredState)
    {
        onSubmitNewPassword = { [weak self] password in
            guard let self = self else { return }
            state.submitPassword(password: password, delegate: self)
        }
    }

    private func wireV1SignUpAttributesCallback(_ state: SignUpAttributesRequiredState)
    {
        onSubmitAttributes = { [weak self] attributes in
            guard let self = self else { return }
            state.submitAttributes(attributes: attributes, delegate: self)
        }
    }

    private func handleV1SignUpError(_ message: String)
    {
        dismissAnyModal()
        isSigningIn = false
        statusMessage = message
    }

    private func continueAfterV1SignUp(_ state: SignInAfterSignUpState)
    {
        dismissAnyModal()
        statusMessage = "Signed up successfully. Signing in…"
        let parameters = MSALNativeAuthSignInAfterSignUpParameters()
        state.signIn(parameters: parameters, delegate: self)
    }
}


// MARK: - V1 Sign Up delegates

extension SignInViewModel: SignUpStartDelegate,
    SignUpVerifyCodeDelegate,
    SignUpResendCodeDelegate,
    SignUpPasswordRequiredDelegate,
    SignUpAttributesRequiredDelegate
{
    func onSignUpStartError(error: SignUpStartError)
    {
        if error.isUserAlreadyExists
        {
            handleV1SignUpError("Unable to sign up: user already exists.")
        }
        else if error.isInvalidUsername
        {
            handleV1SignUpError("Unable to sign up: the email is invalid.")
        }
        else if error.isInvalidPassword
        {
            handleV1SignUpError("Unable to sign up: the password is invalid.")
        }
        else if error.isBrowserRequired
        {
            handleV1SignUpError("This flow must continue in a browser. Please sign up using the browser-based flow.")
        }
        else
        {
            handleV1SignUpError("Unable to sign up: \(error.errorDescription ?? "unknown error").")
        }
    }

    func onSignUpCodeRequired(
        newState: SignUpCodeRequiredState,
        sentTo: String,
        channelTargetType: MSALNativeAuthChannelType,
        codeLength: Int
    )
    {
        statusMessage = "Code sent to \(sentTo) (\(codeLength) digits)."
        wireV1SignUpCodeCallbacks(newState)
        presentVerifyCodeModal()
    }

    func onSignUpAttributesInvalid(attributeNames: [String])
    {
        handleV1SignUpError("Unable to sign up: invalid attribute(s): \(attributeNames.joined(separator: ", ")).")
    }

    func onSignUpVerifyCodeError(error: VerifyCodeError, newState: SignUpCodeRequiredState?)
    {
        if error.isInvalidCode, let newState = newState
        {
            wireV1SignUpCodeCallbacks(newState)
            updateVerifyCodeModal(errorMessage: "Check the code and try again")
        }
        else if error.isBrowserRequired
        {
            handleV1SignUpError("This flow must continue in a browser. Please sign up using the browser-based flow.")
        }
        else
        {
            handleV1SignUpError("Unable to verify code: \(error.errorDescription ?? "unknown error").")
        }
    }

    func onSignUpAttributesRequired(attributes: [MSALNativeAuthRequiredAttribute], newState: SignUpAttributesRequiredState)
    {
        requiredAttributes = attributes
        wireV1SignUpAttributesCallback(newState)
        dismissAnyModal()
        presentCollectAttributesModal()
    }

    func onSignUpPasswordRequired(newState: SignUpPasswordRequiredState)
    {
        wireV1SignUpPasswordCallback(newState)
        presentNewPasswordModal()
    }

    func onSignUpCompleted(newState: SignInAfterSignUpState)
    {
        continueAfterV1SignUp(newState)
    }

    func onSignUpResendCodeError(error: ResendCodeError, newState: SignUpCodeRequiredState?)
    {
        if let newState = newState
        {
            wireV1SignUpCodeCallbacks(newState)
        }
        handleV1SignUpError("Unable to resend the code: \(error.errorDescription ?? "unknown error").")
    }

    func onSignUpResendCodeCodeRequired(
        newState: SignUpCodeRequiredState,
        sentTo: String,
        channelTargetType: MSALNativeAuthChannelType,
        codeLength: Int
    )
    {
        statusMessage = "Code sent to \(sentTo) (\(codeLength) digits)."
        wireV1SignUpCodeCallbacks(newState)
        updateVerifyCodeModal(errorMessage: nil)
    }

    func onSignUpPasswordRequiredError(error: PasswordRequiredError, newState: SignUpPasswordRequiredState?)
    {
        if error.isInvalidPassword, let newState = newState
        {
            wireV1SignUpPasswordCallback(newState)
            updateNewPasswordModal(errorMessage: "Invalid password")
        }
        else
        {
            handleV1SignUpError("Error setting password: \(error.errorDescription ?? "unknown error").")
        }
    }

    func onSignUpAttributesRequiredError(error: AttributesRequiredError)
    {
        handleV1SignUpError("Error submitting attributes: \(error.errorDescription ?? "unknown error").")
    }

    func onSignUpAttributesInvalid(attributeNames: [String], newState: SignUpAttributesRequiredState)
    {
        wireV1SignUpAttributesCallback(newState)
        statusMessage = "Invalid attribute(s): \(attributeNames.joined(separator: ", ")). Please correct them and try again."
        presentCollectAttributesModal()
    }
}

// MARK: - Sign in after V1 sign-up

extension SignInViewModel: SignInAfterSignUpDelegate
{
    func onSignInAfterSignUpError(error: SignInAfterSignUpError)
    {
        handleV1SignUpError("Error signing in after sign-up: \(error.errorDescription ?? "unknown error").")
    }
}
