//
//  LineDetail.swift
//  EGO
//

import CoreLocation

enum DayType: Hashable {
    case weekday, saturday, sunday

    /// Parsed from the schedule row's `tur` field.
    init?(tur: String) {
        switch tur {
        case "HAFTA İÇİ": self = .weekday
        case "CUMARTESİ": self = .saturday
        case "PAZAR": self = .sunday
        default: return nil
        }
    }
}

struct Departure {
    let hour: Int?
    let minute: Int?
    let detail: String?
}

struct LineDetail {
    let line: Line
    let stops: [Stop]
    let schedule: [DayType: [Departure]]
    let routeCoordinates: [CLLocationCoordinate2D]
}
