//
//  BusArrivalRow.swift
//  EGO
//
//  One row per line at a stop: either a live bus (remaining time, plate, vehicle
//  no, solo/articulated) or the next scheduled departure. Shared between the Stop
//  screen and the buses tab of the Line screen.
//

import SwiftUI

struct BusArrivalRow: View {
    let arrival: BusArrival

    var body: some View {
        HStack(spacing: 12) {
            Text(arrival.lineCode)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(.white)
                .frame(width: 60, height: 48)
                .background(Color(.egoRed), in: .rect(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 6) {
                Text(arrival.lineName)
                    .font(.subheadline)
                    .lineLimit(3)
                subtitle
            }

            Spacer(minLength: 8)

            trailing
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder private var subtitle: some View {
        switch arrival {
        case .live(let bus):
            HStack(spacing: 6) {
                Text(bus.vehicleNo)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .overlay(Capsule().stroke(.black.opacity(0.2), lineWidth: 1)
                    )
                Text(bus.isArticulated ? "Articulated" : "Solo")
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .overlay(Capsule().stroke(.black.opacity(0.2), lineWidth: 1)
                    )
            }
            .font(.caption)
        case .scheduled(let departure):
            Text("Next departure: \(departure.nextDepartureText)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var trailing: some View {
        switch arrival {
        case .live(let bus):
            switch bus.progress {
            case .arriving(let seconds):
                VStack(spacing: 0) {
                    Text("\(max(1, Int((Double(seconds) / 60).rounded())))")
                        .font(.title3.weight(.bold).monospacedDigit())
                    Text("min")
                        .font(.caption2)
                }
                .foregroundStyle(Color(.egoRed))
            case .atStop:
                Text("At stop")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color(.egoRed))
            case .departing:
                Text("Departing")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color(.egoRed))
            case .passed:
                Text("Passed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .scheduled:
            EmptyView()
        }
    }
}

// Display order shared by every arrivals list: buses at the stop, then live buses
// by soonest arrival, then ones that just left, then ones long past the stop, then
// scheduled departures — keeping the API's order within groups without a countdown.
extension Array where Element == BusArrival {
    func sortedForDisplay() -> [BusArrival] {
        enumerated()
            .sorted { lhs, rhs in
                let lhsRank = lhs.element.displayRank
                let rhsRank = rhs.element.displayRank
                if lhsRank != rhsRank { return lhsRank < rhsRank }
                if case .live(let lhsBus) = lhs.element, case .live(let rhsBus) = rhs.element,
                   case .arriving(let lhsSeconds) = lhsBus.progress,
                   case .arriving(let rhsSeconds) = rhsBus.progress,
                   lhsSeconds != rhsSeconds {
                    return lhsSeconds < rhsSeconds
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }
}

private extension BusArrival {
    var displayRank: Int {
        switch self {
        case .live(let bus):
            switch bus.progress {
            case .departing: return 0
            case .atStop: return 1
            case .arriving: return 2
            case .passed: return 3
            }
        case .scheduled: return 4
        }
    }
}

#Preview("Live and scheduled", traits: .sizeThatFitsLayout) {
    List {
        BusArrivalRow(arrival: .live(LiveBus(
            lineCode: "203-7", lineName: "(ÖHO) İNCİRLİ-SOKULLU", vehicleNo: "37-026",
            plate: "06 ABC 123", coordinate: nil, heading: nil, progress: .departing,
            isArticulated: false, isAccessible: false, stopNo: nil, prevStopNo: nil
        )))
        BusArrivalRow(arrival: .live(LiveBus(
            lineCode: "154-2", lineName: "ULUS-SOKULLU", vehicleNo: "07-157",
            plate: "06 BG 3495", coordinate: nil, heading: nil, progress: .atStop,
            isArticulated: false, isAccessible: true, stopNo: nil, prevStopNo: nil
        )))
        BusArrivalRow(arrival: .live(LiveBus(
            lineCode: "183-2", lineName: "ULUS - İLKER SİNAN CD.", vehicleNo: "12-107",
            plate: nil, coordinate: nil, heading: nil, progress: .arriving(seconds: 296),
            isArticulated: true, isAccessible: true, stopNo: nil, prevStopNo: nil
        )))
        BusArrivalRow(arrival: .live(LiveBus(
            lineCode: "456", lineName: "ÖRNEK-ÇALIŞKANLAR-ULUS-KIZILAY", vehicleNo: "22-108",
            plate: nil, coordinate: nil, heading: nil, progress: .passed,
            isArticulated: false, isAccessible: true, stopNo: nil, prevStopNo: nil
        )))
        BusArrivalRow(arrival: .scheduled(NextDeparture(
            lineCode: "888-8", lineName: "Sincan - Ulus",
            nextDepartureText: "00:15", minutesUntil: 12
        )))
    }
}
