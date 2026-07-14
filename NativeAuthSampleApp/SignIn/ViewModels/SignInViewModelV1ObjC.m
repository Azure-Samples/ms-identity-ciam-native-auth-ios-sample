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

#import "SignInViewModelV1ObjC.h"

@interface SignInViewModelV1ObjC () <SignInStartDelegate,
    SignInPasswordRequiredDelegate,
    SignInVerifyCodeDelegate,
    SignInResendCodeDelegate>

@property (nonatomic, strong) MSALNativeAuthPublicClientApplication *application;
@property (nonatomic, weak) id<SignInViewModelV1ObjCDelegate> output;
@property (nonatomic, copy) NSString *password;
@property (nonatomic, strong, nullable) SignInCodeRequiredState *codeRequiredState;
@property (nonatomic, strong, nullable) SignInPasswordRequiredState *passwordRequiredState;

@end

@implementation SignInViewModelV1ObjC

- (instancetype)initWithApplication:(MSALNativeAuthPublicClientApplication *)application
                           delegate:(id<SignInViewModelV1ObjCDelegate>)delegate
{
    self = [super init];
    if (self)
    {
        _application = application;
        _output = delegate;
        _password = @"";
    }
    return self;
}

#pragma mark - Entry point

- (void)signInWithUsername:(NSString *)username password:(NSString *)password
{
    self.password = password ?: @"";
    self.codeRequiredState = nil;
    self.passwordRequiredState = nil;

    MSALNativeAuthSignInParameters *parameters = [[MSALNativeAuthSignInParameters alloc] initWithUsername:username];
    if (self.password.length > 0)
    {
        parameters.password = self.password;
    }

    [self.application signInParameters:parameters delegate:self];
}

#pragma mark - Continuations

- (void)submitCode:(NSString *)code
{
    if (self.codeRequiredState)
    {
        [self.codeRequiredState submitCodeWithCode:code delegate:self];
    }
}

- (void)resendCode
{
    if (self.codeRequiredState)
    {
        [self.codeRequiredState resendCodeWithDelegate:self];
    }
}

- (void)submitNewPassword:(NSString *)password
{
    (void)password;
}

#pragma mark - Helpers

- (NSString *)messageWithPrefix:(NSString *)prefix error:(MSALNativeAuthError *)error
{
    return [NSString stringWithFormat:@"%@: %@ Error Code: %@.",
            prefix,
            error.errorDescription ?: @"N/A",
            error.errorCodes];
}

- (void)failWithPrefix:(NSString *)prefix
                 error:(MSALNativeAuthError *)error
         isInvalidCode:(BOOL)isInvalidCode
     isInvalidPassword:(BOOL)isInvalidPassword
{
    [self.output signInV1Driver:self
             didFailWithMessage:[self messageWithPrefix:prefix error:error]
                  isInvalidCode:isInvalidCode
              isInvalidPassword:isInvalidPassword
              isBrowserRequired:error.isBrowserRequired];
}

- (void)updateCodeRequiredState:(SignInCodeRequiredState *)state
                         sentTo:(NSString *)sentTo
                     codeLength:(NSInteger)codeLength
{
    self.codeRequiredState = state;
    self.passwordRequiredState = nil;

    [self.output signInV1Driver:self
       didRequireCodeSentTo:sentTo
                 codeLength:codeLength
                  canResend:YES];
}

#pragma mark - SignInStartDelegate

- (void)onSignInStartErrorWithError:(SignInStartError *)error
{
    BOOL isInvalidPassword = error.isInvalidCredentials || error.isUserNotFound;
    [self failWithPrefix:@"Sign in failed"
                   error:error
           isInvalidCode:NO
       isInvalidPassword:isInvalidPassword];
}

- (void)onSignInCodeRequiredWithNewState:(SignInCodeRequiredState *)newState
                                  sentTo:(NSString *)sentTo
                       channelTargetType:(MSALNativeAuthChannelType *)channelTargetType
                              codeLength:(NSInteger)codeLength
{
    (void)channelTargetType;
    [self updateCodeRequiredState:newState sentTo:sentTo codeLength:codeLength];
}

- (void)onSignInPasswordRequiredWithNewState:(SignInPasswordRequiredState *)newState
{
    self.passwordRequiredState = newState;
    self.codeRequiredState = nil;
    [self.output signInV1Driver:self didUpdateStatus:@"Submitting password…" isBusy:YES];
    [newState submitPasswordWithPassword:self.password delegate:self];
}

- (void)onSignInCompletedWithResult:(MSALNativeAuthUserAccountResult *)result
{
    self.codeRequiredState = nil;
    self.passwordRequiredState = nil;
    [self.output signInV1Driver:self didCompleteWithResult:result];
}

#pragma mark - SignInPasswordRequiredDelegate

- (void)onSignInPasswordRequiredErrorWithError:(PasswordRequiredError *)error
                                      newState:(SignInPasswordRequiredState *)newState
{
    self.passwordRequiredState = newState;
    [self failWithPrefix:@"Sign in failed"
                   error:error
           isInvalidCode:NO
       isInvalidPassword:error.isInvalidPassword];
}

#pragma mark - SignInVerifyCodeDelegate

- (void)onSignInVerifyCodeErrorWithError:(VerifyCodeError *)error
                                newState:(SignInCodeRequiredState *)newState
{
    self.codeRequiredState = newState;
    [self failWithPrefix:@"Sign in failed"
                   error:error
           isInvalidCode:error.isInvalidCode
       isInvalidPassword:NO];
}

#pragma mark - SignInResendCodeDelegate

- (void)onSignInResendCodeErrorWithError:(ResendCodeError *)error
                                newState:(SignInCodeRequiredState *)newState
{
    self.codeRequiredState = newState;
    [self failWithPrefix:@"Unable to resend the code"
                   error:error
           isInvalidCode:NO
       isInvalidPassword:NO];
}

- (void)onSignInResendCodeCodeRequiredWithNewState:(SignInCodeRequiredState *)newState
                                            sentTo:(NSString *)sentTo
                                 channelTargetType:(MSALNativeAuthChannelType *)channelTargetType
                                        codeLength:(NSInteger)codeLength
{
    (void)channelTargetType;
    [self updateCodeRequiredState:newState sentTo:sentTo codeLength:codeLength];
}

@end
