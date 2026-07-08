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
    /// Time until arrival at the selected stop; nil when the bus is past it.
    let remainingSeconds: Int?
    let isArticulated: Bool
    let isAccessible: Bool
    let stopNo: String?
    let prevStopNo: String?
}

struct NextDeparture {
    let lineCode: String
    let lineName: String
    /// Human-readable text after the newline, e.g. "00:01 / 1 dk Sonra".
    let nextDepartureText: String
    let minutesUntil: Int?
}
