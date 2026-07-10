//
//  CardStore.swift
//  EGO
//
//  The user's saved EGO cards, persisted in UserDefaults per the app spec.
//  A card is just a 16-digit number plus a user-given name; exactly one card
//  is the "main" card shown on the Card tab.
//

import Foundation

struct UserCard: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    /// 16 digits, no separators.
    var number: String

    /// The number in groups of 4, as printed on the physical card.
    var displayNumber: String { Self.grouped(number) }

    /// Splits a digit string into groups of 4 ("5028500600000000" → "5028 5006 0000 0000").
    static func grouped(_ digits: String) -> String {
        String(digits.enumerated().flatMap { index, digit in
            index > 0 && index.isMultiple(of: 4) ? [" ", digit] : [digit]
        })
    }
}

@MainActor
@Observable
final class CardStore {
    private static let cardsKey = "userCards"
    private static let mainCardKey = "mainCardID"

    private let defaults: UserDefaults

    private(set) var cards: [UserCard] {
        didSet { persist() }
    }

    private(set) var mainCardID: UUID? {
        didSet { persist() }
    }

    var mainCard: UserCard? {
        cards.first { $0.id == mainCardID } ?? cards.first
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.cardsKey),
           let saved = try? JSONDecoder().decode([UserCard].self, from: data) {
            cards = saved
        } else {
            cards = []
        }
        mainCardID = defaults.string(forKey: Self.mainCardKey).flatMap(UUID.init)
    }

    func add(name: String, number: String) {
        let card = UserCard(name: name, number: number)
        cards.append(card)
        if cards.count == 1 { mainCardID = card.id }
    }

    func remove(_ card: UserCard) {
        cards.removeAll { $0.id == card.id }
        if mainCardID == card.id { mainCardID = cards.first?.id }
    }

    func setMain(_ card: UserCard) {
        mainCardID = card.id
    }

    private func persist() {
        defaults.set(try? JSONEncoder().encode(cards), forKey: Self.cardsKey)
        defaults.set(mainCardID?.uuidString, forKey: Self.mainCardKey)
    }
}
