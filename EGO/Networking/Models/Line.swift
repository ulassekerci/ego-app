//
//  Line.swift
//  EGO
//

import Foundation

enum LineType: Hashable {
    case bus, metro, ankaray, suburban

    /// Lines segmented control splits `bus` from everything rail.
    var isRail: Bool { self != .bus }

    /// Parsed from the API's `tur` field (e.g. "EGO, OTOBÜS", "BANLİYO, BANLİYO").
    init(tur: String) {
        if tur.contains("METRO") {
            self = .metro
        } else if tur.contains("ANKARAY") {
            self = .ankaray
        } else if tur.contains("BANLİYO") {
            self = .suburban
        } else {
            self = .bus
        }
    }
}

struct Line: Identifiable, Hashable {
    let id: String
    let code: String
    let name: String
    let type: LineType
    let durationMinutes: Int?
    let distanceKm: Int?
}
