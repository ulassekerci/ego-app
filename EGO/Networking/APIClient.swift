//
//  APIClient.swift
//  EGO
//
//  Builds requests, sets the mandatory headers, decodes, and validates the API's
//  `status` field. Stateless and thread-safe — `URLSession` is safe to share.
//

import Foundation
import OSLog

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
    private static let logger = Logger(subsystem: "com.ulas.EGO", category: "APIClient")

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Sends `endpoint`, appending `UID` (when non-nil) and `LAN=tr`, then decodes
    /// `T` and checks the API status. `uid` is nil only for the first-run `connect`.
    func request<T: Decodable>(_ endpoint: EGOEndpoint, uid: String?) async throws -> T {
        let request = try makeRequest(endpoint, uid: uid)
        let urlString = request.url?.absoluteString ?? "<nil>"
        Self.logger.debug("→ \(urlString, privacy: .public)")

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            Self.logger.error("Non-HTTP response for \(urlString, privacy: .public)")
            throw APIError.invalidResponse
        }
        Self.logger.debug("← HTTP \(http.statusCode) \(data.count) bytes")
        guard (200..<300).contains(http.statusCode) else {
            Self.logger.error("HTTP \(http.statusCode) for \(urlString, privacy: .public) body: \(Self.bodyPreview(data), privacy: .public)")
            throw APIError.http(http.statusCode)
        }

        let decoded: T
        do {
            decoded = try JSONDecoder().decode(T.self, from: data)
        } catch {
            Self.logger.error("""
            Decoding \(String(describing: T.self), privacy: .public) failed for \(urlString, privacy: .public)
            error: \(String(describing: error), privacy: .public)
            body: \(Self.bodyPreview(data), privacy: .public)
            """)
            throw APIError.decoding(error)
        }

        if let egoResponse = decoded as? EGOResponse, egoResponse.status != "TRUE" {
            Self.logger.error("API status \(egoResponse.status, privacy: .public) for \(urlString, privacy: .public) message: \(egoResponse.message, privacy: .public)")
            throw APIError.apiStatus(message: egoResponse.message)
        }
        return decoded
    }

    /// Sends `endpoint` and returns the undecoded body — for the debug screen.
    func rawResponse(_ endpoint: EGOEndpoint, uid: String?) async throws -> (statusCode: Int, body: Data) {
        let request = try makeRequest(endpoint, uid: uid)
        Self.logger.debug("→ (raw) \(request.url?.absoluteString ?? "<nil>", privacy: .public)")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        return (http.statusCode, data)
    }

    /// First 2 KB of the body as text, for error logs. Marks empty bodies explicitly —
    /// the API returns HTTP 200 with 0 bytes when it rejects a request shape.
    private static func bodyPreview(_ data: Data) -> String {
        guard !data.isEmpty else { return "<empty body>" }
        let preview = String(decoding: data.prefix(2048), as: UTF8.self)
        return data.count > 2048 ? preview + "… (\(data.count) bytes total)" : preview
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
