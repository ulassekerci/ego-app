//
//  DebugView.swift
//  EGO
//
//  Developer screen (More tab) for poking the API directly: shows the session
//  UID (tap to copy) and fires raw requests, displaying the undecoded body so
//  DTO mismatches and empty-body rejections are visible in-app.
//

import SwiftUI
import UIKit

struct DebugView: View {
    @Environment(Session.self) private var session

    private let client = APIClient()

    @State private var statusLine: String?
    @State private var responseText: String?
    @State private var isLoading = false
    @State private var justCopied = false

    var body: some View {
        List {
            Section("Session UID") {
                Button {
                    UIPasteboard.general.string = session.uid
                    justCopied = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        justCopied = false
                    }
                } label: {
                    HStack {
                        Text(session.uid ?? "no UID — connect first")
                            .font(.footnote.monospaced())
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: justCopied ? "checkmark" : "doc.on.doc")
                            .foregroundStyle(justCopied ? .green : .secondary)
                    }
                }
                .disabled(session.uid == nil)
            }

            Section("Requests") {
                Button("Connect") {
                    send(.connect)
                }
                Button("Stop 12208") {
                    send(.busesAtStop(stopCode: "12208"))
                }
                Button("Create new UID") {
                    createNewUID()
                }
            }
            .disabled(isLoading)

            Section {
                if isLoading {
                    HStack {
                        ProgressView()
                        Text("Loading…").foregroundStyle(.secondary)
                    }
                } else if let responseText {
                    ScrollView(.horizontal) {
                        Text(responseText)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    Text("No response yet.").foregroundStyle(.secondary)
                }
            } header: {
                Text(statusLine ?? "Response")
            }
        }
        .navigationTitle("Debug")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func send(_ endpoint: EGOEndpoint) {
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                let (statusCode, body) = try await client.rawResponse(endpoint, uid: session.uid)
                statusLine = "HTTP \(statusCode) — \(body.count) bytes"
                responseText = body.isEmpty ? "<empty body>" : String(decoding: body, as: UTF8.self)
            } catch {
                statusLine = "Request failed"
                responseText = String(describing: error)
            }
        }
    }

    /// Drops the stored UID and connects without one so the server mints a fresh
    /// identity. Goes through `Session` (not `rawResponse`) so the new UID is
    /// stored and the UID row above updates.
    private func createNewUID() {
        isLoading = true
        Task {
            defer { isLoading = false }
            do {
                try await session.createNewUID()
                statusLine = "New UID created"
                responseText = session.uid ?? "<no UID in response>"
            } catch {
                statusLine = "Request failed"
                responseText = String(describing: error)
            }
        }
    }
}

#Preview {
    NavigationStack {
        DebugView()
    }
    .environment(Session())
}
