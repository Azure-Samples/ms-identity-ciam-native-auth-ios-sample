//
// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct ProtectedAPIConfiguration {
    let endpoint: URL
    let scopes: [String]

    init(endpoint: String, scopes: [String]) throws {
        guard let url = URL(string: endpoint),
              url.scheme?.lowercased() == "https",
              url.host != nil else {
            throw ProtectedAPIError.invalidEndpoint
        }
        guard !scopes.isEmpty, scopes.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw ProtectedAPIError.invalidScopes
        }
        self.endpoint = url
        self.scopes = scopes
    }
}

enum ProtectedAPIError: LocalizedError {
    case invalidEndpoint
    case invalidScopes
    case invalidResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "Protected API endpoint must be a valid HTTPS URL."
        case .invalidScopes:
            return "Configure at least one non-empty protected API scope."
        case .invalidResponse:
            return "The protected API did not return an HTTP response."
        case .httpStatus(let statusCode):
            return "The protected API returned HTTP \(statusCode)."
        }
    }
}

final class ProtectedAPIClient: NSObject, URLSessionTaskDelegate {
    static func request(endpoint: URL, accessToken: String) -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue(["Bearer", accessToken].joined(separator: " "), forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    static func responseBody(data: Data, response: URLResponse) throws -> String {
        guard let response = response as? HTTPURLResponse else {
            throw ProtectedAPIError.invalidResponse
        }
        guard (200...299).contains(response.statusCode) else {
            throw ProtectedAPIError.httpStatus(response.statusCode)
        }
        return String(data: data, encoding: .utf8) ?? "<non-text response>"
    }

    func get(endpoint: URL, accessToken: String) async throws -> String {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        let (data, response) = try await session.data(for: Self.request(endpoint: endpoint, accessToken: accessToken))
        return try Self.responseBody(data: data, response: response)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
