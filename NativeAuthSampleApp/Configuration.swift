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

//    static let clientId = "595671e3-5863-4589-89c6-140cc451e969"
//    static let clientId = "456cf138-cb77-48e6-8a82-74f869d77e74" //MSIDLABCIAM6
//    static let clientId = "27922004-5251-4030-b22d-91ecd9a37ea4"
//    static let clientId = "7dfc59db-51f2-4979-a134-761ca6cecd9e"  // Andy
//    static let clientId = "18eb7a6e-61ba-48bb-bc50-4f971ec352bf" // Sergei
//    static let clientId = "430146fc-27b5-4c63-a677-2e5f2fa9aa00" // Silviu tenant
    static let clientId = "b91b095d-1892-43ff-88e0-b07efff0ec89" // Silviu tenant -- OTP
    
    
//    static let tenantSubdomain = "MSIDLABCIAM6"
//    static let tenantSubdomain = "andyexternalid"
//    static let tenantSubdomain = "sergeicustomers"
//    static let tenantSubdomain = "spasamples"
    static let tenantSubdomain = "spasamples"
}
