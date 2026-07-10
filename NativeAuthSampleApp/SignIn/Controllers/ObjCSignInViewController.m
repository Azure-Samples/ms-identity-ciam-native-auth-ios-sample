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

#import "ObjCSignInViewController.h"
#import "NativeAuthSampleApp-Swift.h"
@import MSAL;

@interface ObjCSignInViewController () <
    MSALNativeAuthFlowDelegate,
    MSALNativeAuthCodeRequiredDelegate,
    MSALNativeAuthPasswordRequiredDelegate,
    MSALNativeAuthNewPasswordRequiredDelegate,
    MSALNativeAuthAttributesRequiredDelegate,
    MSALNativeAuthAttributesInvalidDelegate,
    MSALNativeAuthMFARequiredDelegate,
    MSALNativeAuthMFAVerificationRequiredDelegate,
    MSALNativeAuthStrongAuthRegistrationRequiredDelegate,
    MSALNativeAuthStrongAuthVerificationRequiredDelegate,
    CredentialsDelegate,
    SignInStartDelegate,
    SignInVerifyCodeDelegate,
    SignInResendCodeDelegate,
    ResetPasswordStartDelegate,
    ResetPasswordVerifyCodeDelegate,
    ResetPasswordResendCodeDelegate,
    ResetPasswordRequiredDelegate,
    SignInAfterResetPasswordDelegate>

// UI
@property (nonatomic, strong) UIStackView *signInStack;
@property (nonatomic, strong) UIStackView *signedInStack;
@property (nonatomic, strong) UIStackView *restoringStack;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;
@property (nonatomic, strong) UISegmentedControl *apiVersionControl;
@property (nonatomic, strong) UITextField *emailField;
@property (nonatomic, strong) UITextField *passwordField;
@property (nonatomic, strong) UIButton *signInButton;
@property (nonatomic, strong) UIButton *resetPasswordButton;
@property (nonatomic, strong) UIButton *signOutButton;
@property (nonatomic, strong) UILabel *statusLabel;

// State
@property (nonatomic, strong, nullable) MSALNativeAuthPublicClientApplication *nativeAuth;
@property (nonatomic, strong, nullable) MSALNativeAuthUserAccountResult *accountResult;
@property (nonatomic, copy, nullable) NSString *statusMessage;
@property (nonatomic, assign) BOOL useV2Api;
@property (nonatomic, assign) BOOL isSignedIn;
@property (nonatomic, assign) BOOL isRestoringSession;
@property (nonatomic, assign) BOOL isSigningIn;
@property (nonatomic, assign) BOOL didAttemptSessionRestore;

// Shared, flow-agnostic modal continuation callbacks (wired by the active V1/V2 flow).
@property (nonatomic, copy, nullable) void (^onSubmitCode)(NSString *code);
@property (nonatomic, copy, nullable) void (^onResendCode)(void);
@property (nonatomic, copy, nullable) void (^onSubmitNewPassword)(NSString *password);

@property (nonatomic, strong, nullable) VerifyCodeViewController *verifyCodeViewController;
@property (nonatomic, strong, nullable) NewPasswordViewController *pendingNewPasswordViewController;

@end

@implementation ObjCSignInViewController

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.useV2Api = YES;
    self.isRestoringSession = YES;
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    [self initializeMSAL];
    [self buildUI];
    [self updateUI];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self loadCachedSession];
}

- (void)initializeMSAL
{
    NSError *error = nil;
    MSALNativeAuthPublicClientApplicationConfig *config =
        [[MSALNativeAuthPublicClientApplicationConfig alloc]
            initWithClientId:Configuration.clientId
             tenantSubdomain:Configuration.tenantSubdomain
              challengeTypes:MSALNativeAuthChallengeTypeOOB | MSALNativeAuthChallengeTypePassword
                       error:&error];

    if (config && !error)
    {
        config.sliceConfig = Configuration.sliceConfig;
        self.nativeAuth = [[MSALNativeAuthPublicClientApplication alloc]
                           initWithNativeAuthConfiguration:config
                                                     error:&error];
    }

    if (!self.nativeAuth || error)
    {
        NSLog(@"Unable to initialize MSAL %@", error.localizedDescription);
        self.statusMessage = @"Unable to initialize MSAL.";
    }
}

#pragma mark - UI construction

- (void)buildUI
{
    UIStackView *rootStack = [[UIStackView alloc] init];
    rootStack.axis = UILayoutConstraintAxisVertical;
    rootStack.spacing = 16;
    rootStack.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:rootStack];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [rootStack.topAnchor constraintEqualToAnchor:safe.topAnchor constant:16],
        [rootStack.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor constant:16],
        [rootStack.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor constant:-16]
    ]];

    [rootStack addArrangedSubview:[self buildSignInStack]];
    [rootStack addArrangedSubview:[self buildSignedInStack]];
    [rootStack addArrangedSubview:[self buildRestoringStack]];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    self.statusLabel.textColor = [UIColor secondaryLabelColor];
    self.statusLabel.numberOfLines = 0;
    [rootStack addArrangedSubview:self.statusLabel];
}

- (UIStackView *)buildSignInStack
{
    UILabel *title = [[UILabel alloc] init];
    title.text = @"Sign In";
    title.font = [UIFont preferredFontForTextStyle:UIFontTextStyleLargeTitle];
    title.adjustsFontForContentSizeCategory = YES;

    self.apiVersionControl = [[UISegmentedControl alloc] initWithItems:@[@"V1", @"V2"]];
    self.apiVersionControl.selectedSegmentIndex = self.useV2Api ? 1 : 0;
    [self.apiVersionControl addTarget:self
                               action:@selector(apiVersionChanged:)
                     forControlEvents:UIControlEventValueChanged];

    self.emailField = [self makeTextFieldWithPlaceholder:@"Email" secure:NO];
    self.emailField.keyboardType = UIKeyboardTypeEmailAddress;
    self.emailField.textContentType = UITextContentTypeUsername;

    self.passwordField = [self makeTextFieldWithPlaceholder:@"Password" secure:YES];
    self.passwordField.textContentType = UITextContentTypePassword;

    self.signInButton = [self makeButtonWithTitle:@"Sign In" prominent:YES];
    [self.signInButton addTarget:self
                          action:@selector(signInTapped)
                forControlEvents:UIControlEventTouchUpInside];

    self.resetPasswordButton = [self makeButtonWithTitle:@"Reset Password" prominent:NO];
    [self.resetPasswordButton addTarget:self
                                 action:@selector(resetPasswordTapped)
                       forControlEvents:UIControlEventTouchUpInside];

    self.signInStack = [[UIStackView alloc] initWithArrangedSubviews:@[
        title, self.apiVersionControl, self.emailField, self.passwordField,
        self.signInButton, self.resetPasswordButton
    ]];
    self.signInStack.axis = UILayoutConstraintAxisVertical;
    self.signInStack.spacing = 16;
    return self.signInStack;
}

- (UIStackView *)buildSignedInStack
{
    UILabel *title = [[UILabel alloc] init];
    title.text = @"Signed In";
    title.font = [UIFont preferredFontForTextStyle:UIFontTextStyleLargeTitle];
    title.adjustsFontForContentSizeCategory = YES;

    self.signOutButton = [self makeButtonWithTitle:@"Sign Out" prominent:YES];
    [self.signOutButton addTarget:self
                           action:@selector(signOutTapped)
                 forControlEvents:UIControlEventTouchUpInside];

    self.signedInStack = [[UIStackView alloc] initWithArrangedSubviews:@[title, self.signOutButton]];
    self.signedInStack.axis = UILayoutConstraintAxisVertical;
    self.signedInStack.spacing = 16;
    return self.signedInStack;
}

- (UIStackView *)buildRestoringStack
{
    self.activityIndicator = [[UIActivityIndicatorView alloc]
                              initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];

    UILabel *label = [[UILabel alloc] init];
    label.text = @"Restoring your session…";
    label.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    label.textColor = [UIColor secondaryLabelColor];
    label.textAlignment = NSTextAlignmentCenter;

    self.restoringStack = [[UIStackView alloc] initWithArrangedSubviews:@[self.activityIndicator, label]];
    self.restoringStack.axis = UILayoutConstraintAxisVertical;
    self.restoringStack.spacing = 16;
    self.restoringStack.alignment = UIStackViewAlignmentCenter;
    return self.restoringStack;
}

- (UITextField *)makeTextFieldWithPlaceholder:(NSString *)placeholder secure:(BOOL)secure
{
    UITextField *field = [[UITextField alloc] init];
    field.placeholder = placeholder;
    field.borderStyle = UITextBorderStyleRoundedRect;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    field.secureTextEntry = secure;
    [field addTarget:self
              action:@selector(textFieldChanged)
    forControlEvents:UIControlEventEditingChanged];
    return field;
}

- (UIButton *)makeButtonWithTitle:(NSString *)title prominent:(BOOL)prominent
{
    UIButtonConfiguration *configuration = prominent
        ? [UIButtonConfiguration filledButtonConfiguration]
        : [UIButtonConfiguration borderedButtonConfiguration];
    configuration.title = title;

    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.configuration = configuration;
    return button;
}

#pragma mark - UI state

- (void)setStatusMessage:(NSString *)statusMessage
{
    _statusMessage = [statusMessage copy];
    [self updateUI];
}

- (void)updateUI
{
    self.signInStack.hidden = self.isSignedIn || self.isRestoringSession;
    self.signedInStack.hidden = !self.isSignedIn;
    self.restoringStack.hidden = self.isSignedIn || !self.isRestoringSession;

    if (self.restoringStack.hidden)
    {
        [self.activityIndicator stopAnimating];
    }
    else
    {
        [self.activityIndicator startAnimating];
    }

    self.apiVersionControl.enabled = !self.isSigningIn;
    self.signInButton.enabled = ![self isSignInDisabled];
    self.resetPasswordButton.enabled = ![self isResetPasswordDisabled];

    self.statusLabel.text = self.statusMessage;
    self.statusLabel.hidden = (self.statusMessage.length == 0);
}

- (NSString *)email
{
    return self.emailField.text ?: @"";
}

- (NSString *)password
{
    return self.passwordField.text ?: @"";
}

- (BOOL)isSignInDisabled
{
    return self.email.length == 0 || self.password.length == 0 || self.isSigningIn;
}

- (BOOL)isResetPasswordDisabled
{
    return self.email.length == 0 || self.isSigningIn;
}

#pragma mark - Actions

- (void)apiVersionChanged:(UISegmentedControl *)sender
{
    self.useV2Api = (sender.selectedSegmentIndex == 1);
}

- (void)textFieldChanged
{
    [self updateUI];
}

- (void)signInTapped
{
    [self.view endEditing:YES];
    [self signIn];
}

- (void)resetPasswordTapped
{
    [self.view endEditing:YES];
    [self resetPassword];
}

- (void)signOutTapped
{
    [self.view endEditing:YES];
    [self signOut];
}

#pragma mark - Start flows

- (void)loadCachedSession
{
    if (self.didAttemptSessionRestore)
    {
        return;
    }
    self.didAttemptSessionRestore = YES;

    if (!self.nativeAuth)
    {
        self.isRestoringSession = NO;
        [self updateUI];
        return;
    }

    MSALNativeAuthUserAccountResult *account = [self.nativeAuth getNativeAuthUserAccountWithCorrelationId:nil];
    if (!account)
    {
        // No cached account — the user is signed out; show the sign-in UI.
        self.isRestoringSession = NO;
        [self updateUI];
        return;
    }

    self.accountResult = account;
    self.statusMessage = @"Restoring your session…";
    [account getAccessTokenWithParameters:[[MSALNativeAuthGetAccessTokenParameters alloc] init]
                                 delegate:self];
}

- (void)signIn
{
    if (self.email.length == 0 || self.password.length == 0 || self.isSigningIn)
    {
        return;
    }
    if (!self.nativeAuth)
    {
        self.statusMessage = @"MSAL is not initialized.";
        return;
    }

    [self resetFlowState];
    self.isSigningIn = YES;
    self.statusMessage = [NSString stringWithFormat:@"Signing in… (%@)", self.useV2Api ? @"V2" : @"V1"];

    MSALNativeAuthSignInParameters *parameters = [[MSALNativeAuthSignInParameters alloc] initWithUsername:self.email];
    parameters.password = self.password;

    if (self.useV2Api)
    {
        [self.nativeAuth signInV2WithParameters:parameters delegate:self];
    }
    else
    {
        [self.nativeAuth signInParameters:parameters delegate:self];
    }
}

- (void)resetPassword
{
    if (self.email.length == 0 || self.isSigningIn)
    {
        return;
    }
    if (!self.nativeAuth)
    {
        self.statusMessage = @"MSAL is not initialized.";
        return;
    }

    [self resetFlowState];
    self.isSigningIn = YES;
    self.statusMessage = [NSString stringWithFormat:@"Resetting password… (%@)", self.useV2Api ? @"V2" : @"V1"];

    MSALNativeAuthResetPasswordParameters *parameters = [[MSALNativeAuthResetPasswordParameters alloc] initWithUsername:self.email];

    if (self.useV2Api)
    {
        [self.nativeAuth resetPasswordV2WithParameters:parameters delegate:self];
    }
    else
    {
        [self.nativeAuth resetPasswordWithParameters:parameters delegate:self];
    }
}

- (void)resetFlowState
{
    self.onSubmitCode = nil;
    self.onResendCode = nil;
    self.onSubmitNewPassword = nil;
}

- (void)signOut
{
    [self.accountResult signOut];
    self.accountResult = nil;
    [self resetFlowState];
    self.passwordField.text = @"";
    self.isSignedIn = NO;
    self.isSigningIn = NO;
    self.isRestoringSession = NO;
    self.statusMessage = @"Signed out.";
}

- (void)cancelFlow
{
    self.verifyCodeViewController = nil;
    self.pendingNewPasswordViewController = nil;
    self.isSigningIn = NO;
    self.statusMessage = @"Action cancelled.";
}

#pragma mark - Verify Code modal

- (BOOL)isVerifyCodeModalPresented
{
    return self.verifyCodeViewController != nil;
}

- (BOOL)isNewPasswordModalPresented
{
    return self.pendingNewPasswordViewController != nil;
}

- (void)presentVerifyCodeModal
{
    if (self.verifyCodeViewController != nil)
    {
        [self updateVerifyCodeModalWithErrorMessage:nil];
    }
    else
    {
        [self showVerifyCodeModal];
    }
}

- (void)showVerifyCodeModal
{
    self.verifyCodeViewController =
        (VerifyCodeViewController *)[self.storyboard instantiateViewControllerWithIdentifier:@"VerifyCodeViewController"];

    if (!self.verifyCodeViewController)
    {
        NSLog(@"Error creating Verify Code view controller");
        return;
    }

    [self updateVerifyCodeModalWithErrorMessage:nil];
    [self presentViewController:self.verifyCodeViewController animated:YES completion:nil];
}

- (void)updateVerifyCodeModalWithErrorMessage:(nullable NSString *)errorMessage
{
    VerifyCodeViewController *modal = self.verifyCodeViewController;
    if (!modal)
    {
        return;
    }

    if (errorMessage)
    {
        modal.errorLabel.text = errorMessage;
    }

    __weak typeof(self) weakSelf = self;
    modal.onSubmit = ^(NSString *code) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf.onSubmitCode)
            {
                strongSelf.onSubmitCode(code);
            }
        });
    };
    modal.onResend = ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf.onResendCode)
            {
                strongSelf.onResendCode();
            }
        });
    };
    modal.onCancel = ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf cancelFlow];
        });
    };
}

- (void)dismissVerifyCodeModalWithCompletion:(nullable void (^)(void))completion
{
    if (self.verifyCodeViewController == nil)
    {
        if (completion)
        {
            completion();
        }
        return;
    }

    [self dismissViewControllerAnimated:YES completion:completion];
    self.verifyCodeViewController = nil;
}

#pragma mark - New Password modal

- (void)presentNewPasswordModal
{
    if (self.verifyCodeViewController != nil)
    {
        __weak typeof(self) weakSelf = self;
        [self dismissVerifyCodeModalWithCompletion:^{
            [weakSelf showNewPasswordModal];
        }];
    }
    else
    {
        [self showNewPasswordModal];
    }
}

- (void)showNewPasswordModal
{
    self.pendingNewPasswordViewController =
        (NewPasswordViewController *)[self.storyboard instantiateViewControllerWithIdentifier:@"NewPasswordViewController"];

    if (!self.pendingNewPasswordViewController)
    {
        NSLog(@"Error creating password view controller");
        return;
    }

    [self updateNewPasswordModalWithErrorMessage:nil];
    [self presentViewController:self.pendingNewPasswordViewController animated:YES completion:nil];
}

- (void)updateNewPasswordModalWithErrorMessage:(nullable NSString *)errorMessage
{
    NewPasswordViewController *modal = self.pendingNewPasswordViewController;
    if (!modal)
    {
        return;
    }

    if (errorMessage)
    {
        modal.errorLabel.text = errorMessage;
    }

    __weak typeof(self) weakSelf = self;
    modal.onSubmit = ^(NSString *password) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf.onSubmitNewPassword)
            {
                strongSelf.onSubmitNewPassword(password);
            }
        });
    };
    modal.onCancel = ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf cancelFlow];
        });
    };
}

- (void)dismissNewPasswordModal
{
    if (self.pendingNewPasswordViewController == nil)
    {
        return;
    }

    [self dismissViewControllerAnimated:YES completion:nil];
    self.pendingNewPasswordViewController = nil;
}

- (void)dismissAnyModal
{
    if (self.verifyCodeViewController != nil)
    {
        [self dismissVerifyCodeModalWithCompletion:nil];
    }
    if (self.pendingNewPasswordViewController != nil)
    {
        [self dismissNewPasswordModal];
    }
}

#pragma mark - Native Auth V2 per-state delegates

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

- (void)onCodeRequiredWithState:(MSALNativeAuthCodeRequiredState *)state
                       scenario:(MSALNativeAuthFlowScenario)scenario
{
    NSLog(@"ObjCSignInViewController[%@]: state required — %@", [self labelForScenario:scenario], state.description);
    self.statusMessage = [NSString stringWithFormat:@"Code sent to %@ (%ld digits).", state.sentTo, (long)state.codeLength];

    __weak typeof(self) weakSelf = self;
    self.onSubmitCode = ^(NSString *code) {
        [state submitCode:code delegate:weakSelf];
    };
    self.onResendCode = ^{
        [state resendCodeWithDelegate:weakSelf];
    };
    [self presentVerifyCodeModal];
}

- (void)onPasswordRequiredWithState:(MSALNativeAuthPasswordRequiredState *)state
                           scenario:(MSALNativeAuthFlowScenario)scenario
{
    NSLog(@"ObjCSignInViewController[%@]: state required — %@", [self labelForScenario:scenario], state.description);
    self.statusMessage = @"Submitting password…";
    [state submitPassword:self.password delegate:self];
}

- (void)onNewPasswordRequiredWithState:(MSALNativeAuthNewPasswordRequiredState *)state
                              scenario:(MSALNativeAuthFlowScenario)scenario
{
    NSLog(@"ObjCSignInViewController[%@]: state required — %@", [self labelForScenario:scenario], state.description);
    __weak typeof(self) weakSelf = self;
    self.onSubmitNewPassword = ^(NSString *password) {
        [state submitNewPassword:password delegate:weakSelf];
    };
    [self presentNewPasswordModal];
}

- (void)onAttributesRequiredWithState:(MSALNativeAuthAttributesRequiredState *)state
                             scenario:(MSALNativeAuthFlowScenario)scenario
{
    NSLog(@"ObjCSignInViewController[%@]: state required — %@", [self labelForScenario:scenario], state.description);
    self.isSigningIn = NO;
    self.statusMessage = [NSString stringWithFormat:@"Action required: %@", state.description];
}

- (void)onAttributesInvalidWithState:(MSALNativeAuthAttributesInvalidState *)state
                            scenario:(MSALNativeAuthFlowScenario)scenario
{
    NSLog(@"ObjCSignInViewController[%@]: state required — %@", [self labelForScenario:scenario], state.description);
    self.isSigningIn = NO;
    self.statusMessage = [NSString stringWithFormat:@"Action required: %@", state.description];
}

- (void)onMFARequiredWithState:(MSALNativeAuthMFARequiredState *)state
                      scenario:(MSALNativeAuthFlowScenario)scenario
{
    NSLog(@"ObjCSignInViewController[%@]: state required — %@", [self labelForScenario:scenario], state.description);
    MSALAuthMethod *method = state.authMethods.firstObject;
    if (!method)
    {
        self.isSigningIn = NO;
        self.statusMessage = @"No auth methods available.";
        return;
    }
    self.statusMessage = @"Selecting authentication method…";
    [state selectAuthMethod:method verificationContact:nil delegate:self];
}

- (void)onMFAVerificationRequiredWithState:(MSALNativeAuthMFAVerificationRequiredState *)state
                                  scenario:(MSALNativeAuthFlowScenario)scenario
{
    NSLog(@"ObjCSignInViewController[%@]: state required — %@", [self labelForScenario:scenario], state.description);
    self.statusMessage = [NSString stringWithFormat:@"Verification code sent to %@ (%ld digits).", state.sentTo, (long)state.codeLength];
    __weak typeof(self) weakSelf = self;
    self.onSubmitCode = ^(NSString *code) {
        [state submitChallenge:code delegate:weakSelf];
    };
    self.onResendCode = nil;
    [self presentVerifyCodeModal];
}

- (void)onStrongAuthRegistrationRequiredWithState:(MSALNativeAuthStrongAuthRegistrationRequiredState *)state
                                         scenario:(MSALNativeAuthFlowScenario)scenario
{
    NSLog(@"ObjCSignInViewController[%@]: state required — %@", [self labelForScenario:scenario], state.description);
    MSALAuthMethod *method = state.authMethods.firstObject;
    if (!method)
    {
        self.isSigningIn = NO;
        self.statusMessage = @"No auth methods available.";
        return;
    }
    self.statusMessage = @"Selecting authentication method…";
    [state selectAuthMethod:method verificationContact:nil delegate:self];
}

- (void)onStrongAuthVerificationRequiredWithState:(MSALNativeAuthStrongAuthVerificationRequiredState *)state
                                         scenario:(MSALNativeAuthFlowScenario)scenario
{
    NSLog(@"ObjCSignInViewController[%@]: state required — %@", [self labelForScenario:scenario], state.description);
    self.statusMessage = [NSString stringWithFormat:@"Verification code sent to %@ (%ld digits).", state.sentTo, (long)state.codeLength];
    __weak typeof(self) weakSelf = self;
    self.onSubmitCode = ^(NSString *code) {
        [state submitChallenge:code delegate:weakSelf];
    };
    self.onResendCode = nil;
    [self presentVerifyCodeModal];
}

- (void)onFlowCompletedWithResult:(MSALNativeAuthUserAccountResult *)result
                         scenario:(MSALNativeAuthFlowScenario)scenario
{
    NSLog(@"ObjCSignInViewController[%@]: flow completed", [self labelForScenario:scenario]);
    self.accountResult = result;
    [self dismissAnyModal];
    self.isSigningIn = NO;
    self.isSignedIn = YES;
    self.statusMessage = [NSString stringWithFormat:@"Signed in as %@.", result.account.username ?: @"unknown user"];
}

- (void)onFlowErrorWithError:(MSALNativeAuthFlowError *)error
                    scenario:(MSALNativeAuthFlowScenario)scenario
{
    NSLog(@"ObjCSignInViewController[%@]: flow error — %@", [self labelForScenario:scenario], error.errorDescription ?: @"N/A");

    // The app decides recoverability from the error. On a recoverable error the modal's
    // submit/resend callbacks still capture the state, so re-submitting advances the flow.
    if (error.isInvalidCode && [self isVerifyCodeModalPresented])
    {
        [self updateVerifyCodeModalWithErrorMessage:@"Check the code and try again"];
    }
    else if (error.isInvalidPassword && [self isNewPasswordModalPresented])
    {
        [self updateNewPasswordModalWithErrorMessage:@"Invalid password"];
    }
    else if (error.isBrowserRequired)
    {
        [self dismissAnyModal];
        self.isSigningIn = NO;
        self.statusMessage = @"This flow must continue in a browser. Please sign in using the browser-based flow.";
    }
    else
    {
        [self dismissAnyModal];
        self.isSigningIn = NO;
        self.statusMessage = [NSString stringWithFormat:@"Sign in failed: %@ Error Code: %@.",
                              error.errorDescription ?: @"N/A", error.errorCodes];
    }
}

#pragma mark - CredentialsDelegate (silent access-token retrieval)

- (void)onAccessTokenRetrieveCompletedWithResult:(MSALNativeAuthTokenResult *)result
{
    // A token was acquired silently — the user is already signed in.
    self.isRestoringSession = NO;
    self.isSignedIn = YES;
    self.statusMessage = [NSString stringWithFormat:@"Signed in as %@.", self.accountResult.account.username ?: @"unknown user"];
}

- (void)onAccessTokenRetrieveErrorWithError:(RetrieveAccessTokenError *)error
{
    // Couldn't get a token silently (e.g. the user was signed out or interaction is required) —
    // show the sign-in UI.
    self.accountResult = nil;
    self.isRestoringSession = NO;
    self.isSignedIn = NO;
    self.statusMessage = nil;
}

#pragma mark - V1 flow helpers

- (void)wireV1SignInCodeCallbacks:(SignInCodeRequiredState *)state
{
    __weak typeof(self) weakSelf = self;
    self.onSubmitCode = ^(NSString *code) {
        [state submitCodeWithCode:code delegate:weakSelf];
    };
    self.onResendCode = ^{
        [state resendCodeWithDelegate:weakSelf];
    };
}

- (void)wireV1ResetPasswordCodeCallbacks:(ResetPasswordCodeRequiredState *)state
{
    __weak typeof(self) weakSelf = self;
    self.onSubmitCode = ^(NSString *code) {
        [state submitCodeWithCode:code delegate:weakSelf];
    };
    self.onResendCode = ^{
        [state resendCodeWithDelegate:weakSelf];
    };
}

- (void)wireV1ResetPasswordNewPasswordCallback:(ResetPasswordRequiredState *)state
{
    __weak typeof(self) weakSelf = self;
    self.onSubmitNewPassword = ^(NSString *password) {
        [state submitPasswordWithPassword:password delegate:weakSelf];
    };
}

- (void)handleV1SignInCompleted:(MSALNativeAuthUserAccountResult *)result
{
    [self resetFlowState];
    self.accountResult = result;
    [self dismissAnyModal];
    self.isSigningIn = NO;
    self.isSignedIn = YES;
    self.statusMessage = [NSString stringWithFormat:@"Signed in as %@.", result.account.username ?: @"unknown user"];
}

- (void)handleV1Error:(NSString *)message
{
    [self dismissAnyModal];
    self.isSigningIn = NO;
    self.statusMessage = message;
}

#pragma mark - V1 Sign In delegates

- (void)onSignInStartErrorWithError:(SignInStartError *)error
{
    if (error.isUserNotFound || error.isInvalidCredentials || error.isInvalidUsername)
    {
        [self handleV1Error:@"Invalid username or password."];
    }
    else
    {
        [self handleV1Error:[NSString stringWithFormat:@"Sign in failed: %@.", error.errorDescription ?: @"unknown error"]];
    }
}

- (void)onSignInCodeRequiredWithNewState:(SignInCodeRequiredState *)newState
                                  sentTo:(NSString *)sentTo
                       channelTargetType:(MSALNativeAuthChannelType *)channelTargetType
                              codeLength:(NSInteger)codeLength
{
    self.statusMessage = [NSString stringWithFormat:@"Code sent to %@ (%ld digits).", sentTo, (long)codeLength];
    [self wireV1SignInCodeCallbacks:newState];
    [self presentVerifyCodeModal];
}

- (void)onSignInCompletedWithResult:(MSALNativeAuthUserAccountResult *)result
{
    [self handleV1SignInCompleted:result];
}

- (void)onSignInVerifyCodeErrorWithError:(VerifyCodeError *)error
                                newState:(nullable SignInCodeRequiredState *)newState
{
    if (error.isInvalidCode && newState)
    {
        [self wireV1SignInCodeCallbacks:newState];
        [self updateVerifyCodeModalWithErrorMessage:@"Check the code and try again"];
    }
    else
    {
        [self handleV1Error:[NSString stringWithFormat:@"Sign in failed: %@.", error.errorDescription ?: @"unknown error"]];
    }
}

- (void)onSignInResendCodeErrorWithError:(ResendCodeError *)error
                                newState:(nullable SignInCodeRequiredState *)newState
{
    [self handleV1Error:@"Unable to resend the code."];
}

- (void)onSignInResendCodeCodeRequiredWithNewState:(SignInCodeRequiredState *)newState
                                            sentTo:(NSString *)sentTo
                                 channelTargetType:(MSALNativeAuthChannelType *)channelTargetType
                                        codeLength:(NSInteger)codeLength
{
    [self wireV1SignInCodeCallbacks:newState];
    [self updateVerifyCodeModalWithErrorMessage:nil];
}

#pragma mark - V1 Reset Password delegates

- (void)onResetPasswordStartErrorWithError:(ResetPasswordStartError *)error
{
    if (error.isInvalidUsername || error.isUserNotFound)
    {
        [self handleV1Error:@"Unable to reset password: the email is invalid."];
    }
    else if (error.isUserDoesNotHavePassword)
    {
        [self handleV1Error:@"Unable to reset password: no password associated with this email."];
    }
    else
    {
        [self handleV1Error:[NSString stringWithFormat:@"Unable to reset password: %@.", error.errorDescription ?: @"unknown error"]];
    }
}

- (void)onResetPasswordCodeRequiredWithNewState:(ResetPasswordCodeRequiredState *)newState
                                         sentTo:(NSString *)sentTo
                              channelTargetType:(MSALNativeAuthChannelType *)channelTargetType
                                     codeLength:(NSInteger)codeLength
{
    self.statusMessage = [NSString stringWithFormat:@"Code sent to %@ (%ld digits).", sentTo, (long)codeLength];
    [self wireV1ResetPasswordCodeCallbacks:newState];
    [self presentVerifyCodeModal];
}

- (void)onResetPasswordVerifyCodeErrorWithError:(VerifyCodeError *)error
                                       newState:(nullable ResetPasswordCodeRequiredState *)newState
{
    if (error.isInvalidCode && newState)
    {
        [self wireV1ResetPasswordCodeCallbacks:newState];
        [self updateVerifyCodeModalWithErrorMessage:@"Check the code and try again"];
    }
    else
    {
        [self handleV1Error:[NSString stringWithFormat:@"Unable to reset password: %@.", error.errorDescription ?: @"unknown error"]];
    }
}

- (void)onPasswordRequiredWithNewState:(ResetPasswordRequiredState *)newState
{
    [self wireV1ResetPasswordNewPasswordCallback:newState];
    [self presentNewPasswordModal];
}

- (void)onResetPasswordResendCodeErrorWithError:(ResendCodeError *)error
                                       newState:(nullable ResetPasswordCodeRequiredState *)newState
{
    [self handleV1Error:@"Unable to resend the code."];
}

- (void)onResetPasswordResendCodeRequiredWithNewState:(ResetPasswordCodeRequiredState *)newState
                                               sentTo:(NSString *)sentTo
                                    channelTargetType:(MSALNativeAuthChannelType *)channelTargetType
                                           codeLength:(NSInteger)codeLength
{
    [self wireV1ResetPasswordCodeCallbacks:newState];
    [self updateVerifyCodeModalWithErrorMessage:nil];
}

- (void)onResetPasswordRequiredErrorWithError:(PasswordRequiredError *)error
                                     newState:(nullable ResetPasswordRequiredState *)newState
{
    if (error.isInvalidPassword && newState)
    {
        [self wireV1ResetPasswordNewPasswordCallback:newState];
        [self updateNewPasswordModalWithErrorMessage:@"Invalid password"];
    }
    else
    {
        [self handleV1Error:[NSString stringWithFormat:@"Error setting password: %@.", error.errorDescription ?: @"unknown error"]];
    }
}

- (void)onResetPasswordCompletedWithNewState:(SignInAfterResetPasswordState *)newState
{
    [self dismissAnyModal];
    self.statusMessage = @"Password reset. Signing in…";
    MSALNativeAuthSignInAfterResetPasswordParameters *parameters = [[MSALNativeAuthSignInAfterResetPasswordParameters alloc] init];
    [newState signInParameters:parameters delegate:self];
}

- (void)onSignInAfterResetPasswordErrorWithError:(SignInAfterResetPasswordError *)error
{
    [self handleV1Error:[NSString stringWithFormat:@"Error signing in after password reset: %@.", error.errorDescription ?: @"unknown error"]];
}

@end
