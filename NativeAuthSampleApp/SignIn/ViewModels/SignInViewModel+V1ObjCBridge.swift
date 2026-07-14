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

// MARK: - Bridge from the Objective-C V1 driver back to the SwiftUI view model

/// Maps events raised by the Objective-C ``SignInViewModelV1ObjC`` driver onto this view model's
/// published UI state and the shared SwiftUI modals. The driver keeps all MSAL SDK usage in
/// Objective-C (proving the V1 API is Obj-C-friendly); this view model only reacts to the callbacks
/// and drives the SwiftUI presentation, reusing the same modals and continuation closures as the
/// native Swift V1 path.
extension SignInViewModel: SignInViewModelV1ObjCDelegate
{
    func startV1ObjCSignIn(application: MSALNativeAuthPublicClientApplication)
    {
        let driver = SignInViewModelV1ObjC(application: application, delegate: self)
        objCDriverV1 = driver
        driver.signIn(withUsername: email, password: password)
    }

    @MainActor
    func signInV1Driver(_ driver: SignInViewModelV1ObjC, didUpdateStatus status: String, isBusy: Bool)
    {
        statusMessage = status
        if !isBusy
        {
            isSigningIn = false
        }
    }

    @MainActor
    func signInV1Driver(
        _ driver: SignInViewModelV1ObjC,
        didRequireCodeSentTo sentTo: String,
        codeLength: Int,
        canResend: Bool
    )
    {
        statusMessage = "Code sent to \(sentTo) (\(codeLength) digits)."
        onSubmitCode = { [weak driver] code in
            driver?.submitCode(code)
        }
        onResendCode = canResend ? { [weak driver] in
            driver?.resendCode()
        } : nil
        presentVerifyCodeModal()
    }

    @MainActor
    func signInV1DriverDidRequireNewPassword(_ driver: SignInViewModelV1ObjC)
    {
        onSubmitNewPassword = { [weak driver] password in
            driver?.submitNewPassword(password)
        }
        presentNewPasswordModal()
    }

    @MainActor
    func signInV1Driver(_ driver: SignInViewModelV1ObjC, didCompleteWithResult result: MSALNativeAuthUserAccountResult)
    {
        accountResult = result
        dismissAnyModal()
        isSigningIn = false
        isSignedIn = true
        statusMessage = "Signed in as \(result.account.username ?? "unknown user")."
    }

    @MainActor
    func signInV1Driver(
        _ driver: SignInViewModelV1ObjC,
        didFailWithMessage message: String,
        isInvalidCode: Bool,
        isInvalidPassword: Bool,
        isBrowserRequired: Bool
    )
    {
        // The driver reports the error's recoverability flags; the app decides how to surface it.
        // On a recoverable error the modal's submit/resend callbacks still capture the state, so
        // re-submitting advances the flow.
        if isInvalidCode, isVerifyCodeModalPresented
        {
            updateVerifyCodeModal(errorMessage: "Check the code and try again")
        }
        else if isInvalidPassword, isNewPasswordModalPresented
        {
            updateNewPasswordModal(errorMessage: "Invalid password")
        }
        else if isBrowserRequired
        {
            dismissAnyModal()
            isSigningIn = false
            statusMessage = "This flow must continue in a browser. Please sign in using the browser-based flow."
        }
        else
        {
            dismissAnyModal()
            isSigningIn = false
            statusMessage = message
        }
    }
}
