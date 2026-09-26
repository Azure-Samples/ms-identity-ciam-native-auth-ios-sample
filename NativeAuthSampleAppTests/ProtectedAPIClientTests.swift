//
// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.
//

import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import NativeAuthSampleSupport

final class ProtectedAPIClientTests: XCTestCase {
    func testConfigurationRequiresHTTPS() {
        XCTAssertThrowsError(
            try ProtectedAPIConfiguration(
                endpoint: "http://api.example.com/me",
                scopes: ["api://example/access"]
            )
        )
    }

    func testConfigurationRequiresScopes() {
        XCTAssertThrowsError(
            try ProtectedAPIConfiguration(
                endpoint: "https://api.example.com/me",
                scopes: []
            )
        )
    }

    func testRequestUsesBearerAuthorizationWithoutPuttingTokenInURL() throws {
        let endpoint = try XCTUnwrap(URL(string: "https://api.example.com/me"))
        let token = "test-access-token"

        let request = ProtectedAPIClient.request(endpoint: endpoint, accessToken: token)

        XCTAssertEqual(request.url, endpoint)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(
            request.value(forHTTPHeaderField: "Authorization"),
            ["Bearer", token].joined(separator: " ")
        )
        XCTAssertFalse(try XCTUnwrap(request.url?.absoluteString).contains(token))
    }

    func testResponseRejectsNonSuccessStatusWithoutReturningBody() throws {
        let url = try XCTUnwrap(URL(string: "https://api.example.com/me"))
        let response = try XCTUnwrap(
            HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)
        )

        XCTAssertThrowsError(
            try ProtectedAPIClient.responseBody(
                data: Data("sensitive response".utf8),
                response: response
            )
        ) { error in
            guard case ProtectedAPIError.httpStatus(401) = error else {
                return XCTFail("Expected an HTTP 401 error, got \(error)")
            }
        }
    }

    func testResponseReturnsSuccessfulUTF8Body() throws {
        let url = try XCTUnwrap(URL(string: "https://api.example.com/me"))
        let response = try XCTUnwrap(
            HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        )

        let body = try ProtectedAPIClient.responseBody(
            data: Data("{\"ok\":true}".utf8),
            response: response
        )

        XCTAssertEqual(body, "{\"ok\":true}")
    }
}
