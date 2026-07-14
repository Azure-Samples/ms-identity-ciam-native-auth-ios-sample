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

// MARK: - Sign-up flow

extension SignInViewModel
{
    func signUp()
    {
        guard !email.isEmpty, !isSigningIn else
        {
            return
        }

        guard let application = application else
        {
            statusMessage = "MSAL is not initialized."
            return
        }

        resetFlowState()
        isSigningIn = true
        statusMessage = "Signing up… (\(useV2Api ? "V2" : "V1"))"

        if useV2Api
        {
            let parameters = MSALNativeAuthSignUpParametersV2(username: email)
            if !password.isEmpty
            {
                parameters.password = password
            }
            application.signUpV2(parameters: parameters, delegate: self)
        }
        else
        {
            let parameters = MSALNativeAuthSignUpParameters(username: email)
            if !password.isEmpty
            {
                parameters.password = password
            }
            application.signUp(parameters: parameters, delegate: self)
        }
    }

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
