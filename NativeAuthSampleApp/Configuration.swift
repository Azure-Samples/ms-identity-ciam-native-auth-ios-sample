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
    // Update the below to your client ID and tenantSubdomain you received in the portal.

    static let clientId = "c08b63a7-3415-431e-84ad-85a8a7d6cc0e"
    static let tenantSubdomain = "spasamples"
    static let tenantId = "1eb974cd-0dc5-40a6-9f68-94b19f5535c5"

    //static let clientId = "f8e00965-c38b-4710-ba45-efae62eeb6f9"
    //static let tenantSubdomain = "MSIDLABCIAM6"
    //static let tenantId = "fe362aec-5d43-45d1-b730-9755e60dc3b9"

    /// ESTS test slice / data-center used to pin requests to a specific scale unit.
    /// Set to `nil` to route to production. The Native Auth request path sends this as the
    /// `dc` query parameter.
    ///
     //  static let testSliceDataCenter: String? = "ESTS-PUB-WEULR1-AZ2-FD130-001"
    // static let testSliceDataCenter: String? = "ESTS-PUB-SEASLR1-FD000-TEST1-100"

    static let testSliceDataCenter: String? = "ESTS-PUB-SEASLR1-FD000-TEST1-100"
    static let testSlice: String? = "test1"


    /// Errors thrown while building values from the sample app configuration.
    enum ConfigurationError: Error {
        case invalidAuthorityUrl
    }

    /// Builds the CIAM (External ID) authority from `tenantSubdomain`, using the
    /// `https://<tenantSubdomain>.ciamlogin.com` endpoint expected by Native Auth.
    /// Throws `ConfigurationError.invalidAuthorityUrl` if the URL cannot be formed.
    static func ciamAuthority() throws -> MSALCIAMAuthority {
        guard let authorityUrl = URL(string: "https://\(tenantSubdomain).ciamlogin.com/\(tenantId)") else {
            throw ConfigurationError.invalidAuthorityUrl
        }
        return try MSALCIAMAuthority(url: authorityUrl)
    }


    /// Slice configuration applied to every `MSALNativeAuthPublicClientApplicationConfig`.
    /// Returns `nil` when no test slice is configured.
    static var sliceConfig: MSALSliceConfig? {
        guard let dc = testSliceDataCenter, let slice = testSlice else { return nil }
        return MSALSliceConfig(slice: slice, dc: dc)
    }
}
