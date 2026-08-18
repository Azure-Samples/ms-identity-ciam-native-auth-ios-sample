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

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct SignInView: View
{
    @ObservedObject var viewModel: SignInViewModel

    init(viewModel: SignInViewModel = SignInViewModel())
    {
        self.viewModel = viewModel
    }

    var body: some View
    {
        VStack(spacing: 16)
        {
            if viewModel.isSignedIn
            {
                SignedInView(viewModel: viewModel)
            }
            else if viewModel.isRestoringSession
            {
                restoringSessionContent
            }
            else
            {
                signInContent
            }

            if !viewModel.isSignedIn, let statusMessage = viewModel.statusMessage
            {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()
        }
        .padding()
        .sheet(item: $viewModel.activeSheet)
        { sheet in
            switch sheet
            {
            case .verifyCode:
                VerifyCodeSheet(viewModel: viewModel)
            case .newPassword:
                NewPasswordSheet(viewModel: viewModel)
            case .collectAttributes:
                CollectAttributesSheet(viewModel: viewModel)
            case .selectAuthMethod:
                SelectAuthMethodSheet(viewModel: viewModel)
            case .verificationContact:
                VerificationContactSheet(viewModel: viewModel)
            }
        }
        .onAppear
        {
            viewModel.loadCachedSession()
            viewModel.presentationAnchorProvider =
            {
                Self.presentationAnchor()
            }
        }
    }

    private var restoringSessionContent: some View
    {
        VStack(spacing: 16)
        {
            ProgressView()
            Text("Restoring your session…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var signInContent: some View
    {
        VStack(spacing: 16)
        {
            Text("Sign In")
                .font(.largeTitle)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("Use V2 API (preview)", isOn: $viewModel.useV2Api)
                .disabled(viewModel.isSigningIn)

            TextField("Email", text: $viewModel.email)
                .textFieldStyle(.roundedBorder)

            VStack(spacing: 4)
            {
                SecureField("Password", text: $viewModel.password)
                    .textFieldStyle(.roundedBorder)

                Text("Leave the password empty to sign in with a one-time email code.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button(action: viewModel.signIn)
            {
                Text("Sign In")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isSignInDisabled)

            Button(action: viewModel.signUp)
            {
                Text("Sign Up")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isSignUpDisabled)

            Button(action: viewModel.resetPassword)
            {
                Text("Reset Password")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isResetPasswordDisabled)

            Button(action: viewModel.signInWithBrowser)
            {
                Text("Sign in with Browser")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isSigningIn)

            socialSignInContent
        }
    }

    private var socialSignInContent: some View
    {
        VStack(spacing: 8)
        {
            Text("Sign in with social")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(SocialProvider.allCases)
            { provider in
                Button(action:
                {
                    viewModel.signInWithSocial(provider: provider)
                })
                {
                    Text(provider.displayName)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isSigningIn)
            }
        }
    }

    private static func presentationAnchor() -> Any?
    {
        #if os(iOS)
        return UIApplication.shared.connectedScenes
            .compactMap
            {
                $0 as? UIWindowScene
            }
            .flatMap
            {
                $0.windows
            }
            .first
            {
                $0.isKeyWindow
            }
        #elseif os(macOS)
        return NSApplication.shared.keyWindow
        #else
        return nil
        #endif
    }
}

#Preview
{
    SignInView()
}
