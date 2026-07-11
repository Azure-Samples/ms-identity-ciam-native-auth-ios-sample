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

#import "SignInViewModelV2ObjC.h"

@interface SignInViewModelV2ObjC () <MSALNativeAuthFlowDelegate,
    MSALNativeAuthCodeRequiredDelegate,
    MSALNativeAuthPasswordRequiredDelegate,
    MSALNativeAuthNewPasswordRequiredDelegate,
    MSALNativeAuthAttributesRequiredDelegate,
    MSALNativeAuthAttributesInvalidDelegate,
    MSALNativeAuthMFARequiredDelegate,
    MSALNativeAuthMFAVerificationRequiredDelegate,
    MSALNativeAuthStrongAuthRegistrationRequiredDelegate,
    MSALNativeAuthStrongAuthVerificationRequiredDelegate>

@property (nonatomic, strong) MSALNativeAuthPublicClientApplication *application;
@property (nonatomic, weak) id<SignInViewModelV2ObjCDelegate> output;
@property (nonatomic, copy) NSString *password;

/// Continuations captured from the active state so the shared modals stay flow-agnostic, mirroring
/// the Swift `SignInViewModel` continuation closures.
@property (nonatomic, copy, nullable) void (^onSubmitCode)(NSString *code);
@property (nonatomic, copy, nullable) void (^onResendCode)(void);
@property (nonatomic, copy, nullable) void (^onSubmitNewPassword)(NSString *password);

@end

@implementation SignInViewModelV2ObjC

- (instancetype)initWithApplication:(MSALNativeAuthPublicClientApplication *)application
                           delegate:(id<SignInViewModelV2ObjCDelegate>)delegate
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
    [self resetContinuations];

    MSALNativeAuthSignInParameters *parameters = [[MSALNativeAuthSignInParameters alloc] initWithUsername:username];
    parameters.password = password;

    [self.application signInV2WithParameters:parameters delegate:self];
}

#pragma mark - Continuations

- (void)submitCode:(NSString *)code
{
    if (self.onSubmitCode)
    {
        self.onSubmitCode(code);
    }
}

- (void)resendCode
{
    if (self.onResendCode)
    {
        self.onResendCode();
    }
}

- (void)submitNewPassword:(NSString *)password
{
    if (self.onSubmitNewPassword)
    {
        self.onSubmitNewPassword(password);
    }
}

- (void)resetContinuations
{
    self.onSubmitCode = nil;
    self.onResendCode = nil;
    self.onSubmitNewPassword = nil;
}

#pragma mark - Helpers

- (NSString *)labelForScenario:(MSALNativeAuthFlowScenario)scenario
{
    switch (scenario)
    {
        case MSALNativeAuthFlowScenarioSignIn: return @"signIn";
        case MSALNativeAuthFlowScenarioSignUp: return @"signUp";
        case MSALNativeAuthFlowScenarioPasswordReset: return @"passwordReset";
        default: return @"unknown";
    }
}

#pragma mark - Native Auth V2 per-state delegates

- (void)onCodeRequiredWithState:(MSALNativeAuthCodeRequiredState *)state
                       scenario:(MSALNativeAuthFlowScenario)scenario
{
    NSLog(@"SignInViewModelV2ObjC[%@]: state required — %@", [self labelForScenario:scenario], state.description);

    __weak typeof(self) weakSelf = self;
    self.onSubmitCode = ^(NSString *code) {
        [state submitCode:code delegate:weakSelf];
    };
    self.onResendCode = ^{
        [state resendCodeWithDelegate:weakSelf];
    };

    [self.output signInDriver:self
         didRequireCodeSentTo:state.sentTo
                   codeLength:state.codeLength
                    canResend:YES];
}

- (void)onPasswordRequiredWithState:(MSALNativeAuthPasswordRequiredState *)state
                           scenario:(MSALNativeAuthFlowScenario)scenario
{
    NSLog(@"SignInViewModelV2ObjC[%@]: state required — %@", [self labelForScenario:scenario], state.description);
    [self.output signInDriver:self didUpdateStatus:@"Submitting password…" isBusy:YES];
    [state submitPassword:self.password delegate:self];
}

- (void)onNewPasswordRequiredWithState:(MSALNativeAuthNewPasswordRequiredState *)state
                              scenario:(MSALNativeAuthFlowScenario)scenario
{
    NSLog(@"SignInViewModelV2ObjC[%@]: state required — %@", [self labelForScenario:scenario], state.description);

    __weak typeof(self) weakSelf = self;
    self.onSubmitNewPassword = ^(NSString *password) {
        [state submitNewPassword:password delegate:weakSelf];
    };

    [self.output signInDriverDidRequireNewPassword:self];
}

- (void)onAttributesRequiredWithState:(MSALNativeAuthAttributesRequiredState *)state
                             scenario:(MSALNativeAuthFlowScenario)scenario
{
    NSLog(@"SignInViewModelV2ObjC[%@]: state required — %@", [self labelForScenario:scenario], state.description);
    NSString *status = [NSString stringWithFormat:@"Action required: %@", state.description];
    [self.output signInDriver:self didUpdateStatus:status isBusy:NO];
}

- (void)onAttributesInvalidWithState:(MSALNativeAuthAttributesInvalidState *)state
                            scenario:(MSALNativeAuthFlowScenario)scenario
{
    NSLog(@"SignInViewModelV2ObjC[%@]: state required — %@", [self labelForScenario:scenario], state.description);
    NSString *status = [NSString stringWithFormat:@"Action required: %@", state.description];
    [self.output signInDriver:self didUpdateStatus:status isBusy:NO];
}

- (void)onMFARequiredWithState:(MSALNativeAuthMFARequiredState *)state
                      scenario:(MSALNativeAuthFlowScenario)scenario
{
    NSLog(@"SignInViewModelV2ObjC[%@]: state required — %@", [self labelForScenario:scenario], state.description);
    MSALAuthMethod *method = state.authMethods.firstObject;
    if (!method)
    {
        [self.output signInDriver:self didUpdateStatus:@"No auth methods available." isBusy:NO];
        return;
    }
    [self.output signInDriver:self didUpdateStatus:@"Selecting authentication method…" isBusy:YES];
    [state selectAuthMethod:method verificationContact:nil delegate:self];
}

- (void)onMFAVerificationRequiredWithState:(MSALNativeAuthMFAVerificationRequiredState *)state
                                  scenario:(MSALNativeAuthFlowScenario)scenario
{
    NSLog(@"SignInViewModelV2ObjC[%@]: state required — %@", [self labelForScenario:scenario], state.description);

    __weak typeof(self) weakSelf = self;
    self.onSubmitCode = ^(NSString *code) {
        [state submitChallenge:code delegate:weakSelf];
    };
    self.onResendCode = nil;

    [self.output signInDriver:self
         didRequireCodeSentTo:state.sentTo
                   codeLength:state.codeLength
                    canResend:NO];
}

- (void)onStrongAuthRegistrationRequiredWithState:(MSALNativeAuthStrongAuthRegistrationRequiredState *)state
                                         scenario:(MSALNativeAuthFlowScenario)scenario
{
    NSLog(@"SignInViewModelV2ObjC[%@]: state required — %@", [self labelForScenario:scenario], state.description);
    MSALAuthMethod *method = state.authMethods.firstObject;
    if (!method)
    {
        [self.output signInDriver:self didUpdateStatus:@"No auth methods available." isBusy:NO];
        return;
    }
    [self.output signInDriver:self didUpdateStatus:@"Selecting authentication method…" isBusy:YES];
    [state selectAuthMethod:method verificationContact:nil delegate:self];
}

- (void)onStrongAuthVerificationRequiredWithState:(MSALNativeAuthStrongAuthVerificationRequiredState *)state
                                         scenario:(MSALNativeAuthFlowScenario)scenario
{
    NSLog(@"SignInViewModelV2ObjC[%@]: state required — %@", [self labelForScenario:scenario], state.description);

    __weak typeof(self) weakSelf = self;
    self.onSubmitCode = ^(NSString *code) {
        [state submitChallenge:code delegate:weakSelf];
    };
    self.onResendCode = nil;

    [self.output signInDriver:self
         didRequireCodeSentTo:state.sentTo
                   codeLength:state.codeLength
                    canResend:NO];
}

- (void)onFlowCompletedWithResult:(MSALNativeAuthUserAccountResult *)result
                         scenario:(MSALNativeAuthFlowScenario)scenario
{
    NSLog(@"SignInViewModelV2ObjC[%@]: flow completed", [self labelForScenario:scenario]);
    [self.output signInDriver:self didCompleteWithResult:result];
}

- (void)onFlowErrorWithError:(MSALNativeAuthFlowError *)error
                    scenario:(MSALNativeAuthFlowScenario)scenario
{
    NSLog(@"SignInViewModelV2ObjC[%@]: flow error — %@", [self labelForScenario:scenario], error.errorDescription ?: @"N/A");

    NSString *message = [NSString stringWithFormat:@"Sign in failed: %@ Error Code: %@.",
                         error.errorDescription ?: @"N/A", error.errorCodes];

    [self.output signInDriver:self
           didFailWithMessage:message
                isInvalidCode:error.isInvalidCode
            isInvalidPassword:error.isInvalidPassword
            isBrowserRequired:error.isBrowserRequired];
}

@end
