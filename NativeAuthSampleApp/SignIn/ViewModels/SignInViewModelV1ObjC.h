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

@class SignInViewModelV1ObjC;

/// UI-affecting events raised by ``SignInViewModelV1ObjC`` so the SwiftUI `SignInViewModel` can
/// update the screen. The driver keeps all MSAL SDK usage in Objective-C; the Swift view model only
/// reacts to these callbacks and drives the shared SwiftUI modals. All callbacks are delivered on
/// the main thread (the Native Auth V1 delegates are invoked on the main actor).
@protocol SignInViewModelV1ObjCDelegate <NSObject>

/// A human-readable status update. `isBusy` is `YES` while the flow is still in progress and `NO`
/// once it has stopped making progress (e.g. an action is required with no in-app continuation).
- (void)signInV1Driver:(SignInViewModelV1ObjC *)driver
       didUpdateStatus:(NSString *)status
                isBusy:(BOOL)isBusy
    NS_SWIFT_NAME(signInV1Driver(_:didUpdateStatus:isBusy:));

/// The server requires a one-time code. `canResend` indicates whether resending is supported for
/// the current state.
- (void)signInV1Driver:(SignInViewModelV1ObjC *)driver
    didRequireCodeSentTo:(NSString *)sentTo
            codeLength:(NSInteger)codeLength
             canResend:(BOOL)canResend
    NS_SWIFT_NAME(signInV1Driver(_:didRequireCodeSentTo:codeLength:canResend:));

/// The server requires the user to choose a new password.
- (void)signInV1DriverDidRequireNewPassword:(SignInViewModelV1ObjC *)driver
    NS_SWIFT_NAME(signInV1DriverDidRequireNewPassword(_:));

/// The flow completed successfully.
- (void)signInV1Driver:(SignInViewModelV1ObjC *)driver
 didCompleteWithResult:(MSALNativeAuthUserAccountResult *)result
    NS_SWIFT_NAME(signInV1Driver(_:didCompleteWithResult:));

/// The flow failed. The recoverability flags mirror the V1 Native Auth errors so the view model
/// can decide whether to surface an inline modal error or end the flow.
- (void)signInV1Driver:(SignInViewModelV1ObjC *)driver
    didFailWithMessage:(NSString *)message
         isInvalidCode:(BOOL)isInvalidCode
     isInvalidPassword:(BOOL)isInvalidPassword
     isBrowserRequired:(BOOL)isBrowserRequired
    NS_SWIFT_NAME(signInV1Driver(_:didFailWithMessage:isInvalidCode:isInvalidPassword:isBrowserRequired:));

@end

/// Drives the MSAL Native Auth **V1** granular sign-in flow entirely from Objective-C.
///
/// This type exists to verify that the Native Auth V1 public API — the `signIn` entry point, the
/// granular delegate protocols, and the concrete state / error types — is fully consumable from
/// Objective-C. The sample's UI remains in SwiftUI; this driver reports UI-affecting events through
/// ``SignInViewModelV1ObjCDelegate``.
@interface SignInViewModelV1ObjC : NSObject

- (instancetype)initWithApplication:(MSALNativeAuthPublicClientApplication *)application
                           delegate:(id<SignInViewModelV1ObjCDelegate>)delegate NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/// Starts a V1 sign-in. `password` is retained so a password-required step can be auto-submitted.
- (void)signInWithUsername:(NSString *)username password:(NSString *)password;

/// Continuations forwarded to the currently active V1 sign-in state.
- (void)submitCode:(NSString *)code;
- (void)resendCode;
- (void)submitNewPassword:(NSString *)password;

@end

NS_ASSUME_NONNULL_END
