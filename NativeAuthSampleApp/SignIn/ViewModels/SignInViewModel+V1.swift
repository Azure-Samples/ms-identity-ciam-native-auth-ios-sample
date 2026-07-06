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
