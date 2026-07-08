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
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(minWidth: 54)
                .background(Color(.egoRed), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(arrival.lineName)
                    .font(.subheadline)
                    .lineLimit(2)
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
                Text(bus.plate ?? bus.vehicleNo)
                if bus.plate != nil {
                    Text(bus.vehicleNo)
                }
                Text(bus.isArticulated ? "Articulated" : "Solo")
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.quaternary, in: Capsule())
                if bus.isAccessible {
                    Image(systemName: "figure.roll")
                        .accessibilityLabel("Accessible")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
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
                Text("Departed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
            case .atStop: return 0
            case .arriving: return 1
            case .departing: return 2
            case .passed: return 3
            }
        case .scheduled: return 4
        }
    }
}

#Preview("Live and scheduled", traits: .sizeThatFitsLayout) {
    List {
        BusArrivalRow(arrival: .live(LiveBus(
            lineCode: "413", lineName: "Çayyolu - Kızılay", vehicleNo: "1234",
            plate: "06 ABC 123", coordinate: nil, progress: .arriving(seconds: 420),
            isArticulated: true, isAccessible: true, stopNo: nil, prevStopNo: nil
        )))
        BusArrivalRow(arrival: .live(LiveBus(
            lineCode: "155-6", lineName: "Atatürk Sitesi - Ulus", vehicleNo: "07-157",
            plate: "06 BG 3495", coordinate: nil, progress: .atStop,
            isArticulated: false, isAccessible: true, stopNo: nil, prevStopNo: nil
        )))
        BusArrivalRow(arrival: .live(LiveBus(
            lineCode: "413", lineName: "Çayyolu - Kızılay", vehicleNo: "5678",
            plate: nil, coordinate: nil, progress: .passed,
            isArticulated: false, isAccessible: false, stopNo: nil, prevStopNo: nil
        )))
        BusArrivalRow(arrival: .scheduled(NextDeparture(
            lineCode: "540", lineName: "Sincan - Ulus",
            nextDepartureText: "00:15 / 12 dk Sonra", minutesUntil: 12
        )))
    }
}
