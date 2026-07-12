//
//  LinesView.swift
//  EGO
//
//  Lines tab: all bus and rail lines behind a segmented control, filtered by a
//  search bar. The full list is fetched once and filtered locally; tapping a
//  line pushes its Line screen.
//

import SwiftUI

struct LinesView: View {
    @Environment(EGOService.self) private var service
    @Environment(Session.self) private var session

    @State private var lines: [Line] = []
    @State private var showRail = false
    @State private var searchText = ""
    @State private var errorMessage: String?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Line type", selection: $showRail) {
                    Text("Bus").tag(false)
                    Text("Rail").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 16)
                
                content
            }
            .navigationTitle("Lines")
            .searchable(text: $searchText, prompt: "Line number or name")
            .task { await load() }
        }
    }

    @ViewBuilder private var content: some View {
        if let errorMessage, lines.isEmpty, !isLoading {
            ContentUnavailableView {
                Label("Couldn't Load Lines", systemImage: "wifi.exclamationmark")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Retry") {
                    Task { await load() }
                }
            }
        } else if isLoading, lines.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(filteredLines) { line in
                NavigationLink {
                    LineView(lineCode: line.code)
                } label: {
                    LineRow(line: line)
                }
            }
            // Replaces the list's built-in ~30pt top inset (meant for a section
            // header) with a value that sits closer to the picker.
            .contentMargins(.top, 16, for: .scrollContent)
            .overlay {
                if filteredLines.isEmpty {
                    if searchText.isEmpty {
                        ContentUnavailableView(
                            "No Lines",
                            systemImage: showRail ? "tram" : "bus",
                            description: Text("No \(showRail ? "rail" : "bus") lines are available.")
                        )
                    } else {
                        ContentUnavailableView.search(text: searchText)
                    }
                }
            }
        }
    }

    private var filteredLines: [Line] {
        let segment = lines.filter { $0.type.isRail == showRail }
        guard !searchText.isEmpty else { return segment }
        return segment.filter {
            $0.code.localizedStandardContains(searchText)
                || $0.name.localizedStandardContains(searchText)
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            if session.uid == nil { try await session.connect() }
            lines = try await service.lines()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct LineRow: View {
    let line: Line

    var body: some View {
        HStack(spacing: 12) {
            Text(line.code)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(.white)
                .frame(width: 60, height: 40)
                .background(Color(.egoRed), in: .rect(cornerRadius: 8))

            Text(line.name)
                .font(.subheadline)
                .lineLimit(2)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    let session = Session()
    LinesView()
        .environment(session)
        .environment(EGOService(session: session))
        .environment(SelectedStopStore())
}
