//
//  LineDTO.swift
//  EGO
//

import Foundation

/// A row from `Hatlar` / the `table` of `HatBilgileri`.
struct LineDTO: Decodable {
    let id: String
    let tur: String        // e.g. "EGO, OTOBÜS", "METRO, METRO"
    let kod: String        // line code, e.g. "155-6"
    let ad: String         // line name
    let sure: String       // duration minutes (string)
    let mesafe: String     // distance km (string)
    let detay: String?
}
