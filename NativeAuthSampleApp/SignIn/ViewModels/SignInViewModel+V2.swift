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

// MARK: - Native Auth V2 per-state delegates

extension SignInViewModel: MSALNativeAuthCodeRequiredDelegate,
    MSALNativeAuthPasswordRequiredDelegate,
    MSALNativeAuthExistingAccountCodeRequiredDelegate,
    MSALNativeAuthExistingAccountPasswordRequiredDelegate,
    MSALNativeAuthNewPasswordRequiredDelegate,
    MSALNativeAuthAttributesRequiredDelegate,
    MSALNativeAuthAuthMethodSelectionRequiredDelegate,
    MSALNativeAuthMFAVerificationRequiredDelegate,
    MSALNativeAuthStrongAuthRegistrationRequiredDelegate,
    MSALNativeAuthStrongAuthVerificationRequiredDelegate,
    MSALNativeAuthSignInAfterResetPasswordRequiredDelegate,
    MSALNativeAuthSignInAfterSignUpRequiredDelegate
{
    private func label(_ scenario: MSALNativeAuthFlowScenario) -> String
    {
        switch scenario
        {
        case .signIn: return "signIn"
        case .signUp: return "signUp"
        case .passwordReset: return "passwordReset"
        @unknown default: return "unknown"
        }
    }

    @MainActor
    func onCodeRequired(state: MSALNativeAuthCodeRequiredState, scenario: MSALNativeAuthFlowScenario)
    {
        print("SignInViewModel[\(label(scenario))]: state required — \(state.description)")
        statusMessage = "Code sent to \(state.sentTo) (\(state.codeLength) digits)."
        onSubmitCode = { [weak self] code in
            guard let self = self else { return }
            state.submitCode(code, delegate: self)
        }
        onResendCode = { [weak self] in
            guard let self = self else { return }
            state.resendCode(delegate: self)
        }
        presentVerifyCodeModal()
    }

    @MainActor
    func onPasswordRequired(state: MSALNativeAuthPasswordRequiredState, scenario: MSALNativeAuthFlowScenario)
    {
        print("SignInViewModel[\(label(scenario))]: state required — \(state.description)")
        statusMessage = "Submitting password…"
        state.submitPassword(password, delegate: self)
    }


    @MainActor
    func onExistingAccountCodeRequired(state: MSALNativeAuthExistingAccountCodeRequiredState, scenario: MSALNativeAuthFlowScenario)
    {
        onCodeRequired(state: state, scenario: scenario)
        statusMessage = "An account already exists. Enter the code sent to \(state.sentTo) (\(state.codeLength) digits) to sign in."
    }

    @MainActor
    func onExistingAccountPasswordRequired(state: MSALNativeAuthExistingAccountPasswordRequiredState, scenario: MSALNativeAuthFlowScenario)
    {
        print("SignInViewModel[\(label(scenario))]: state required — \(state.description)")
        statusMessage = "An account already exists. Enter its current password to sign in."
        onSubmitExistingAccountPassword = { [weak self] password in
            guard let self = self else { return }
            self.existingAccountPasswordError = nil
            state.submitPassword(password, delegate: self)
        }
        existingAccountPasswordError = nil
        activeSheet = .existingAccountPassword
    }

    @MainActor
    func onNewPasswordRequired(state: MSALNativeAuthNewPasswordRequiredState, scenario: MSALNativeAuthFlowScenario)
    {
        print("SignInViewModel[\(label(scenario))]: state required — \(state.description)")
        onSubmitNewPassword = { [weak self] password in
            guard let self = self else { return }
            state.submitNewPassword(password, delegate: self)
        }
        presentNewPasswordModal()
    }

    @MainActor
    func onAttributesRequired(state: MSALNativeAuthAttributesRequiredState, scenario: MSALNativeAuthFlowScenario)
    {
        print("SignInViewModel[\(label(scenario))]: state required — \(state.description)")
        statusMessage = "Additional information is required."
        requiredAttributes = state.attributes
        onSubmitAttributes = { [weak self] attributes in
            guard let self = self else { return }
            state.submitAttributes(attributes, delegate: self)
        }
        presentCollectAttributesModal()
    }

    @MainActor
    func onAuthMethodSelectionRequired(state: MSALNativeAuthAuthMethodSelectionRequiredState, scenario: MSALNativeAuthFlowScenario)
    {
        print("SignInViewModel[\(label(scenario))]: state required — \(state.description)")
        guard state.authMethods.count > 0 else
        {
            isSigningIn = false
            statusMessage = "No auth methods available."
            return
        }

        statusMessage = "Select an authentication method."
        authMethods = state.authMethods
        onSelectAuthMethod = { [weak self] method in
            guard let self = self else { return }
            state.selectAuthMethod(method, delegate: self)
        }
        presentSelectAuthMethodModal()
        return
    }

    @MainActor
    func onMFAVerificationRequired(state: MSALNativeAuthMFAVerificationRequiredState, scenario: MSALNativeAuthFlowScenario)
    {
        print("SignInViewModel[\(label(scenario))]: state required — \(state.description)")
        statusMessage = "Verification code sent to \(state.sentTo) (\(state.codeLength) digits)."
        onSubmitCode = { [weak self] code in
            guard let self = self else { return }
            state.submitChallenge(code, delegate: self)
        }
        onResendCode = { [weak self] in
            guard let self = self else { return }
            state.resendChallenge(delegate: self)
        }
        presentVerifyCodeModal()
    }

    @MainActor
    func onStrongAuthRegistrationRequired(state: MSALNativeAuthStrongAuthRegistrationRequiredState, scenario: MSALNativeAuthFlowScenario)
    {
        print("SignInViewModel[\(label(scenario))]: state required — \(state.description)")
        guard state.authMethods.count > 0 else
        {
            dismissAnyModal()
            isSigningIn = false
            statusMessage = "No supported authentication methods are available for registration."
            return
        }
        onSubmitCode = nil
        onResendCode = nil
        authMethods = state.authMethods
        statusMessage = "Select an authentication method to register."
        onSelectAuthMethod = { [weak self] method in
            guard let self = self else { return }
            self.collectV2VerificationContact(for: method, state: state)
        }
        presentSelectAuthMethodModal()
    }

    @MainActor
    private func collectV2VerificationContact(
        for method: MSALAuthMethod,
        state: MSALNativeAuthStrongAuthRegistrationRequiredState
    )
    {
        registrationAuthMethod = method
        statusMessage = method.channelTargetType.isSMSType
            ? "Enter the phone number to register, including the country calling code."
            : "Enter the email address to register."
        onSubmitVerificationContact = { [weak self] verificationContact in
            guard let self = self else { return }
            self.dismissAnyModal()
            self.statusMessage = "Registering authentication method…"
            state.selectAuthMethod(method, verificationContact: verificationContact, delegate: self)
        }
        presentVerificationContactModal()
    }

    @MainActor
    func onStrongAuthVerificationRequired(state: MSALNativeAuthStrongAuthVerificationRequiredState, scenario: MSALNativeAuthFlowScenario)
    {
        print("SignInViewModel[\(label(scenario))]: state required — \(state.description)")
        statusMessage = "Verification code sent to \(state.sentTo) (\(state.codeLength) digits)."
        onSubmitCode = { [weak self] code in
            guard let self = self else { return }
            state.submitChallenge(code, delegate: self)
        }
        onResendCode = { [weak self] in
            guard let self = self else { return }
          //  state.resendChallenge(delegate: self)
        }
        presentVerifyCodeModal()
    }

    @MainActor
    func onSignInAfterSignUpRequired(state: MSALNativeAuthSignInAfterSignUpState, scenario: MSALNativeAuthFlowScenario)
    {
        print("SignInViewModel[\(label(scenario))]: state required — \(state.description)")
        dismissAnyModal()
        statusMessage = "Signed up successfully. Signing in…"
        state.signIn(delegate: self)
    }

    @MainActor
    func onSignInAfterResetPasswordRequired(state: MSALNativeAuthSignInAfterResetPasswordState, scenario: MSALNativeAuthFlowScenario)
    {
        print("SignInViewModel[\(label(scenario))]: state required — \(state.description)")
        dismissAnyModal()
        statusMessage = "Password reset. Signing in…"
        state.signIn(delegate: self)
    }

    @MainActor
    func onFlowCompleted(result: MSALNativeAuthUserAccountResult, scenario: MSALNativeAuthFlowScenario)
    {
        print("SignInViewModel[\(label(scenario))]: flow completed")
        accountResult = result
        dismissAnyModal()
        isSigningIn = false
        isSignedIn = true
        statusMessage = "Signed in as \(result.account.username ?? "unknown user")."
        accountResult?.getAccessToken(parameters: MSALNativeAuthGetAccessTokenParameters(), delegate: self)
    }

    @MainActor
    func onFlowError(error: MSALNativeAuthFlowError, scenario: MSALNativeAuthFlowScenario)
    {
        let errorKind: String
        switch true
        {
        case error.isNotImplemented:
            errorKind = "notImplemented — The required delegate is not implemented."
        case error.isUserNotFound:
            errorKind = "userNotFound — The username was not found."
        case error.isInvalidCode:
            errorKind = "invalidCode — The one-time code is invalid or expired."
        case error.isInvalidPassword:
            errorKind = "invalidPassword — The password does not meet the server's requirements."
        case error.isInvalidUsername:
            errorKind = "invalidUsername — The username failed local validation."
        case error.isInvalidChallenge:
            errorKind = "invalidChallenge — The authentication challenge was rejected."
        case error.isInvalidInput:
            errorKind = "invalidInput — The strong-auth registration input was invalid."
        case error.isBrowserRequired:
            errorKind = "browserRequired — The flow must continue in a browser."
        case error.isGeneralError:
            errorKind = "generalError — A general or unexpected error occurred."
        default:
            errorKind = "unknown — No known MSALNativeAuthFlowError classification matched."
        }
        print("SignInViewModel[\(label(scenario))]: flow error — \(errorKind) Description: \(error.errorDescription ?? "N/A") Error Codes: \(error.errorCodes).")
        // The app decides recoverability from the error. On a recoverable error the modal's
        // submit/resend callbacks still capture the state, so re-submitting advances the flow.
        if error.isInvalidCode, isVerifyCodeModalPresented
        {
            updateVerifyCodeModal(errorMessage: "Check the code and try again")
        }
        else if error.isInvalidPassword, isNewPasswordModalPresented
        {
            updateNewPasswordModal(errorMessage: "Invalid password")
        }
        else if error.isInvalidPassword, activeSheet == .existingAccountPassword
        {
            existingAccountPasswordError = "Check your current password and try again."
        }
        else if error.isBrowserRequired
        {
            dismissAnyModal()
            isSigningIn = false
            statusMessage = "This flow must continue in a browser. Please sign in using the browser-based flow."
        }
        else
        {
            dismissAnyModal()
            isSigningIn = false
            statusMessage = "Operation failed: \(error.errorDescription ?? "N/A") Error Code: \(error.errorCodes)."
        }
    }
}
