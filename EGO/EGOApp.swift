//
//  EGOApp.swift
//  EGO
//
//  Created by ulassekerci on 08/07/2026.
//

import SwiftUI

@main
struct EGOApp: App {
    @State private var session: Session
    @State private var service: EGOService
    @State private var selectedStop = SelectedStopStore()
    @State private var cardStore = CardStore()

    init() {
        let session = Session()
        _session = State(initialValue: session)
        _service = State(initialValue: EGOService(session: session))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(session)
                .environment(service)
                .environment(selectedStop)
                .environment(cardStore)
                .task {
                    // Acquire (first run) or renew the UID on launch.
                    try? await session.connect()
                }
        }
    }
}
