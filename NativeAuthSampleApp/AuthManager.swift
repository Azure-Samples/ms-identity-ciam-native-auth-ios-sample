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

    /// The most recent concrete state handed back by the SDK, used to continue a multi-step flow.
    private(set) var currentState: MSALNativeAuthState?

    /// Invoked when the server hands back a state that requires the app to continue the flow.
    /// The concrete state type (and its properties) describe what input is needed next.
    var onStateRequired: ((MSALNativeAuthState) -> Void)?

    /// Invoked when the flow completes successfully and tokens are available.
    var onCompleted: ((MSALNativeAuthUserAccountResult) -> Void)?

    /// Invoked when the flow fails.
    ///
    /// Note: with the server-driven (V2) delegate model, "browser required" outcomes are also
    /// reported here (the flow must fall back to the web). Inspect the error to decide how to react.
    var onError: ((MSALNativeAuthFlowError) -> Void)?

    /// Retained for source compatibility. The V2 delegate model no longer surfaces a dedicated
    /// browser-required callback with a URL — such outcomes now arrive through `onError`. This
    /// closure is therefore never invoked; prefer handling the web fallback inside `onError`.
    var onBrowserRequired: ((URL) -> Void)?

    init(application: MSALNativeAuthPublicClientApplication) {
        self.application = application
        super.init()
    }

    // MARK: - Start flows (V2)

    /// Start the server-driven reset password (SSPR) flow.
    func resetPassword(email: String) {
        reset()
        let parameters = MSALNativeAuthResetPasswordParameters(username: email)
        application.resetPasswordV2(parameters: parameters, delegate: self)
    }

    /// Start the server-driven sign up flow.
    func signUp(email: String, password: String? = nil) {
        reset()
        let parameters = MSALNativeAuthSignUpParametersV2(username: email)
        parameters.password = password
        application.signUpV2(parameters: parameters, delegate: self)
    }

    /// Start the server-driven sign in flow.
    func signIn(email: String, password: String? = nil) {
        reset()
        let parameters = MSALNativeAuthSignInParameters(username: email)
        parameters.password = password
        application.signInV2(parameters: parameters, delegate: self)
    }

    // MARK: - Continue the current flow (V2)

    func submitCode(_ code: String) {
        (currentState as? MSALNativeAuthCodeRequiredState)?.submitCode(code, delegate: self)
    }

    func submitPassword(_ password: String) {
        (currentState as? MSALNativeAuthPasswordRequiredState)?.submitPassword(password, delegate: self)
    }

    func submitNewPassword(_ password: String) {
        (currentState as? MSALNativeAuthNewPasswordRequiredState)?.submitNewPassword(password, delegate: self)
    }

    func submitAttributes(_ attributes: [String: Any]) {
        if let state = currentState as? MSALNativeAuthAttributesRequiredState {
            state.submitAttributes(attributes, delegate: self)
        } else if let state = currentState as? MSALNativeAuthAttributesInvalidState {
            state.submitAttributes(attributes, delegate: self)
        }
    }

    func selectAuthMethod(_ method: MSALAuthMethod, verificationContact: String? = nil) {
        if let state = currentState as? MSALNativeAuthMFARequiredState {
            state.selectAuthMethod(method, verificationContact: verificationContact, delegate: self)
        } else if let state = currentState as? MSALNativeAuthStrongAuthRegistrationRequiredState {
            state.selectAuthMethod(method, verificationContact: verificationContact, delegate: self)
        }
    }

    func submitChallenge(_ challenge: String) {
        if let state = currentState as? MSALNativeAuthMFAVerificationRequiredState {
            state.submitChallenge(challenge, delegate: self)
        } else if let state = currentState as? MSALNativeAuthStrongAuthVerificationRequiredState {
            state.submitChallenge(challenge, delegate: self)
        }
    }

    func resendCode() {
        (currentState as? MSALNativeAuthCodeRequiredState)?.resendCode(delegate: self)
    }

    // MARK: - Private

    private func reset() {
        currentState = nil
    }

    /// Stores the latest state and forwards it to the facade closure.
    @MainActor
    private func handle(_ state: MSALNativeAuthState) {
        currentState = state
        print("AuthManager: state required — \(AuthManager.describe(state))")
        onStateRequired?(state)
    }
}

// MARK: - MSALNativeAuthFlowDelegate (terminal callbacks) + per-state delegates

extension AuthManager: MSALNativeAuthCodeRequiredDelegate,
                       MSALNativeAuthPasswordRequiredDelegate,
                       MSALNativeAuthNewPasswordRequiredDelegate,
                       MSALNativeAuthSignInAfterResetPasswordRequiredDelegate,
                       MSALNativeAuthAttributesRequiredDelegate,
                       MSALNativeAuthAttributesInvalidDelegate,
                       MSALNativeAuthMFARequiredDelegate,
                       MSALNativeAuthMFAVerificationRequiredDelegate,
                       MSALNativeAuthStrongAuthRegistrationRequiredDelegate,
                       MSALNativeAuthStrongAuthVerificationRequiredDelegate {

    // MARK: Terminal callbacks

    @MainActor
    func onFlowCompleted(result: MSALNativeAuthUserAccountResult, scenario: MSALNativeAuthFlowScenario) {
        reset()
        print("AuthManager: flow completed for \(result.account.username ?? "unknown user")")
        onCompleted?(result)
    }

    @MainActor
    func onFlowError(error: MSALNativeAuthFlowError, scenario: MSALNativeAuthFlowScenario) {
        print("AuthManager: flow error — \(error.errorDescription ?? "no description")")
        onError?(error)
    }

    // MARK: Per-state callbacks

    @MainActor
    func onCodeRequired(state: MSALNativeAuthCodeRequiredState, scenario: MSALNativeAuthFlowScenario) {
        handle(state)
    }

    @MainActor
    func onPasswordRequired(state: MSALNativeAuthPasswordRequiredState, scenario: MSALNativeAuthFlowScenario) {
        handle(state)
    }

    @MainActor
    func onNewPasswordRequired(state: MSALNativeAuthNewPasswordRequiredState, scenario: MSALNativeAuthFlowScenario) {
        handle(state)
    }

    @MainActor
    func onSignInAfterResetPasswordRequired(
        state: MSALNativeAuthSignInAfterResetPasswordState,
        scenario: MSALNativeAuthFlowScenario
    ) {
        let parameters = MSALNativeAuthSignInAfterResetPasswordParameters()
        parameters.scopes = []
        state.signIn(parameters: parameters, delegate: self)
    }

    @MainActor
    func onAttributesRequired(state: MSALNativeAuthAttributesRequiredState, scenario: MSALNativeAuthFlowScenario) {
        handle(state)
    }

    @MainActor
    func onAttributesInvalid(state: MSALNativeAuthAttributesInvalidState, scenario: MSALNativeAuthFlowScenario) {
        handle(state)
    }

    @MainActor
    func onMFARequired(state: MSALNativeAuthMFARequiredState, scenario: MSALNativeAuthFlowScenario) {
        handle(state)
    }

    @MainActor
    func onMFAVerificationRequired(state: MSALNativeAuthMFAVerificationRequiredState, scenario: MSALNativeAuthFlowScenario) {
        handle(state)
    }

    @MainActor
    func onStrongAuthRegistrationRequired(state: MSALNativeAuthStrongAuthRegistrationRequiredState,
                                          scenario: MSALNativeAuthFlowScenario) {
        handle(state)
    }

    @MainActor
    func onStrongAuthVerificationRequired(state: MSALNativeAuthStrongAuthVerificationRequiredState,
                                          scenario: MSALNativeAuthFlowScenario) {
        handle(state)
    }
}

// MARK: - Helpers

extension AuthManager {

    /// Human-readable description of a state, used for logging.
    static func describe(_ state: MSALNativeAuthState) -> String {
        switch state {
        case let state as MSALNativeAuthCodeRequiredState:
            return "codeRequired (sentTo: \(state.sentTo), length: \(state.codeLength))"
        case is MSALNativeAuthPasswordRequiredState:
            return "passwordRequired"
        case is MSALNativeAuthNewPasswordRequiredState:
            return "newPasswordRequired"
        case let state as MSALNativeAuthAttributesRequiredState:
            return "attributesRequired (\(state.attributes.map { $0.name }.joined(separator: ", ")))"
        case let state as MSALNativeAuthAttributesInvalidState:
            return "attributesInvalid (\(state.attributeNames.joined(separator: ", ")))"
        case is MSALNativeAuthMFARequiredState:
            return "mfaRequired"
        case let state as MSALNativeAuthMFAVerificationRequiredState:
            return "mfaVerificationRequired (sentTo: \(state.sentTo), length: \(state.codeLength))"
        case is MSALNativeAuthStrongAuthRegistrationRequiredState:
            return "strongAuthRegistrationRequired"
        case let state as MSALNativeAuthStrongAuthVerificationRequiredState:
            return "strongAuthVerificationRequired (sentTo: \(state.sentTo), length: \(state.codeLength))"
        default:
            return "\(type(of: state))"
        }
    }
}
