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

@MainActor private var protectedAPITokenDelegates: [ObjectIdentifier: ProtectedAPITokenDelegate] = [:]

private final class ProtectedAPITokenDelegate: NSObject, CredentialsDelegate
{
    private let onCompleted: @MainActor (MSALNativeAuthTokenResult) -> Void
    private let onError: @MainActor (RetrieveAccessTokenError) -> Void

    init(
        onCompleted: @escaping @MainActor (MSALNativeAuthTokenResult) -> Void,
        onError: @escaping @MainActor (RetrieveAccessTokenError) -> Void
    )
    {
        self.onCompleted = onCompleted
        self.onError = onError
    }

    @MainActor
    func onAccessTokenRetrieveCompleted(result: MSALNativeAuthTokenResult)
    {
        onCompleted(result)
    }

    @MainActor
    func onAccessTokenRetrieveError(error: RetrieveAccessTokenError)
    {
        onError(error)
    }
}

// MARK: - Protected API

extension SignInViewModel
{
    private var protectedAPIUrl: String?
    {
        nil
    }

    private var protectedAPIScopes: [String]
    {
        []
    }

    @MainActor
    func callProtectedAPI()
    {
        guard let accountResult = accountResult else
        {
            protectedAPIResult = "No signed-in account is available."
            return
        }

        guard let apiUrl = protectedAPIUrl, !protectedAPIScopes.isEmpty else
        {
            protectedAPIResult = "Protected API not configured. Set the API URL and scopes in SignInViewModel+ProtectedAPI.swift."
            return
        }

        statusMessage = "Retrieving access token to call the protected API…"
        protectedAPIResult = nil

        let parameters = MSALNativeAuthGetAccessTokenParameters()
        parameters.scopes = protectedAPIScopes

        let key = ObjectIdentifier(self)
        let delegate = ProtectedAPITokenDelegate(
            onCompleted: { [weak self] tokenResult in
                guard let self = self else { return }
                protectedAPITokenDelegates[key] = nil
                self.accessProtectedAPI(apiUrl: apiUrl, accessToken: tokenResult.accessToken)
            },
            onError: { [weak self] error in
                protectedAPITokenDelegates[key] = nil
                self?.statusMessage = "Unable to retrieve an access token."
                self?.protectedAPIResult = "Error retrieving access token: \(error.errorDescription ?? "unknown error")"
            }
        )
        protectedAPITokenDelegates[key] = delegate
        accountResult.getAccessToken(parameters: parameters, delegate: delegate)
    }

    @MainActor
    private func accessProtectedAPI(apiUrl: String, accessToken: String)
    {
        guard let url = URL(string: apiUrl) else
        {
            protectedAPIResult = "Invalid API URL."
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error
            {
                Task { @MainActor in
                    self?.statusMessage = "Protected API call failed."
                    self?.protectedAPIResult = error.localizedDescription
                }
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else
            {
                Task { @MainActor in
                    self?.statusMessage = "Protected API call failed."
                    self?.protectedAPIResult = "No HTTP response was returned."
                }
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else
            {
                Task { @MainActor in
                    self?.statusMessage = "Protected API call failed."
                    self?.protectedAPIResult = "HTTP response code: \(httpResponse.statusCode)"
                }
                return
            }

            let body: String
            if let data = data, let text = String(data: data, encoding: .utf8)
            {
                body = text
            }
            else
            {
                body = "<empty response>"
            }

            Task { @MainActor in
                self?.statusMessage = "Accessed the protected API successfully."
                self?.protectedAPIResult = """
                Accessed API successfully using an access token.
                HTTP response code: \(httpResponse.statusCode)
                HTTP response body:
                \(body)
                """
            }
        }.resume()
    }
}
