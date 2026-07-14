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

import Foundation
import MSAL

#if os(iOS) && canImport(UIKit)
import UIKit
#endif

#if os(macOS) && canImport(AppKit)
import AppKit
#endif

// MARK: - Browser and social sign-in

extension SignInViewModel
{
    func signInWithBrowser()
    {
        startBrowserSignIn(domainHint: nil, displayName: "browser")
    }

    func signInWithSocial(provider: SocialProvider)
    {
        startBrowserSignIn(domainHint: provider.domainHint, displayName: provider.displayName)
    }

    private func startBrowserSignIn(domainHint: String?, displayName: String)
    {
        guard !isSigningIn else
        {
            return
        }

        resetFlowState()
        isSigningIn = true
        statusMessage = "Signing in with \(displayName)…"

        guard let webviewParameters = makeWebviewParameters() else
        {
            isSigningIn = false
            statusMessage = "Unable to start browser sign-in: no presentation anchor is available."
            return
        }

        let application: MSALPublicClientApplication
        do
        {
            application = try webBrowserApplication()
        }
        catch
        {
            isSigningIn = false
            statusMessage = "Unable to initialize browser sign-in: \(error.localizedDescription)"
            return
        }

        let parameters = MSALInteractiveTokenParameters(scopes: ["User.Read"], webviewParameters: webviewParameters)
        parameters.promptType = .login
        parameters.domainHint = domainHint

        application.acquireToken(with: parameters) { [weak self] result, error in
            DispatchQueue.main.async
            {
                guard let self = self else { return }

                if let error = error
                {
                    self.isSigningIn = false
                    self.statusMessage = "Error acquiring token: \(error.localizedDescription)"
                    return
                }

                guard result?.account != nil else
                {
                    self.isSigningIn = false
                    self.statusMessage = "Could not acquire token: no account returned."
                    return
                }

                if let account = self.application?.getNativeAuthUserAccount()
                {
                    self.accountResult = account
                }

                self.isSigningIn = false
                self.isSignedIn = true
                self.statusMessage = "Signed in successfully with \(displayName)."
            }
        }
    }

    private func webBrowserApplication() throws -> MSALPublicClientApplication
    {
        if let webBrowserApp = webBrowserApp
        {
            return webBrowserApp
        }

        guard let authorityUrl = URL(string: "https://\(Configuration.tenantSubdomain).ciamlogin.com") else
        {
            throw WebSignInError.invalidAuthority
        }

        let authority = try MSALCIAMAuthority(url: authorityUrl)
        let config = MSALPublicClientApplicationConfig(
            clientId: Configuration.clientId,
            redirectUri: nil,
            authority: authority
        )
        config.sliceConfig = Configuration.sliceConfig

        let application = try MSALPublicClientApplication(configuration: config)
        webBrowserApp = application
        return application
    }

    private func makeWebviewParameters() -> MSALWebviewParameters?
    {
        guard let anchor = presentationAnchorProvider?() else
        {
            return nil
        }

        #if os(iOS) && canImport(UIKit)
        guard let window = anchor as? UIWindow, let viewController = window.rootViewController else
        {
            return nil
        }
        return MSALWebviewParameters(authPresentationViewController: viewController)
        #elseif os(macOS) && canImport(AppKit)
        guard let window = anchor as? NSWindow, let viewController = window.contentViewController else
        {
            return nil
        }
        return MSALWebviewParameters(authPresentationViewController: viewController)
        #else
        return nil
        #endif
    }
}

private extension SocialProvider
{
    var domainHint: String
    {
        switch self
        {
        case .linkedin:
            return "www.linkedin.com"
        default:
            return displayName
        }
    }
}

private enum WebSignInError: LocalizedError
{
    case invalidAuthority

    var errorDescription: String?
    {
        switch self
        {
        case .invalidAuthority:
            return "The CIAM authority URL is invalid."
        }
    }
}
