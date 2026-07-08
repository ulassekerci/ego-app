//
//  StopDTO.swift
//  EGO
//

import Foundation

/// A row from `Durak` / `Duraklar` / the `table_durak` of `HatBilgileri`.
struct StopDTO: Decodable {
    let id: String
    let kod: String        // 5-digit stop number (string)
    let ad: String         // stop name
    let konum: String?     // human-readable location
    let lat: String?
    let lng: String?
    let sira: String?      // order within a line — only present in line details
    let detay: String?
}
