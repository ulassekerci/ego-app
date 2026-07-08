//
//  Placeholders.swift
//  EGO
//
//  Stub tabs — Lines, Card and More are specified in docs/app-design.md but not
//  built yet. Each stub gets replaced by a real screen in its own file.
//

import SwiftUI

struct LinesView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("Lines", systemImage: "bus", description: Text("Not implemented."))
                .navigationTitle("Lines")
        }
    }
}

struct CardView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("Card", systemImage: "creditcard", description: Text("Not implemented."))
                .navigationTitle("Card")
        }
    }
}

struct MoreView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("More", systemImage: "ellipsis.circle", description: Text("Not implemented."))
                .navigationTitle("More")
        }
    }
}
