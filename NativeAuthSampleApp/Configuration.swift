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

import MSAL

@objcMembers
class Configuration: NSObject {
    static let clientId = "Enter_the_Application_Id_Here"
    static let tenantSubdomain = "Enter_the_Tenant_Subdomain_Here"

    /// Optional protected API settings. Leave both values empty to use authentication without
    /// calling an API.
    static let protectedAPIEndpoint = ""
    static let protectedAPIScopes: [String] = []

    /// Internal test-slice routing is opt-in. Keep this `nil` for production routing.
    static let testSliceDataCenter: String? = nil

    static var sliceConfig: MSALSliceConfig? {
        guard let dc = testSliceDataCenter else { return nil }
        return MSALSliceConfig(slice: nil, dc: dc)
    }

    static var identityConfigurationError: String? {
        if clientId == "Enter_the_Application_Id_Here" || tenantSubdomain == "Enter_the_Tenant_Subdomain_Here" {
            return "Configure clientId and tenantSubdomain in Configuration.swift before signing in."
        }
        guard UUID(uuidString: clientId) != nil else {
            return "Configuration.clientId must be an application (client) ID in UUID format."
        }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        guard !tenantSubdomain.isEmpty,
              tenantSubdomain.rangeOfCharacter(from: allowed.inverted) == nil else {
            return "Configuration.tenantSubdomain must contain only letters, numbers, and hyphens."
        }
        return nil
    }

    static var protectedAPIConfiguration: ProtectedAPIConfiguration? {
        guard !protectedAPIEndpoint.isEmpty || !protectedAPIScopes.isEmpty else {
            return nil
        }
        return try? ProtectedAPIConfiguration(
            endpoint: protectedAPIEndpoint,
            scopes: protectedAPIScopes
        )
    }

    static var protectedAPIConfigurationError: String? {
        guard !protectedAPIEndpoint.isEmpty || !protectedAPIScopes.isEmpty else {
            return nil
        }
        do {
            _ = try ProtectedAPIConfiguration(endpoint: protectedAPIEndpoint, scopes: protectedAPIScopes)
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
