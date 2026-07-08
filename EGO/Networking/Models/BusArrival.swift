//
//  BusArrival.swift
//  EGO
//
//  A bus row is either a live bus or a scheduled "next departure" placeholder.
//

import CoreLocation

enum BusArrival: Identifiable {
    case live(LiveBus)
    case scheduled(NextDeparture)

    var id: String {
        switch self {
        case .live(let bus): return "live-\(bus.lineCode)-\(bus.vehicleNo)"
        case .scheduled(let departure): return "scheduled-\(departure.lineCode)"
        }
    }

    var lineCode: String {
        switch self {
        case .live(let bus): return bus.lineCode
        case .scheduled(let departure): return departure.lineCode
        }
    }

    var lineName: String {
        switch self {
        case .live(let bus): return bus.lineName
        case .scheduled(let departure): return departure.lineName
        }
    }
}

struct LiveBus {
    let lineCode: String
    let lineName: String
    let vehicleNo: String
    let plate: String?
    let coordinate: CLLocationCoordinate2D?
    /// Where the bus is relative to the selected stop.
    let progress: LiveBusProgress
    let isArticulated: Bool
    let isAccessible: Bool
    let stopNo: String?
    let prevStopNo: String?
}

/// A live bus's position relative to the selected stop.
enum LiveBusProgress: Equatable {
    /// En route; arrives in `seconds`.
    case arriving(seconds: Int)
    /// At the stop right now (`durum == "geldi"` / `sure == "Geldi"`).
    case atStop
    /// Just left the stop (`durum == "gidiyor"` / `sure == "Gidiyor"`).
    case departing
    /// Already past the stop (`saniye == "999999"` / `sure == "T.V.Süresi"`).
    case passed
}

struct NextDeparture {
    let lineCode: String
    let lineName: String
    /// Human-readable text after the newline, e.g. "00:01 / 1 dk Sonra".
    let nextDepartureText: String
    let minutesUntil: Int?
}
