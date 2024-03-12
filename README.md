# Sign in users and call a protected web API in iOS (Swift) mobile app by using native authentication

* [Overview](#overview)
* [Contents](#contents)
* [Prerequisites](#prerequisites)
* [Project setup](#project-setup)
* [Key concepts](#key-concepts)
* [Reporting problems](#reporting-problems)
* [Contributing](#contributing)

## Overview

This sample iOS sample applications demonstrates how to handle sign-up, sign-in, sign out, and reset password scenarios using Microsoft Entra External ID for customers. You can configure the sample to call a protected web API.

## Contents

| File/folder | Description |
|-------------|-------------|
| `NativeAuthSampleApp/Configuration.swift`       | Configuration file. |
| `.gitignore` | Define what to ignore at commit time. |
| `CHANGELOG.md` | List of changes to the sample. |
| `CONTRIBUTING.md` | Guidelines for contributing to the sample. |
| `README.md` | This README file. |
| `LICENSE`   | The license for the sample. |

## Prerequisites

* <a href="https://developer.apple.com/xcode/resources/" target="_blank">Xcode</a>
* Microsoft Entra External ID for customers tenant. If you don't already have one, <a href="https://aka.ms/ciam-free-trial?wt.mc_id=ciamcustomertenantfreetrial_linkclick_content_cnl" target="_blank">sign up for a free trial</a>

## Project setup

To enable your application to authenicate users with Microsoft Entra, Microsoft Entra ID for customers must be made aware of the application you create. The following steps show you how to:

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

### Step 6: Clone sample iOS mobile application

Clone the sample iOS mobile application by following the steps outlined in [Clone sample iOS mobile application](https://learn.microsoft.com/entra/external-id/customers/how-to-run-native-authentication-sample-ios-app#clone-sample-ios-mobile-application).
 
### Step 7: Configure the sample iOS mobile application

Configure the sample iOS mobile application by following the steps in [Configure the sample iOS mobile application](https://learn.microsoft.com/entra/external-id/customers/how-to-run-native-authentication-sample-ios-app#configure-the-sample-ios-mobile-application).

### Step 8: Run and test sample iOS mobile application

Run and test the iOS sample mobile application by following the steps in [Run and test sample iOS mobile application](https://learn.microsoft.com/entra/external-id/customers/how-to-run-native-authentication-sample-ios-app#run-and-test-sample-ios-mobile-application).

### Step 9: Call a protected web API

Follow the steps in Sign in users and call an API in a sample iOS mobile app by using native authentication to [sign in users and call a protected API in the iOS sample mobile app](https://learn.microsoft.com//entra/external-id/customers/sample-native-authentication-ios-sample-app-call-web-api).

## Key concepts

Open `NativeAuthSampleApp/Configuration.swift` file and you find the following lines of code:

```swift
import MSAL

@objcMembers
class Configuration: NSObject {
    // Update the below to your client ID and tenantSubdomain you received in the portal.

    static let clientId = "Enter_the_Application_Id_Here"
    static let tenantSubdomain = "Enter_the_Tenant_Subdomain_Here"
}
```

The code creates two constant properties:

* _clientId_ - the value _Enter_the_Application_Id_Here_ is replaced with **Application (client) ID** of the app you register during the project setup. The **Application (client) ID** is unique identifier of your registered application.
* _tenantSubdomain_ - the value _Enter_the_Tenant_Subdomain_Here_ is replaced with the Directory (tenant) subdomain. The tenant subdomain URL is used to construct the authentication endpoint for your app.

You use `NativeAuthSampleApp/Configuration.swift` file to set configuration options when you initialize the client app in the Microsoft Authentication Library (MSAL).

To create SDK instance, use the following code:

```swift
import MSAL

var nativeAuth: MSALNativeAuthPublicClientApplication!

do {
    nativeAuth = try MSALNativeAuthPublicClientApplication(
        clientId: Configuration.clientId,
        tenantSubdomain: Configuration.tenantSubdomain,
        challengeTypes: [.OOB, .password]
    )
} catch {
    print("Unable to initialize MSAL \(error)")
    showResultText("Unable to initialize MSAL")
}
```

You create MSL instance so that we can perform authentication logic and interact with our tenant through native authentication APIs. For more information about SDK instance, see [Tutorial: Prepare your iOS app for native authentication](https://learn.microsoft.com/en-gb/entra/external-id/customers/tutorial-native-authentication-prepare-ios-app#create-sdk-instance)

## Reporting problems

* Search the [GitHub issues](https://github.com/Azure-Samples/ms-identity-ciam-native-auth-ios-sample/issues) in the repository - your problem might already have been reported or have an answer.
* Nothing similar? [Open an issue](https://github.com/Azure-Samples/ms-identity-ciam-native-auth-ios-sample/issues/new) that clearly explains the problem you're having running the sample app.

## Contributing

If you'd like to contribute to this sample, see [CONTRIBUTING.MD](/CONTRIBUTING.md).

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information, see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
