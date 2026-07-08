//
//  ContentView.swift
//  EGO
//
//  Created by ulassekerci on 08/07/2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") {
                HomeView()
            }
            Tab("Lines", systemImage: "bus") {
                LinesView()
            }
            Tab("Card", systemImage: "creditcard") {
                CardView()
            }
            Tab("More", systemImage: "ellipsis") {
                MoreView()
            }
        }
        .tint(Color(.egoRed))
    }
}

#Preview {
    let session = Session()
    ContentView()
        .environment(session)
        .environment(EGOService(session: session))
        .environment(SelectedStopStore())
}
