//
//  Card.swift
//  EGO
//

import Foundation

struct CardBalance {
    let card: String
    let balance: Decimal?
    let lastUsed: Date?
    let subscriptionEnd: Date?
    let hasSubscription: Bool
}

struct CardTransaction: Identifiable {
    let id = UUID()
    let date: Date?
    let amount: Decimal?
    let remaining: Decimal?
    /// Rides left on the subscription; only set on subscription (ABO) rows.
    let subscriptionRemaining: Int?
    let line: String?
    let vehicleNo: String?
    let type: String?
    let description: String?
}
