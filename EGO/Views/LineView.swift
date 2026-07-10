//
//  LineView.swift
//  EGO
//
//  One bus/rail line in four tabs: its stops (with total distance/duration),
//  scheduled departures by day type, live buses relative to the selected stop,
//  and the route on a map.
//

import MapKit
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
    /// Set when a bus row in the Buses tab is tapped; the Route tab consumes it
    /// and opens zoomed in on that bus.
    @State private var focusedBus: LiveBus?

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
        case .buses:
            LineBusesTab(lineCode: lineCode) { bus in
                focusedBus = bus
                tab = .route
            }
        case .stops, .departures, .route:
            if let detail {
                switch tab {
                case .stops: LineStopsTab(detail: detail)
                case .departures: LineDeparturesTab(schedule: detail.schedule)
                default: LineRouteTab(detail: detail, focusedBus: $focusedBus)
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
    /// Called with a tapped live bus so the parent can show it on the route map.
    let showOnMap: (LiveBus) -> Void

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
                            // Live buses with a position open the route map zoomed
                            // in on them; the rest stay plain rows.
                            if case .live(let bus) = arrival, bus.coordinate != nil {
                                Button {
                                    showOnMap(bus)
                                } label: {
                                    BusArrivalRow(arrival: arrival)
                                        .contentShape(.rect)
                                }
                                .buttonStyle(.plain)
                            } else {
                                BusArrivalRow(arrival: arrival)
                            }
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

// MARK: - Route

private struct LineRouteTab: View {
    let detail: LineDetail
    @Binding var focusedBus: LiveBus?

    @Environment(EGOService.self) private var service
    @Environment(Session.self) private var session

    @State private var buses: [LiveBus] = []
    @State private var busError: String?
    @State private var isLoadingBuses = false
    @State private var selectedBusID: String?
    @State private var position: MapCameraPosition = .automatic

    init(detail: LineDetail, focusedBus: Binding<LiveBus?>) {
        self.detail = detail
        _focusedBus = focusedBus
        // Arriving from a bus row: open zoomed in on that bus, pre-selected so
        // its detail card shows once the live positions load.
        if let bus = focusedBus.wrappedValue, let coordinate = bus.coordinate {
            _position = State(initialValue: .camera(MapCamera(centerCoordinate: coordinate, distance: 4000)))
            _selectedBusID = State(initialValue: bus.vehicleNo)
        }
    }

    var body: some View {
        if detail.routeCoordinates.isEmpty, detail.stops.isEmpty {
            ContentUnavailableView(
                "No Route",
                systemImage: "map",
                description: Text("EGO doesn't provide route geometry for this line.")
            )
        } else {
            // The default camera position (.automatic) frames the map content.
            // Pan/zoom only: locked north-up and 2D, which also keeps the bus
            // heading wedges accurate (they rotate relative to screen-north).
            Map(position: $position, interactionModes: [.pan, .zoom], selection: $selectedBusID) {
                if !detail.routeCoordinates.isEmpty {
                    MapPolyline(coordinates: detail.routeCoordinates)
                        .stroke(Color(.egoRed), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                }
                ForEach(detail.stops) { stop in
                    if let coordinate = stop.coordinate {
                        // Collision handling hides the crowded titles until
                        // the user zooms in; the circles always stay visible.
                        Annotation(stop.name, coordinate: coordinate) {
                            Text(stop.order.map(String.init) ?? "·")
                                .font(.caption2.weight(.bold).monospacedDigit())
                                // 3-digit orders (100+ stop lines) shrink to fit
                                // instead of overflowing the circle.
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .padding(.horizontal, 3)
                                .foregroundStyle(Color(.egoRed))
                                .frame(width: 22, height: 22)
                                .background(.white, in: .circle)
                                .overlay(Circle().stroke(Color(.egoRed), lineWidth: 2))
                        }
                    }
                }
                // Annotations stack by latitude (no z-priority in SwiftUI MapKit),
                // so a bus north of a stop draws behind its circle. The bus chips
                // are larger than the circles and blue, so they stay identifiable
                // even when partially covered.
                ForEach(buses, id: \.vehicleNo) { bus in
                    if let coordinate = bus.coordinate {
                        Annotation(bus.vehicleNo, coordinate: coordinate) {
                            BusMarker(bus: bus, isSelected: bus.vehicleNo == selectedBusID)
                        }
                        .tag(bus.vehicleNo)
                    }
                }
            }
            .mapStyle(.standard(pointsOfInterest: .excludingAll))
            .task {
                // One-shot: leaving and reopening the tab frames the whole route.
                focusedBus = nil
                await loadBuses()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if isLoadingBuses {
                        ProgressView()
                    } else {
                        Button("Refresh Buses", systemImage: "arrow.clockwise") {
                            Task { await loadBuses() }
                        }
                    }
                }
            }
            .overlay(alignment: .bottom) {
                VStack(spacing: 8) {
                    if let busError {
                        Label(busError, systemImage: "wifi.exclamationmark")
                            .font(.footnote)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.thinMaterial, in: .capsule)
                    }
                    if let bus = buses.first(where: { $0.vehicleNo == selectedBusID }) {
                        BusDetailCard(bus: bus) { selectedBusID = nil }
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }

    /// Bus positions are a live overlay on the static route: a failure keeps the
    /// map usable and just surfaces the banner.
    private func loadBuses() async {
        isLoadingBuses = true
        busError = nil
        do {
            if session.uid == nil { try await session.connect() }
            // No DURAK: arrival times don't matter here, only positions.
            buses = try await service.buses(line: detail.line.code, stop: nil).compactMap {
                if case .live(let bus) = $0 { return bus }
                return nil
            }
        } catch {
            busError = error.localizedDescription
        }
        isLoadingBuses = false
    }
}

/// A bus on the map: red circle with a bus glyph, plus a pointer wedge orbiting
/// the circle to show the direction of travel. The wedge (not the glyph) rotates
/// so the icon stays upright.
private struct BusMarker: View {
    let bus: LiveBus
    let isSelected: Bool

    var body: some View {
        ZStack {
            if let heading = bus.heading {
                // offset then rotate: the rotation anchor stays at the circle's
                // center, so the wedge orbits it and points outward.
                PointerWedge()
                    .fill(.blue)
                    .frame(width: 14, height: 9)
                    .offset(y: -26)
                    .rotationEffect(.degrees(heading))
            }
            Image(systemName: "bus")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(.blue, in: .circle)
                .overlay(Circle().stroke(.white, lineWidth: 2))
        }
        .scaleEffect(isSelected ? 1.2 : 1)
        .animation(.snappy, value: isSelected)
    }
}

/// Upward-pointing triangle; rotated by the bus heading.
private struct PointerWedge: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

/// Details for the selected bus, floating over the bottom of the map.
private struct BusDetailCard: View {
    let bus: LiveBus
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Bus \(bus.vehicleNo)")
                    .font(.headline)
                if let plate = bus.plate {
                    Text(plate)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    Label(bus.isArticulated ? "Articulated" : "Solo", systemImage: "bus")
                    if bus.isAccessible {
                        Label("Accessible", systemImage: "figure.roll")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
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
