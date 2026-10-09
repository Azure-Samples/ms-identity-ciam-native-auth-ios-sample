# Sign in users and call a protected web API in an iOS/macOS SwiftUI app using native authentication

* [Overview](#overview)
* [Contents](#contents)
* [Prerequisites](#prerequisites)
* [Project setup](#project-setup)
* [Key concepts](#key-concepts)
* [Reporting problems](#reporting-problems)
* [Contributing](#contributing)

## Overview

This SwiftUI application demonstrates sign-up, sign-in, sign-out, and self-service password reset using Microsoft Entra External ID for customers on iOS and macOS. It uses Microsoft Authentication Library (MSAL) **2.16.0**, obtained through Swift Package Manager (SPM).

The **Use V2 API (preview)** toggle is enabled by default. V2 uses server-driven authentication states; turning the toggle off selects the V1 per-step delegate APIs. Both share the same screens and configuration.

> Native Auth V2 APIs in MSAL 2.16.0 are experimental, may change without notice, and must not be used in production applications. Availability of individual flows depends on your tenant configuration and service support.

The sample includes password and email one-time-code sign-in, sign-up with attribute collection, password reset, MFA and strong-auth registration states, browser/social sign-in, cached-session restoration, and sign-out. An optional protected-API call is available after sign-in. Authentication method selection and verification prompts appear when requested by the service.

## Contents

| File/folder | Description |
|-------------|-------------|
| `NativeAuthSampleApp.xcodeproj`      | This sample application project file. |
| `NativeAuthSampleApp/Configuration.swift`       | Configuration file. |
| `NativeAuthSampleApp/App/NativeAuthSampleAppApp.swift` | Shared SwiftUI entry point and MSAL logging setup. |
| `NativeAuthSampleApp/SignIn/ViewModels/SignInViewModel.swift` | Shared authentication state, initialization, browser sign-in, and protected-API setup. |
| `NativeAuthSampleApp/SignIn/ViewModels/SignInViewModel+V1.swift` | V1 flow delegates. |
| `NativeAuthSampleApp/SignIn/ViewModels/SignInViewModel+V2.swift` | V2 state delegates. |
| `NativeAuthSampleApp/SignIn/Views/` | Shared sign-in/signed-in screens and authentication sheets. |
| `NativeAuthSampleApp.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` | Resolved MSAL release and revision. |
| `CONTRIBUTING.md` | Guidelines for contributing to the sample. |
| `README.md` | This README file. |
| `LICENSE.md`   | The license for the sample. |

## Prerequisites

* <a href="https://developer.apple.com/xcode/resources/" target="_blank">Xcode</a> with SDKs supporting the sample's deployment targets: **iOS 17.6 or later** and **macOS 14.6 or later**. Use a current stable Xcode compatible with the released MSAL binary.
* Internet access to resolve the MSAL Swift package and download its binary framework. No separate MSAL source checkout, CocoaPods, or Carthage setup is needed.
* Microsoft Entra External ID for customers tenant. If you don't already have one, <a href="https://aka.ms/ciam-free-trial?wt.mc_id=ciamcustomertenantfreetrial_linkclick_content_cnl" target="_blank">sign up for a free trial</a>

## Project setup

To enable your application to authenticate users with Microsoft Entra, Microsoft Entra ID for customers must be made aware of the application you create. The following steps show you how to:

### Step 1: Register an application

Register your app in the Microsoft Entra admin center using the steps in [Register an application](https://learn.microsoft.com/entra/external-id/customers/how-to-run-native-authentication-sample-ios-app#register-an-application).

### Step 2: Enable public client and native authentication flows

Enable public client and native authentication flows for the registered application using the steps in [Enable public client and native authentication flows](https://learn.microsoft.com/entra/external-id/customers/how-to-run-native-authentication-sample-ios-app#enable-public-client-and-native-authentication-flows).

### Step 3: Grant API permissions

Grant API permissions to the registered application by following the steps in [Grant API permissions](https://learn.microsoft.com/entra/external-id/customers/how-to-run-native-authentication-sample-ios-app#grant-api-permissions).

### Step 4: Create user flow

Create a user flow by following the steps in [Create a user flow](https://learn.microsoft.com/entra/external-id/customers/how-to-run-native-authentication-sample-ios-app#create-a-user-flow).

### Step 5: Associate the app with the user flow

Associate the application with the user flow by following the steps in [Associate the application with the user flow](https://learn.microsoft.com/entra/external-id/customers/how-to-run-native-authentication-sample-ios-app#associate-the-application-with-the-user-flow).

### Step 6: Clone the sample and resolve MSAL

```sh
git clone https://github.com/Azure-Samples/ms-identity-ciam-native-auth-ios-sample.git
cd ms-identity-ciam-native-auth-ios-sample
open NativeAuthSampleApp.xcodeproj
```

Xcode resolves the existing package dependency from `https://github.com/AzureAD/microsoft-authentication-library-for-objc`. The project uses the **Exact Version: 2.16.0** rule and links the `MSAL` product to the shared application target. Do not add a second MSAL framework or local Xcode subproject.

To update MSAL later, select a reviewed release in the project's **Package Dependencies**, change the exact version, resolve packages, and commit both the project file and `Package.resolved`. Validate both platforms and both API modes before updating the pin.

### Step 7: Configure the sample

Replace `clientId`, `tenantSubdomain`, and `tenantId` in `NativeAuthSampleApp/Configuration.swift` with your app registration and tenant values, as described under [Key concepts](#key-concepts). Both native and browser sign-in use `https://<tenant-subdomain>.ciamlogin.com/<tenant-id>`. No test data-center or slice is configured.

In the `NativeAuthSampleApp` target's **Signing & Capabilities**, choose your development team and a bundle identifier for your app. Register `msauth.<bundle-identifier>://auth` as the redirect URI. `Info.plist` derives the URL scheme from the bundle identifier and includes the `msauthv2` and `msauthv3` query schemes.

Keep the platform-specific keychain entitlements: `com.microsoft.adalcache` on iOS and `com.microsoft.identity.universalstorage` on macOS, each prefixed by your app identifier prefix. The macOS entitlements also enable the app sandbox and outgoing network connections. Follow the [MSAL configuration guidance](https://learn.microsoft.com/entra/msal/objc/install-and-configure-msal#configuring-your-project-to-use-msal) when adjusting signing or keychain settings.

The browser sign-in path requests `User.Read`; ensure the delegated permission is granted to the registration. The social buttons offer Google, Facebook, Apple, and LinkedIn through browser-based sign-in. Configure the corresponding identity providers in your tenant/user flow before using them; the buttons alone do not enable providers.

### Step 8: Run the sample

Select the **NativeAuthSampleApp** scheme, then choose a compatible iOS simulator/device or **My Mac** and run from Xcode.

Enter an email address and password for password sign-in, or leave the password empty to request an email one-time code. Use **Sign Up** or **Reset Password** for those flows and follow the service-requested sheets. The app attempts to restore a cached native-auth session on launch. After sign-in, the signed-in screen provides **Sign Out** and **Call Protected API**.

Use the V2 toggle before starting a flow to compare V1 and V2 behavior. Test signup, sign-in, reset-password, invalid-code retry, cancellation, configured MFA/registration methods, browser sign-in, session restoration, and sign-out against your own tenant. This project does not currently include an automated test target.

### Step 9: Call a protected web API

Register and expose your API, grant its delegated permissions, and obtain the API URL and scope using the [protected API setup guide](https://learn.microsoft.com/entra/external-id/customers/sample-native-authentication-ios-sample-app-call-web-api).

In the **Protected API** extension of `NativeAuthSampleApp/SignIn/ViewModels/SignInViewModel.swift`, replace the `nil` returned by `protectedAPIUrl` with your HTTPS endpoint and the empty `protectedAPIScopes` array with your API's delegated scopes. The button acquires a token for those scopes and sends a bearer-authenticated GET request. Until configured, it displays a configuration message instead of calling an API.

## Key concepts

Open `NativeAuthSampleApp/Configuration.swift` file and you find the following lines of code:

```swift
import MSAL

@objcMembers
class Configuration: NSObject {
    // Update the client ID, tenant subdomain, and tenant ID from the portal.

    static let clientId = "Enter_the_Application_Id_Here"
    static let tenantSubdomain = "Enter_the_Tenant_Subdomain_Here"
    static let tenantId = "Enter_the_Tenant_Id_Here"

    static var authorityURL: URL {
        URL(string: "https://\(tenantSubdomain).ciamlogin.com/\(tenantId)")!
    }
}
```

The code defines three configuration values and a shared authority URL:

* _clientId_ - the value _Enter_the_Application_Id_Here_ is replaced with **Application (client) ID** of the app you register during the project setup. The **Application (client) ID** is unique identifier of your registered application.
* _tenantSubdomain_ - the value _Enter_the_Tenant_Subdomain_Here_ is replaced with the Directory (tenant) subdomain. The tenant subdomain URL is used to construct the authentication endpoint for your app.
* _tenantId_ - replace _Enter_the_Tenant_Id_Here_ with the **Directory (tenant) ID** from your tenant's overview page.
* _authorityURL_ - combines the tenant subdomain and tenant ID into the authority used by both authentication paths.

You use `NativeAuthSampleApp/Configuration.swift` file to set configuration options when you initialize the client app in the Microsoft Authentication Library (MSAL).

To create SDK instance, use the following code:

```swift
import MSAL

func makeNativeAuth() throws -> MSALNativeAuthPublicClientApplication {
    let authority = try MSALCIAMAuthority(url: Configuration.authorityURL)
    let config = MSALNativeAuthPublicClientApplicationConfig(
        clientId: Configuration.clientId,
        authority: authority,
        challengeTypes: [.OOB, .password]
    )
    config.capabilities = [.mfaRequired, .registrationRequired]
    return try MSALNativeAuthPublicClientApplication(nativeAuthConfiguration: config)
}
```

The view model uses this configuration pattern and catches initialization errors to display an error status. The capabilities advertise support for MFA and strong-auth registration; tenant policy determines when these states are required. For more information, see [Tutorial: Prepare your iOS app for native authentication](https://learn.microsoft.com/entra/external-id/customers/tutorial-native-authentication-prepare-ios-app#create-sdk-instance).

## Reporting problems

* Search the [GitHub issues](https://github.com/Azure-Samples/ms-identity-ciam-native-auth-ios-sample/issues) in the repository - your problem might already have been reported or have an answer.
* Nothing similar? [Open an issue](https://github.com/Azure-Samples/ms-identity-ciam-native-auth-ios-sample/issues/new) that clearly explains the problem you're having running the sample app.

## Contributing

If you'd like to contribute to this sample, see [CONTRIBUTING.md](/CONTRIBUTING.md).

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information, see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
