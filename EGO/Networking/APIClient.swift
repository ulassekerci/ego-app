//
//  APIClient.swift
//  EGO
//
//  Builds requests, sets the mandatory headers, decodes, and validates the API's
//  `status` field. Stateless and thread-safe — `URLSession` is safe to share.
//

import Foundation

/// Every top-level response carries these two fields; success is `status == "TRUE"`.
protocol EGOResponse {
    var status: String { get }
    var message: String { get }
}

/// Wrapper used by the 7 endpoints that return a single `table` array of rows.
struct TableResponse<Row: Decodable>: Decodable, EGOResponse {
    let table: [Row]
    let message: String
    let status: String
}

struct APIClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Sends `endpoint`, appending `UID` (when non-nil) and `LAN=tr`, then decodes
    /// `T` and checks the API status. `uid` is nil only for the first-run `connect`.
    func request<T: Decodable>(_ endpoint: EGOEndpoint, uid: String?) async throws -> T {
        let request = try makeRequest(endpoint, uid: uid)
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.http(http.statusCode)
        }

        let decoded: T
        do {
            decoded = try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }

        if let egoResponse = decoded as? EGOResponse, egoResponse.status != "TRUE" {
            throw APIError.apiStatus(message: egoResponse.message)
        }
        return decoded
    }

    private func makeRequest(_ endpoint: EGOEndpoint, uid: String?) throws -> URLRequest {
        let url = APIConfig.baseURL.appendingPathComponent(endpoint.path)
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidResponse
        }

        var items = endpoint.queryItems
        if let uid {
            items.append(URLQueryItem(name: "UID", value: uid))
        }
        items.append(URLQueryItem(name: "LAN", value: "tr"))
        components.queryItems = items

        guard let requestURL = components.url else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        // A valid Android user-agent is mandatory or the API returns nothing.
        request.setValue(APIConfig.userAgent, forHTTPHeaderField: "user-agent")
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "accept")
        request.setValue("keep-alive", forHTTPHeaderField: "connection")
        // Intentionally NOT setting accept-encoding: URLSession adds gzip and
        // gunzips transparently; setting it forces manual decompression.
        return request
    }
}
