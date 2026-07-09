//
//  LineView.swift
//  EGO
//
//  One bus/rail line in four tabs: its stops (with total distance/duration),
//  scheduled departures by day type, live buses relative to the selected stop,
//  and a route map (placeholder for now).
//

import SwiftUI

enum LineTab: Hashable {
    case stops, departures, buses, route
}

struct LineView: View {
    let lineCode: String

    @Environment(EGOService.self) private var service
    @Environment(Session.self) private var session

    @State private var tab: LineTab
    @State private var detail: LineDetail?
    @State private var errorMessage: String?
    @State private var isLoading = true

    init(lineCode: String, initialTab: LineTab = .stops) {
        self.lineCode = lineCode
        _tab = State(initialValue: initialTab)
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $tab) {
                Text("Stops").tag(LineTab.stops)
                Text("Departures").tag(LineTab.departures)
                Text("Buses").tag(LineTab.buses)
                Text("Route").tag(LineTab.route)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 16)

            content
        }
        .navigationTitle(lineCode)
        .navigationBarTitleDisplayMode(.inline)
        .navigationSubtitle(detail?.line.name ?? "")
        .task { await loadDetails() }
    }

    @ViewBuilder private var content: some View {
        switch tab {
        case .stops, .departures:
            if let detail {
                if tab == .stops {
                    LineStopsTab(detail: detail)
                } else {
                    LineDeparturesTab(schedule: detail.schedule)
                }
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView {
                    Label("Couldn't Load Line", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(errorMessage ?? "Something went wrong.")
                } actions: {
                    Button("Retry") {
                        Task { await loadDetails() }
                    }
                }
            }
        case .buses:
            LineBusesTab(lineCode: lineCode)
        case .route:
            ContentUnavailableView(
                "Route",
                systemImage: "map",
                description: Text("The route map isn't implemented yet.")
            )
        }
    }

    private func loadDetails() async {
        isLoading = true
        errorMessage = nil
        do {
            // Recover if the launch-time connect failed; UID *expiry* mid-session
            // still surfaces as an error with no transparent retry.
            if session.uid == nil { try await session.connect() }
            detail = try await service.lineDetails(code: lineCode)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Stops

private struct LineStopsTab: View {
    let detail: LineDetail

    var body: some View {
        List {
            Section {
                HStack(spacing: 0) {
                    if let distance = detail.line.distanceKm {
                        Label("\(distance) km", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                            .frame(maxWidth: .infinity)
                    }
                    if let duration = detail.line.durationMinutes {
                        Label("\(duration) min", systemImage: "clock")
                            .frame(maxWidth: .infinity)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Section {
                ForEach(detail.stops) { stop in
                    NavigationLink {
                        StopView(stopCode: stop.code)
                    } label: {
                        HStack(spacing: 12) {
                            Text(stop.order.map(String.init) ?? "·")
                                .font(.footnote.weight(.semibold).monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(stop.name)
                                    .font(.subheadline)
                                if let location = stop.location {
                                    Text(location)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                    }
                }
            }
        }
        // Replaces the list's built-in ~30pt top inset (meant for a section
        // header) with the spacing used across the app's picker-topped lists.
        .contentMargins(.top, 16, for: .scrollContent)
    }
}

// MARK: - Departures

private struct LineDeparturesTab: View {
    let schedule: [DayType: [Departure]]

    @State private var day: DayType = .todayInIstanbul

    var body: some View {
        VStack(spacing: 0) {
            Picker("Day", selection: $day) {
                Text("Weekdays").tag(DayType.weekday)
                Text("Saturday").tag(DayType.saturday)
                Text("Sunday").tag(DayType.sunday)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 16)

            List {
                ForEach(hourGroups, id: \.hour) { group in
                    Section(group.hour.map { String(format: "%02d", $0) } ?? "Other") {
                        ForEach(Array(group.departures.enumerated()), id: \.offset) { _, departure in
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text(timeText(departure))
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                                if let detail = departure.detail {
                                    Text(detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .contentMargins(.top, 16, for: .scrollContent)
            .overlay {
                if hourGroups.isEmpty {
                    ContentUnavailableView(
                        "No Departures",
                        systemImage: "calendar.badge.exclamationmark",
                        description: Text("No departures are scheduled for this day.")
                    )
                }
            }
        }
    }

    /// The day's departures in one section per hour, unknown times last.
    private var hourGroups: [(hour: Int?, departures: [Departure])] {
        let sorted = (schedule[day] ?? []).sorted {
            ($0.hour ?? 99, $0.minute ?? 99) < ($1.hour ?? 99, $1.minute ?? 99)
        }
        var groups: [(hour: Int?, departures: [Departure])] = []
        for departure in sorted {
            if let last = groups.indices.last, groups[last].hour == departure.hour {
                groups[last].departures.append(departure)
            } else {
                groups.append((hour: departure.hour, departures: [departure]))
            }
        }
        return groups
    }

    private func timeText(_ departure: Departure) -> String {
        guard let hour = departure.hour, let minute = departure.minute else {
            return "—"
        }
        return String(format: "%02d:%02d", hour, minute)
    }
}

private extension DayType {
    /// Schedules follow Ankara's local day, not the device time zone.
    static var todayInIstanbul: DayType {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul") ?? .current
        switch calendar.component(.weekday, from: .now) {
        case 1: return .sunday
        case 7: return .saturday
        default: return .weekday
        }
    }
}

// MARK: - Buses

private struct LineBusesTab: View {
    let lineCode: String

    @Environment(EGOService.self) private var service
    @Environment(Session.self) private var session
    @Environment(SelectedStopStore.self) private var selectedStop

    @State private var arrivals: [BusArrival] = []
    @State private var errorMessage: String?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let errorMessage, arrivals.isEmpty, !isLoading {
                ContentUnavailableView {
                    Label("Couldn't Load Buses", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("Retry") {
                        Task { await load() }
                    }
                }
            } else if isLoading, arrivals.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section {
                        ForEach(arrivals) { arrival in
                            BusArrivalRow(arrival: arrival)
                        }
                    } header: {
                        if let stop = selectedStop.stop {
                            Text("Arrivals at \(stop.name)")
                        }
                    }
                }
                .refreshable { await load() }
                .contentMargins(.top, 16, for: .scrollContent)
                .overlay {
                    if arrivals.isEmpty {
                        ContentUnavailableView(
                            "No Buses",
                            systemImage: "bus",
                            description: Text("No buses are on this line right now.")
                        )
                    }
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        errorMessage = nil
        do {
            if session.uid == nil { try await session.connect() }
            arrivals = try await service.buses(line: lineCode, stop: selectedStop.stop?.code)
                .sortedForDisplay()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    let session = Session()
    NavigationStack {
        LineView(lineCode: "155-6")
    }
    .environment(session)
    .environment(EGOService(session: session))
    .environment(SelectedStopStore())
}
