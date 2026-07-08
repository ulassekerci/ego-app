//
//  BusDTO.swift
//  EGO
//
//  Dual-shaped: a live bus (arac_no is a real id) or a "next departure" placeholder
//  (arac_no == "-"). All shape-specific fields are optional. `doluluk` (occupancy) and
//  `trafik` (traffic) are intentionally omitted: `trafik` isn't needed and `doluluk`
//  hasn't implemented by EGO yet.
//

import Foundation

struct BusDTO: Decodable {
    let arac_no: String            // "-" ⇒ scheduled placeholder, else live bus id
    let hat_kod: String?           // line code (may be absent; fall back to hat_no)
    let hat_no: String?
    let hat_ad: String?            // line name
    let sure: String?              // live: "6 dk" / "T.V.Süresi"; scheduled: multiline text
    let detay: String?             // live: "Solo‚ Engelli" (‚ is U+201A, not a comma)
    let plaka_no: String?
    let lat: String?
    let lng: String?
    let saniye: String?            // remaining seconds; "999999" ⇒ not arriving here
    let durak_no: String?
    let onceki_durak_no: String?
}
