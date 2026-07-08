//
//  ConnectDTO.swift
//  EGO
//

import Foundation

/// Flat response from `connect/androidConn.asp` — the only non-`table` shape.
struct ConnectResponse: Decodable, EGOResponse {
    let userID: String
    let version: String?
    let message: String
    let status: String
}
