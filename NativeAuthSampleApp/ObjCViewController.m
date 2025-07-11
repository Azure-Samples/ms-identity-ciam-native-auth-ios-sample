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

#import "ObjCViewController.h"
#import "NativeAuthSampleApp-Swift.h"
@import MSAL;



@interface ObjCViewController () <SignInStartDelegate, CredentialsDelegate>

@property (weak, nonatomic) IBOutlet UITextField *emailTextField;
@property (weak, nonatomic) IBOutlet UITextField *passwordTextField;
@property (weak, nonatomic) IBOutlet UITextView *resultTextView;

@property (weak, nonatomic) IBOutlet UIButton *signInButton;
@property (weak, nonatomic) IBOutlet UIButton *signOutButton;

@property (strong) MSALNativeAuthPublicClientApplication *nativeAuth;
@property (strong) MSALNativeAuthUserAccountResult *accountResult;

@end

@implementation ObjCViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    NSError *error = nil;
    MSALNativeAuthPublicClientApplicationConfig *config = [[MSALNativeAuthPublicClientApplicationConfig alloc]
                                                           initWithClientId:Configuration.clientId
                                                           tenantSubdomain:Configuration.tenantSubdomain
                                                           challengeTypes:MSALNativeAuthChallengeTypeOOB | MSALNativeAuthChallengeTypePassword
                                                           error:&error];

    if (config && !error) {
        self.nativeAuth = [[MSALNativeAuthPublicClientApplication alloc]
                           initWithNativeAuthConfiguration:config
                           error:&error];
    }

    if (error) {
        // Handle error
        NSLog(@"Error initializing MSAL: %@", error.localizedDescription);
    } else {
        NSLog(@"Initialized MSAL successfully");
    }
}

- (IBAction)signInPressed:(id)sender {
    [self.view endEditing:YES];

    NSString *email = self.emailTextField.text;
    NSString *password = self.passwordTextField.text;

    [self showResultText:@"Signing in..."];
    MSALNativeAuthSignInParameters* parameters = [[MSALNativeAuthSignInParameters alloc] initWithUsername:email];
    parameters.password = password;
    [self.nativeAuth signInParameters:parameters
                           delegate:self];
}

- (IBAction)signOutPressed:(id)sender {
    [self.view endEditing:YES];

    if (self.accountResult == nil) {
        NSLog(@"signOutPressed: Not currently signed in.");
        return;
    }
    [self.accountResult signOut];
    
    self.accountResult = nil;

    [self showResultText:@"Signed out."];

    [self updateUI];
}

- (void)showResultText:(NSString *)text {
    self.resultTextView.text = text;
}

- (void)updateUI {
    BOOL signedIn = (self.accountResult != nil);

    self.signInButton.enabled = !signedIn;
    self.signOutButton.enabled = signedIn;
}

#pragma mark - Sign In Delegate methods

- (void)onSignInCodeRequiredWithNewState:(SignInCodeRequiredState *)newState sentTo:(NSString *)sentTo channelTargetType:(MSALNativeAuthChannelType *)channelTargetType codeLength:(NSInteger)codeLength {
    NSLog(@"Unexpected state while signing in: Code Required");
}

- (void)onSignInCompletedWithResult:(MSALNativeAuthUserAccountResult * _Nonnull)result {
    self.accountResult = result;

    MSALNativeAuthGetAccessTokenParameters* parameters = [[MSALNativeAuthGetAccessTokenParameters alloc] init];
    [result getAccessTokenWithParameters:parameters delegate:self];
}

- (void)onSignInStartErrorWithError:(SignInStartError * _Nonnull)error {
    if (error.isInvalidUsername) {
        [self showResultText:@"Invalid username."];
    } else if (error.isInvalidCredentials) {
        [self showResultText:@"Invalid username or password."];
    } else {
        [self showResultText:[NSString stringWithFormat:@"Unexpected error signing in: %@", error.errorDescription]];
    }
}

#pragma mark -  Credentials Delegate methods

- (void)onAccessTokenRetrieveCompletedWithResult:(MSALNativeAuthTokenResult *)result {
    [self showResultText:[NSString stringWithFormat:@"Signed in successfully. Access Token: %@", result.accessToken]];
    [self updateUI];
}

- (void)onAccessTokenRetrieveErrorWithError:(RetrieveAccessTokenError *)error {
    [self showResultText:[NSString stringWithFormat:@"Unexpected error retrieving access token in: %@", error.errorDescription]];
}

@end
