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
                signedInContent
            }
            else if viewModel.isRestoringSession
            {
                restoringSessionContent
            }
            else
            {
                signInContent
            }

            if let statusMessage = viewModel.statusMessage
            {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer()
        }
        .padding()
        .onAppear
        {
            viewModel.loadCachedSession()
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

            if viewModel.useV2Api
            {
                Toggle("Drive V2 sign-in from Objective-C", isOn: $viewModel.useObjCV2Driver)
                    .disabled(viewModel.isSigningIn)
            }

            TextField("Email", text: $viewModel.email)
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .textFieldStyle(.roundedBorder)

            SecureField("Password", text: $viewModel.password)
                .textContentType(.password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .textFieldStyle(.roundedBorder)

            Button(action: viewModel.signIn)
            {
                Text("Sign In")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isSignInDisabled)

            Button(action: viewModel.resetPassword)
            {
                Text("Reset Password")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isResetPasswordDisabled)
        }
    }

    private var signedInContent: some View
    {
        VStack(spacing: 16)
        {
            Text("Signed In")
                .font(.largeTitle)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: viewModel.signOut)
            {
                Text("Sign Out")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview
{
    SignInView()
}
