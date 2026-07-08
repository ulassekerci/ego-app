//
//  StopView.swift
//  EGO
//
//  Shows the lines serving one stop and their live arrivals. Fetches on appear,
//  refreshes on pull-down, and publishes the stop as the app-wide selected stop.
//

import SwiftUI

struct StopView: View {
    let stopCode: String

    @Environment(EGOService.self) private var service
    @Environment(Session.self) private var session
    @Environment(SelectedStopStore.self) private var selectedStop

    @State private var stop: Stop?
    @State private var arrivals: [BusArrival] = []
    @State private var errorMessage: String?
    @State private var isLoading = true

    var body: some View {
        content
            .navigationTitle(stop?.name ?? "Stop \(stopCode)")
            .navigationBarTitleDisplayMode(.inline)
            .task { await load() }
            .onAppear {
                if let stop { selectedStop.stop = stop }
            }
    }

    @ViewBuilder private var content: some View {
        if let errorMessage, stop == nil {
            ContentUnavailableView {
                Label("Couldn't Load Stop", systemImage: "wifi.exclamationmark")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Retry") {
                    Task { await load() }
                }
            }
        } else if isLoading, stop == nil {
            ProgressView()
        } else {
            List(arrivals) { arrival in
                BusArrivalRow(arrival: arrival)
            }
            .refreshable { await refresh() }
            .overlay {
                if arrivals.isEmpty {
                    ContentUnavailableView(
                        "No Lines",
                        systemImage: "bus",
                        description: Text("No lines are serving this stop right now.")
                    )
                }
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            // Recover if the launch-time connect failed; UID *expiry* mid-session
            // still surfaces as an error with no transparent retry.
            if session.uid == nil { try await session.connect() }
            async let stopInfo = service.stop(code: stopCode)
            async let buses = service.busesAtStop(stopCode)
            let (fetchedStop, fetchedArrivals) = try await (stopInfo, buses)
            stop = fetchedStop
            arrivals = fetchedArrivals.sortedForDisplay()
            selectedStop.stop = fetchedStop
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func refresh() async {
        do {
            arrivals = try await service.busesAtStop(stopCode).sortedForDisplay()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
