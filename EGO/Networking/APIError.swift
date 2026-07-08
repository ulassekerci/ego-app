//
//  APIError.swift
//  EGO
//

import Foundation

enum APIError: Error, LocalizedError {
    /// The response was not an `HTTPURLResponse`, a URL couldn't be built, or a
    /// `table`-shaped response we expected to have at least one row was empty.
    case invalidResponse
    /// Non-2xx HTTP status.
    case http(Int)
    /// The body decoded but `status != "TRUE"`; carries the API's `message`.
    case apiStatus(message: String)
    /// JSON decoding failed.
    case decoding(Error)
    /// A call requiring a UID was made before `Session.connect()` succeeded.
    case notConnected

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server returned an unexpected response."
        case .http(let code):
            return "Request failed with HTTP status \(code)."
        case .apiStatus(let message):
            return message.isEmpty ? "The request was rejected by the server." : message
        case .decoding:
            return "The server response could not be read."
        case .notConnected:
            return "Not connected. The session UID is missing or expired."
        }
    }
}
