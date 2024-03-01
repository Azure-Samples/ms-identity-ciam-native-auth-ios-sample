# A native authentication iOS (Swift) sample app using MSAL to authenticate users and call a web API using Microsoft Entra External ID

* [Overview](#overview)
* [Contents](#contents)
* [Prerequisites](#prerequisites)
* [Project setup](#project-setup)
* [Key concepts](#key-concepts)
* [Contributing](#contributing)

## Overview

This sample iOS sample applications demonstrates how sign-up, sign in, sign out, reset password scenarios and call a web API using Microsoft Entra External ID for customers.

## Contents

| File/folder | Description |
|-------------|-------------|
| `NativeAuthSampleApp`       | Sample source code. |
| `.gitignore` | Define what to ignore at commit time. |
| `CHANGELOG.md` | List of changes to the sample. |
| `CONTRIBUTING.md` | Guidelines for contributing to the sample. |
| `README.md` | This README file. |
| `LICENSE`   | The license for the sample. |

## Prerequisites

- <a href="https://developer.apple.com/xcode/resources/" target="_blank">Xcode</a>
- Microsoft Entra External ID for customers tenant. If you don't already have one, <a href="https://aka.ms/ciam-free-trial?wt.mc_id=ciamcustomertenantfreetrial_linkclick_content_cnl" target="_blank">sign up for a free trial</a>

## Project setup

To enable your application to authenicate users with Microsoft Entra, Microsoft Entra ID for customers must be made aware of the application you create. The following steps show you how to:

1. [Register an application](https://review.learn.microsoft.com/en-us/entra/external-id/customers/how-to-run-native-authentication-sample-ios-app?branch=pr-en-us-2024#register-an-application)
1. [Enable public client and native authentication flows](https://review.learn.microsoft.com/en-us/entra/external-id/customers/how-to-run-native-authentication-sample-ios-app?branch=pr-en-us-2024#enable-public-client-and-native-authentication-flows)
1. [Grant API permissions](https://review.learn.microsoft.com/en-us/entra/external-id/customers/how-to-run-native-authentication-sample-ios-app?branch=pr-en-us-2024#grant-api-permissions)
1. [Create a user flow](https://review.learn.microsoft.com/en-us/entra/external-id/customers/how-to-run-native-authentication-sample-ios-app?branch=pr-en-us-2024#create-a-user-flow)
1. [Associate the application with the user flow](https://review.learn.microsoft.com/en-us/entra/external-id/customers/how-to-run-native-authentication-sample-ios-app?branch=pr-en-us-2024#associate-the-application-with-the-user-flow)
1. [Clone sample iOS mobile application](https://review.learn.microsoft.com/en-us/entra/external-id/customers/how-to-run-native-authentication-sample-ios-app?branch=pr-en-us-2024#clone-sample-ios-mobile-application)
1. [Configure the sample iOS mobile application](https://review.learn.microsoft.com/en-us/entra/external-id/customers/how-to-run-native-authentication-sample-ios-app?branch=pr-en-us-2024#configure-the-sample-ios-mobile-application)
1. [Run and test sample iOS mobile application](https://review.learn.microsoft.com/en-us/entra/external-id/customers/how-to-run-native-authentication-sample-ios-app?branch=pr-en-us-2024#run-and-test-sample-ios-mobile-application)

## Key concepts

Let's take a quick review of what's happenning in the app. Open `NativeAuthSampleApp/Configuration.swift` file and you find the following lines of code:

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

- _clientId_ - the value _Enter_the_Application_Id_Here_ is be replaced with **Application (client) ID** of the app you register during the project setup. The **Application (client) ID** is unique identifier of your registered application.
- _tenantSubdomain_ - the value _Enter_the_Tenant_Subdomain_Here_ is replaced with the Directory (tenant) subdomain. The tenant subdomain URL is used to construct the authentication endpoint for your app.

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

To learn more, see [Tutorial: Prepare your iOS app for native authentication](https://review.learn.microsoft.com/en-us/entra/external-id/customers/tutorial-native-authentication-prepare-ios-app?branch=pr-en-us-2024)

## Contributing

If you'd like to contribute to this sample, see [CONTRIBUTING.MD](/CONTRIBUTING.md).

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information, see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
