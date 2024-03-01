# A native authentication iOS (Swift) sample app using MSAL to authenticate users and call a web API using Microsoft Entra External ID

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

## Prerequisite

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

## Contributing

If you'd like to contribute to this sample, see [CONTRIBUTING.MD](/CONTRIBUTING.md).

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information, see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
