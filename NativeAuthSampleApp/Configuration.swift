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

    static let clientId = "595671e3-5863-4589-89c6-140cc451e969"
    static let tenantSubdomain = "nativeauthasampleapp"

    /// Global switch between the Native Auth V1 (per-step delegates) and V2
    /// (server-driven, unified delegate) SDK surfaces. Flip to `false` to use the
    /// deprecated V1 flows.
    static let useNativeAuthV2 = true

    /// ESTS test slice / data-center used to pin requests to a specific scale unit.
    /// Set to `nil` to route to production. The Native Auth request path sends this as the
    /// `dc` query parameter.
    ///
    static let testSliceDataCenter: String? = "nil"

    /// Slice configuration applied to every `MSALNativeAuthPublicClientApplicationConfig`.
    /// Returns `nil` when no test slice is configured.
    static var sliceConfig: MSALSliceConfig? {
        guard let dc = testSliceDataCenter else { return nil }
        return MSALSliceConfig(slice: nil, dc: dc)
    }
}
