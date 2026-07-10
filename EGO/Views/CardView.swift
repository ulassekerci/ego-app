//
//  CardView.swift
//  EGO
//
//  Card tab: shows the main card's balance and subscription end date, offers
//  past usage (sheet) and top-up (opens the official payment page in Safari),
//  and manages the user's saved cards (add, switch main, delete).
//

import SwiftUI

struct CardView: View {
    @Environment(EGOService.self) private var service
    @Environment(Session.self) private var session
    @Environment(CardStore.self) private var store

    @State private var balance: CardBalance?
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showingAddCard = false
    @State private var usageCard: UserCard?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Card")
                .sheet(isPresented: $showingAddCard) { AddCardSheet() }
                .sheet(item: $usageCard) { card in CardUsageSheet(card: card) }
                .task(id: store.mainCard?.id) { await load() }
        }
    }

    @ViewBuilder private var content: some View {
        if let card = store.mainCard {
            List {
                Section {
                    CardFace(card: card)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section {
                    LabeledContent("Balance") {
                        if let amount = balance?.balance {
                            Text(amount, format: .currency(code: "TRY"))
                        } else if isLoading {
                            ProgressView()
                        } else {
                            Text("—")
                        }
                    }
                    if let lastUsed = balance?.lastUsed {
                        LabeledContent("Last used", value: lastUsed, format: .dateTime.day().month().hour().minute())
                    }
                    if let balance, balance.hasSubscription, let end = balance.subscriptionEnd {
                        LabeledContent("Subscription until", value: end, format: .dateTime.day().month().year())
                    }
                    if let errorMessage {
                        Label(errorMessage, systemImage: "wifi.exclamationmark")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button("Past Usage", systemImage: "clock.arrow.circlepath") {
                        usageCard = card
                    }
                    Link(destination: topUpURL(for: card)) {
                        Label("Top Up", systemImage: "creditcard")
                    }
                }
                .foregroundStyle(Color(.egoRed))

                Section("My Cards") {
                    ForEach(store.cards) { candidate in
                        Button {
                            store.setMain(candidate)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(candidate.name)
                                    Text(candidate.displayNumber)
                                        .font(.footnote.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if candidate.id == card.id {
                                    Image(systemName: "checkmark")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(Color(.egoRed))
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                    .onDelete { offsets in
                        for card in offsets.map({ store.cards[$0] }) {
                            store.remove(card)
                        }
                    }

                    Button("Add Card", systemImage: "plus") {
                        showingAddCard = true
                    }
                    .foregroundStyle(Color(.egoRed))
                }
            }
            .refreshable { await load() }
        } else {
            ContentUnavailableView {
                Label("No Cards", systemImage: "creditcard")
            } description: {
                Text("Add your EGO card to see its balance and usage history.")
            } actions: {
                Button("Add Card") { showingAddCard = true }
            }
        }
    }

    /// Official payment page; `kartno` pre-fills the card number field.
    private func topUpURL(for card: UserCard) -> URL {
        URL(string: "https://baskentulasim.com/guest-payment?kartno=\(card.number)")!
    }

    private func load() async {
        guard let card = store.mainCard else {
            balance = nil
            return
        }
        // Drop the previous card's numbers when the main card changes.
        if balance?.card != card.number { balance = nil }
        isLoading = true
        errorMessage = nil
        do {
            // Recover if the launch-time connect failed; UID *expiry* mid-session
            // still surfaces as an error with no transparent retry.
            if session.uid == nil { try await session.connect() }
            balance = try await service.cardBalance(card.number)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Card face

/// The card rendered at physical-card proportions: white-on-red per the brand
/// rules, number grouped in 4s like the printed card.
private struct CardFace: View {
    let card: UserCard

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .top) {
                Image(.logoWhite)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 40)
                Spacer()
                Text(card.name)
                    .font(.headline)
            }
            Spacer()
            Text(card.displayNumber)
                .font(.system(.title3, design: .monospaced).weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(24)
        .background(Color(.egoRed), in: .rect(cornerRadius: 16))
        .aspectRatio(1.586, contentMode: .fit)
    }
}

// MARK: - Add card

private struct AddCardSheet: View {
    @Environment(CardStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var number = ""

    private var digits: String { number.filter(\.isNumber) }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Card Name", text: $name)
                    TextField("0000 0000 0000 0000", text: $number)
                        .keyboardType(.numberPad)
                        .font(.body.monospaced())
                        .onChange(of: number) { _, newValue in
                            let grouped = UserCard.grouped(String(newValue.filter(\.isNumber).prefix(16)))
                            if grouped != newValue { number = grouped }
                        }
                } footer: {
                    Text("The 16-digit number on the front of the card.")
                }
            }
            .navigationTitle("Add Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        store.add(name: trimmedName, number: digits)
                        dismiss()
                    }
                    .disabled(digits.count != 16 || trimmedName.isEmpty)
                }
            }
        }
    }
}

// MARK: - Past usage

private struct CardUsageSheet: View {
    let card: UserCard

    @Environment(EGOService.self) private var service
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var transactions: [CardTransaction] = []
    @State private var errorMessage: String?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Past Usage")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
                .task { await load() }
        }
    }

    @ViewBuilder private var content: some View {
        if let errorMessage {
            ContentUnavailableView {
                Label("Couldn't Load Usage", systemImage: "wifi.exclamationmark")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("Retry") {
                    Task { await load() }
                }
            }
        } else if isLoading {
            ProgressView()
        } else {
            List(transactions) { transaction in
                TransactionRow(transaction: transaction)
            }
            .overlay {
                if transactions.isEmpty {
                    ContentUnavailableView(
                        "No Usage",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("This card has no recent transactions.")
                    )
                }
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            if session.uid == nil { try await session.connect() }
            transactions = try await service.cardUsage(card.number)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct TransactionRow: View {
    let transaction: CardTransaction

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let rides = transaction.subscriptionRemaining {
                    Text(rides, format: .number)
                    Text("rides left")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    if let amount = transaction.amount, amount > 0 {
                        Text(-amount, format: .currency(code: "TRY"))
                    }
                    if let remaining = transaction.remaining, remaining > 0 {
                        Text(remaining, format: .currency(code: "TRY"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    /// Transaction types arrive in Turkish all-caps ("NORMAL BİNİŞ"); recase
    /// with the Turkish locale so dotted/dotless İ-i survive.
    private var title: String {
        let type = transaction.type ?? transaction.description ?? "Transaction"
        return type.capitalized(with: Locale(identifier: "tr_TR"))
    }

    /// `hat` is "<line code>, <vehicle no>" — only the line code matters here;
    /// the vehicle comes from its own field.
    private var subtitle: String {
        var parts: [String] = []
        if let line = transaction.line?.split(separator: ",").first, !line.isEmpty {
            parts.append("Line \(line.trimmingCharacters(in: .whitespaces))")
        }
        if let vehicle = transaction.vehicleNo, !vehicle.isEmpty {
            parts.append(Self.vehicleDisplay(vehicle))
        }
        if let date = transaction.date {
            parts.append(date.formatted(.dateTime.day().month().hour().minute()))
        }
        return parts.joined(separator: " · ")
    }

    /// 5-digit fleet numbers are written "22-171" on the vehicle itself;
    /// anything else (e.g. metro turnstile) is shown as-is.
    static func vehicleDisplay(_ raw: String) -> String {
        guard raw.count == 5, raw.allSatisfy(\.isNumber) else { return raw }
        return "\(raw.prefix(2))-\(raw.dropFirst(2))"
    }
}

// MARK: - Previews

/// Isolated, cleared defaults suite so preview cards never leak into the app's
/// real UserDefaults (which back the actual CardStore) or between renders.
@MainActor
private func previewCardStore(seeded: Bool) -> CardStore {
    let suiteName = "CardViewPreview"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    let store = CardStore(defaults: defaults)
    if seeded { store.add(name: "My Card", number: "5028500600000000") }
    return store
}

#Preview {
    let session = Session()
    CardView()
        .environment(session)
        .environment(EGOService(session: session))
        .environment(previewCardStore(seeded: true))
}

#Preview("No Cards") {
    let session = Session()
    CardView()
        .environment(session)
        .environment(EGOService(session: session))
        .environment(previewCardStore(seeded: false))
}

#Preview("Transactions", traits: .sizeThatFitsLayout) {
    List {
        TransactionRow(transaction: CardTransaction(
            date: .now, amount: 17.5, remaining: 798.96, subscriptionRemaining: nil,
            line: "451, 10412", vehicleNo: "10412", type: "NORMAL BİNİŞ", description: "NORMAL BİNİŞ"
        ))
        TransactionRow(transaction: CardTransaction(
            date: .now, amount: 0, remaining: 0, subscriptionRemaining: 413,
            line: "155-2, 22171", vehicleNo: "22171", type: "ABONMAN BİNİŞ", description: "Abonman Biniş, Kalan:413"
        ))
        TransactionRow(transaction: CardTransaction(
            date: .now, amount: 10, remaining: 788.96, subscriptionRemaining: nil,
            line: "901, 2198", vehicleNo: "2198", type: "AKTARMA", description: "AKTARMA"
        ))
    }
}
