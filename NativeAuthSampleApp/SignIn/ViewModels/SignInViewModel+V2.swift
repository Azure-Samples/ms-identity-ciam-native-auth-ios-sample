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
    MSALNativeAuthNewPasswordRequiredDelegate,
    MSALNativeAuthAttributesRequiredDelegate,
    MSALNativeAuthAttributesInvalidDelegate,
    MSALNativeAuthAuthMethodSelectionRequiredDelegate,
    MSALNativeAuthMFAVerificationRequiredDelegate,
    MSALNativeAuthStrongAuthRegistrationRequiredDelegate,
    MSALNativeAuthStrongAuthVerificationRequiredDelegate,
    MSALNativeAuthSignInAfterResetPasswordRequiredDelegate,
    MSALNativeAuthSignInAfterSignUpRequiredDelegate
{
    @MainActor
    func onCodeRequired(state: MSALNativeAuthCodeRequiredState, scenario: MSALNativeAuthFlowScenario)
    {
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
        statusMessage = "Submitting password…"
        state.submitPassword(password, delegate: self)
    }

    @MainActor
    func onNewPasswordRequired(state: MSALNativeAuthNewPasswordRequiredState, scenario: MSALNativeAuthFlowScenario)
    {
        onSubmitNewPassword = { [weak self] password in
            guard let self = self else { return }
            state.submitNewPassword(password, delegate: self)
        }
        presentNewPasswordModal()
    }

    @MainActor
    func onAttributesRequired(state: MSALNativeAuthAttributesRequiredState, scenario: MSALNativeAuthFlowScenario)
    {
        statusMessage = "Additional information is required."
        requiredAttributes = state.attributes
        onSubmitAttributes = { [weak self] attributes in
            guard let self = self else { return }
            state.submitAttributes(attributes, delegate: self)
        }
        presentCollectAttributesModal()
    }

    @MainActor
    func onAttributesInvalid(state: MSALNativeAuthAttributesInvalidState, scenario: MSALNativeAuthFlowScenario)
    {
        statusMessage = "Invalid attribute value(s): \(state.attributeNames.joined(separator: ", ")). Please correct them and try again."
        onSubmitAttributes = { [weak self] attributes in
            guard let self = self else { return }
            state.submitAttributes(attributes, delegate: self)
        }
        presentCollectAttributesModal()
    }

    @MainActor
    func onAuthMethodSelectionRequired(state: MSALNativeAuthAuthMethodSelectionRequiredState, scenario: MSALNativeAuthFlowScenario)
    {
        guard let method = state.authMethods.first else
        {
            isSigningIn = false
            statusMessage = "No auth methods available."
            return
        }
        if state.authMethods.count > 1
        {
            statusMessage = "Select an authentication method."
            authMethods = state.authMethods
            onSelectAuthMethod = { [weak self] method in
                guard let self = self else { return }
                state.selectAuthMethod(method, delegate: self)
            }
            presentSelectAuthMethodModal()
            return
        }
        statusMessage = "Selecting authentication method…"
        state.selectAuthMethod(method, delegate: self)
    }

    @MainActor
    func onMFAVerificationRequired(state: MSALNativeAuthMFAVerificationRequiredState, scenario: MSALNativeAuthFlowScenario)
    {
        statusMessage = "Verification code sent to \(state.sentTo) (\(state.codeLength) digits)."
        onSubmitCode = { [weak self] code in
            guard let self = self else { return }
            state.submitChallenge(code, delegate: self)
        }
        onResendCode = nil
        presentVerifyCodeModal()
    }

    @MainActor
    func onStrongAuthRegistrationRequired(state: MSALNativeAuthStrongAuthRegistrationRequiredState, scenario: MSALNativeAuthFlowScenario)
    {
        let supportedMethods = state.authMethods.filter
        {
            $0.channelTargetType.isEmailType || $0.channelTargetType.isSMSType
        }
        guard !supportedMethods.isEmpty else
        {
            isSigningIn = false
            statusMessage = "Strong authentication registration is required but no supported methods are available."
            return
        }
        statusMessage = "Select an authentication method to register."
        authMethods = supportedMethods
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
                state.selectAuthMethod(method, verificationContact: verificationContact, delegate: self)
            }
            self.presentVerificationContactModal()
        }
        presentSelectAuthMethodModal()
    }

    @MainActor
    func onStrongAuthVerificationRequired(state: MSALNativeAuthStrongAuthVerificationRequiredState, scenario: MSALNativeAuthFlowScenario)
    {
        statusMessage = "Verification code sent to \(state.sentTo) (\(state.codeLength) digits)."
        onSubmitCode = { [weak self] code in
            guard let self = self else { return }
            state.submitChallenge(code, delegate: self)
        }
        onResendCode = nil
        presentVerifyCodeModal()
    }

    @MainActor
    func onSignInAfterSignUpRequired(state: MSALNativeAuthSignInAfterSignUpState, scenario: MSALNativeAuthFlowScenario)
    {
        dismissAnyModal()
        statusMessage = "Signed up successfully. Signing in…"
        let parameters = MSALNativeAuthSignInAfterSignUpParameters()
        state.signIn(parameters: parameters, delegate: self)
    }

    @MainActor
    func onSignInAfterResetPasswordRequired(state: MSALNativeAuthSignInAfterResetPasswordState, scenario: MSALNativeAuthFlowScenario)
    {
        dismissAnyModal()
        statusMessage = "Password reset. Signing in…"
        let parameters = MSALNativeAuthSignInAfterResetPasswordParameters()
        state.signIn(parameters: parameters, delegate: self)
    }

    @MainActor
    func onFlowCompleted(result: MSALNativeAuthUserAccountResult, scenario: MSALNativeAuthFlowScenario)
    {
        accountResult = result
        dismissAnyModal()
        resetFlowState()
        password = ""
        isSigningIn = false
        isSignedIn = true
        statusMessage = "Signed in."
    }

    @MainActor
    func onFlowError(error: MSALNativeAuthFlowError, scenario: MSALNativeAuthFlowScenario)
    {
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
            statusMessage = "Sign in failed: \(error.errorDescription ?? "N/A") Error Code: \(error.errorCodes)."
        }
    }
}
