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

/// Central facade for the Native Auth **V2** (server-driven, unified-delegate) SDK surface.
///
/// `AuthManager` is the object that conforms to ``MSALNativeAuthFlowDelegate`` so the view
/// controllers do not have to. They build their `MSALNativeAuthPublicClientApplication` as
/// usual, wrap it in an `AuthManager`, point the V2 entry points at this manager and observe
/// the result through the callback closures below.
///
/// The manager keeps the latest ``MSALNativeAuthFlowState`` handed back by the SDK so a flow
/// can be continued (submit code, submit new password, resend code, …) without the caller
/// having to track it.
///
/// Note: the callbacks below only report state; they intentionally do not drive any UI
/// (no modals / navigation) — wiring that up is a separate, later step.
final class AuthManager: NSObject {

    /// The underlying Native Auth application used to start the V2 flows.
    let application: MSALNativeAuthPublicClientApplication

    /// The most recent flow state, used to continue a multi-step flow.
    private var flowState: MSALNativeAuthFlowState?

    /// The most recent action the server required, so callers can route a generic input (e.g. a
    /// verification code) to the correct continuation method.
    private(set) var latestAction: MSALNativeAuthAction?

    /// Invoked when the server requires the app to perform an action to continue the flow.
    var onActionRequired: ((MSALNativeAuthAction) -> Void)?

    /// Invoked when the flow completes successfully and tokens are available.
    var onCompleted: ((MSALNativeAuthUserAccountResult) -> Void)?

    /// Invoked when the flow fails.
    var onError: ((MSALNativeAuthFlowError) -> Void)?

    /// Invoked when the flow must continue in a web browser.
    var onBrowserRequired: ((URL) -> Void)?

    init(application: MSALNativeAuthPublicClientApplication) {
        self.application = application
        super.init()
    }

    // MARK: - Start flows (V2)

    /// Start the server-driven reset password (SSPR) flow.
    func resetPassword(email: String) {
        flowState = nil
        latestAction = nil
        let parameters = MSALNativeAuthResetPasswordParameters(username: email)
        application.resetPasswordV2(parameters: parameters, delegate: self)
    }

    /// Start the server-driven sign up flow.
    func signUp(email: String, password: String? = nil) {
        flowState = nil
        latestAction = nil
        let parameters = MSALNativeAuthSignUpParameters(username: email)
        parameters.password = password
        application.signUpV2(parameters: parameters, delegate: self)
    }

    /// Start the server-driven sign in flow.
    func signIn(email: String, password: String? = nil) {
        flowState = nil
        latestAction = nil
        let parameters = MSALNativeAuthSignInParameters(username: email)
        parameters.password = password
        application.signInV2(parameters: parameters, delegate: self)
    }

    // MARK: - Continue the current flow (V2)

    func submitCode(_ code: String) {
        flowState?.submitCode(code, delegate: self)
    }

    func submitPassword(_ password: String) {
        flowState?.submitPassword(password, delegate: self)
    }

    func submitNewPassword(_ password: String) {
        flowState?.submitNewPassword(password, delegate: self)
    }

    func submitAttributes(_ attributes: [String: Any]) {
        flowState?.submitAttributes(attributes, delegate: self)
    }

    func selectAuthMethod(_ method: MSALAuthMethod, verificationContact: String? = nil) {
        flowState?.selectAuthMethod(method, verificationContact: verificationContact, delegate: self)
    }

    func submitChallenge(_ challenge: String) {
        flowState?.submitChallenge(challenge, delegate: self)
    }

    func resendCode() {
        flowState?.resendCode(delegate: self)
    }
}

// MARK: - MSALNativeAuthFlowDelegate (unified V2 delegate)

extension AuthManager: MSALNativeAuthFlowDelegate {

    @MainActor
    func onActionRequired(action: MSALNativeAuthAction, flowState: MSALNativeAuthFlowState) {
        self.flowState = flowState
        self.latestAction = action
        print("AuthManager: action required — \(AuthManager.describe(action))")
        onActionRequired?(action)
    }

    @MainActor
    func onFlowCompleted(result: MSALNativeAuthUserAccountResult) {
        flowState = nil
        latestAction = nil
        print("AuthManager: flow completed for \(result.account.username ?? "unknown user")")
        onCompleted?(result)
    }

    @MainActor
    func onFlowError(error: MSALNativeAuthFlowError, flowState: MSALNativeAuthFlowState?) {
        self.flowState = flowState
        print("AuthManager: flow error — \(error.errorDescription ?? "no description") (kind: \(error.kind))")
        onError?(error)
    }

    @MainActor
    func onBrowserRequired(url: URL, flowState: MSALNativeAuthFlowState) {
        self.flowState = flowState
        print("AuthManager: browser required — \(url.absoluteString)")
        onBrowserRequired?(url)
    }
}

// MARK: - Helpers

extension AuthManager {

    /// Human-readable description of an action, used for logging.
    static func describe(_ action: MSALNativeAuthAction) -> String {
        switch action {
        case .codeRequired(let sentTo, _, let codeLength):
            return "codeRequired (sentTo: \(sentTo), length: \(codeLength))"
        case .passwordRequired:
            return "passwordRequired"
        case .newPasswordRequired:
            return "newPasswordRequired"
        case .attributesRequired(let attributes):
            return "attributesRequired (\(attributes.map { $0.name }.joined(separator: ", ")))"
        case .attributesInvalid(let attributeNames):
            return "attributesInvalid (\(attributeNames.joined(separator: ", ")))"
        case .mfaRequired:
            return "mfaRequired"
        case .mfaVerificationRequired(let sentTo, _, let codeLength):
            return "mfaVerificationRequired (sentTo: \(sentTo), length: \(codeLength))"
        case .strongAuthRegistrationRequired:
            return "strongAuthRegistrationRequired"
        case .strongAuthVerificationRequired(let sentTo, _, let codeLength):
            return "strongAuthVerificationRequired (sentTo: \(sentTo), length: \(codeLength))"
        }
    }
}
