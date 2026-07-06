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

// MARK: - MSALNativeAuthFlowDelegate (unified V2 delegate)

extension SignInViewModel: MSALNativeAuthFlowDelegate
{
    @MainActor
    func onCodeRequired(action: MSALNativeAuthCodeRequiredAction)
    {
        print("SignInViewModel: action required — \(action.description)")
        statusMessage = "Code sent to \(action.sentTo) (\(action.codeLength) digits)."
        onSubmitCode = { [weak self] code in
            guard let self = self else { return }
            action.submitCode(code, delegate: self)
        }
        onResendCode = { [weak self] in
            guard let self = self else { return }
            action.resendCode(delegate: self)
        }
        presentVerifyCodeModal()
    }

    @MainActor
    func onPasswordRequired(action: MSALNativeAuthPasswordRequiredAction)
    {
        print("SignInViewModel: action required — \(action.description)")
        statusMessage = "Submitting password…"
        action.submitPassword(password, delegate: self)
    }

    @MainActor
    func onNewPasswordRequired(action: MSALNativeAuthNewPasswordRequiredAction)
    {
        print("SignInViewModel: action required — \(action.description)")
        onSubmitNewPassword = { [weak self] password in
            guard let self = self else { return }
            action.submitNewPassword(password, delegate: self)
        }
        presentNewPasswordModal()
    }

    @MainActor
    func onAttributesRequired(action: MSALNativeAuthAttributesRequiredAction)
    {
        print("SignInViewModel: action required — \(action.description)")
        isSigningIn = false
        statusMessage = "Action required: \(action.description)"
    }

    @MainActor
    func onAttributesInvalid(action: MSALNativeAuthAttributesInvalidAction)
    {
        print("SignInViewModel: action required — \(action.description)")
        isSigningIn = false
        statusMessage = "Action required: \(action.description)"
    }

    @MainActor
    func onMFARequired(action: MSALNativeAuthMFARequiredAction)
    {
        print("SignInViewModel: action required — \(action.description)")
        guard let method = action.authMethods.first else
        {
            isSigningIn = false
            statusMessage = "No auth methods available."
            return
        }
        statusMessage = "Selecting authentication method…"
        action.selectAuthMethod(method, verificationContact: nil, delegate: self)
    }

    @MainActor
    func onMFAVerificationRequired(action: MSALNativeAuthMFAVerificationRequiredAction)
    {
        print("SignInViewModel: action required — \(action.description)")
        statusMessage = "Verification code sent to \(action.sentTo) (\(action.codeLength) digits)."
        onSubmitCode = { [weak self] code in
            guard let self = self else { return }
            action.submitChallenge(code, delegate: self)
        }
        onResendCode = nil
        presentVerifyCodeModal()
    }

    @MainActor
    func onStrongAuthRegistrationRequired(action: MSALNativeAuthStrongAuthRegistrationRequiredAction)
    {
        print("SignInViewModel: action required — \(action.description)")
        guard let method = action.authMethods.first else
        {
            isSigningIn = false
            statusMessage = "No auth methods available."
            return
        }
        statusMessage = "Selecting authentication method…"
        action.selectAuthMethod(method, verificationContact: nil, delegate: self)
    }

    @MainActor
    func onStrongAuthVerificationRequired(action: MSALNativeAuthStrongAuthVerificationRequiredAction)
    {
        print("SignInViewModel: action required — \(action.description)")
        statusMessage = "Verification code sent to \(action.sentTo) (\(action.codeLength) digits)."
        onSubmitCode = { [weak self] code in
            guard let self = self else { return }
            action.submitChallenge(code, delegate: self)
        }
        onResendCode = nil
        presentVerifyCodeModal()
    }

    @MainActor
    func onFlowCompleted(result: MSALNativeAuthUserAccountResult)
    {
        accountResult = result
        dismissAnyModal()
        isSigningIn = false
        isSignedIn = true
        statusMessage = "Signed in as \(result.account.username ?? "unknown user")."
    }

    @MainActor
    func onFlowError(error: MSALNativeAuthFlowError)
    {
        // The app decides recoverability from the error. On a recoverable error the modal's
        // submit/resend callbacks still capture the action, so re-submitting advances the flow.
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
