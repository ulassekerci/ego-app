//
//  Session.swift
//  EGO
//
//  Owns the UID lifecycle. The API has no real auth but every request needs a UID
//  with a finite lifetime, renewed by re-hitting `connect` on each launch.
//

import Foundation

@MainActor
@Observable
final class Session {
    private let client: APIClient
    private let defaultsKey = "ego.uid"

    /// The current UID, persisted across relaunches (still renewed each launch).
    private(set) var uid: String?

    init(client: APIClient? = nil) {
        self.client = client ?? APIClient()
        self.uid = UserDefaults.standard.string(forKey: defaultsKey)
    }

    /// The UID for authenticated calls, throwing if `connect()` hasn't succeeded.
    var currentUID: String {
        get throws {
            guard let uid else { throw APIError.notConnected }
            return uid
        }
    }

    /// Acquires a UID on first run (sends no UID so the server mints one) or renews
    /// the stored one. Call from the root view's `.task` on launch.
    func connect() async throws {
        let response: ConnectResponse = try await client.request(.connect, uid: uid)
        uid = response.userID
        UserDefaults.standard.set(response.userID, forKey: defaultsKey)
    }
}
