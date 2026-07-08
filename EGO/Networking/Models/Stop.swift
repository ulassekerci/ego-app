//
//  Stop.swift
//  EGO
//

import CoreLocation

struct Stop: Identifiable {
    let id: String
    let code: String
    let name: String
    let location: String?
    let coordinate: CLLocationCoordinate2D?
    /// Order within a line, only set when the stop came from line details.
    let order: Int?
}

// CLLocationCoordinate2D isn't Equatable/Hashable, so identity is based on the
// stop's stable id (enables use as a NavigationStack value).
extension Stop: Hashable {
    static func == (lhs: Stop, rhs: Stop) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
