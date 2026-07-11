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

#import <Foundation/Foundation.h>
@import MSAL;

NS_ASSUME_NONNULL_BEGIN

@class SignInViewModelV2ObjC;

/// UI-affecting events raised by ``SignInViewModelV2ObjC`` so the SwiftUI `SignInViewModel` can
/// update the screen. The driver keeps all MSAL SDK usage in Objective-C; the Swift view model only
/// reacts to these callbacks and drives the shared UIKit modals. All callbacks are delivered on the
/// main thread (the Native Auth V2 delegates are invoked on the main actor).
@protocol SignInViewModelV2ObjCDelegate <NSObject>

/// A human-readable status update. `isBusy` is `YES` while the flow is still in progress and `NO`
/// once it has stopped making progress (e.g. an action is required with no in-app continuation).
- (void)signInDriver:(SignInViewModelV2ObjC *)driver
     didUpdateStatus:(NSString *)status
              isBusy:(BOOL)isBusy
    NS_SWIFT_NAME(signInDriver(_:didUpdateStatus:isBusy:));

/// The server requires a one-time code. `canResend` indicates whether resending is supported for
/// the current state.
- (void)signInDriver:(SignInViewModelV2ObjC *)driver
    didRequireCodeSentTo:(NSString *)sentTo
              codeLength:(NSInteger)codeLength
               canResend:(BOOL)canResend
    NS_SWIFT_NAME(signInDriver(_:didRequireCodeSentTo:codeLength:canResend:));

/// The server requires the user to choose a new password.
- (void)signInDriverDidRequireNewPassword:(SignInViewModelV2ObjC *)driver
    NS_SWIFT_NAME(signInDriverDidRequireNewPassword(_:));

/// The flow completed successfully.
- (void)signInDriver:(SignInViewModelV2ObjC *)driver
    didCompleteWithResult:(MSALNativeAuthUserAccountResult *)result
    NS_SWIFT_NAME(signInDriver(_:didCompleteWithResult:));

/// The flow failed. The recoverability flags mirror ``MSALNativeAuthFlowError`` so the view model
/// can decide whether to surface an inline modal error or end the flow.
- (void)signInDriver:(SignInViewModelV2ObjC *)driver
    didFailWithMessage:(NSString *)message
         isInvalidCode:(BOOL)isInvalidCode
     isInvalidPassword:(BOOL)isInvalidPassword
     isBrowserRequired:(BOOL)isBrowserRequired
    NS_SWIFT_NAME(signInDriver(_:didFailWithMessage:isInvalidCode:isInvalidPassword:isBrowserRequired:));

@end

/// Drives the MSAL Native Auth **V2** server-driven sign-in flow entirely from Objective-C.
///
/// This type exists to verify that the Native Auth V2 public API — the `signInV2` entry point, the
/// unified ``MSALNativeAuthFlowDelegate``, every per-state delegate protocol, and the concrete
/// state / error / scenario types — is fully consumable from Objective-C. The sample's UI remains in
/// SwiftUI; this driver reports UI-affecting events through ``SignInViewModelV2ObjCDelegate``.
@interface SignInViewModelV2ObjC : NSObject

- (instancetype)initWithApplication:(MSALNativeAuthPublicClientApplication *)application
                           delegate:(id<SignInViewModelV2ObjCDelegate>)delegate NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/// Starts a V2 sign-in. `password` is retained so a password-required step can be auto-submitted.
- (void)signInWithUsername:(NSString *)username password:(NSString *)password;

/// Continuations forwarded to the currently active ``MSALNativeAuthState``.
- (void)submitCode:(NSString *)code;
- (void)resendCode;
- (void)submitNewPassword:(NSString *)password;

@end

NS_ASSUME_NONNULL_END
