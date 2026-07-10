//
//  Placeholders.swift
//  EGO
//
//  Stub tabs — More is intentionally near-empty per docs/app-design.md.
//

import SwiftUI

struct MoreView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    DebugView()
                } label: {
                    Label("Debug", systemImage: "ladybug")
                }
            }
            .navigationTitle("More")
        }
    }
}
