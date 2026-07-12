//
//  Decoding.swift
//  EGO
//
//  Parsing helpers shared by DTO→Model mapping. The API returns every number and
//  date as a string; numbers use `.` decimals and dates are Istanbul-local.
//

import Foundation

enum EGOParse {
    static let posix = Locale(identifier: "en_US_POSIX")

    /// `Int(_:)` / `Double(_:)` are locale-independent (always `.` decimals), which
    /// matches the API's number formatting.
    static func int(_ string: String?) -> Int? {
        guard let string, !string.isEmpty else { return nil }
        return Int(string)
    }

    static func double(_ string: String?) -> Double? {
        guard let string, !string.isEmpty else { return nil }
        return Double(string)
    }

    static func decimal(_ string: String?) -> Decimal? {
        guard let string, !string.isEmpty else { return nil }
        return Decimal(string: string, locale: posix)
    }

    /// The API's fixed `dd.MM.yyyy HH:mm:ss`, 24-hour and Istanbul-local. A value
    /// type, unlike the legacy `DateFormatter`.
    private static let dateStrategy = Date.ParseStrategy(
        format: "\(day: .twoDigits).\(month: .twoDigits).\(year: .defaultDigits) \(hour: .twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)):\(minute: .twoDigits):\(second: .twoDigits)",
        locale: posix,
        timeZone: TimeZone(identifier: "Europe/Istanbul") ?? .current
    )

    static func date(_ string: String?) -> Date? {
        guard let string else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return try? Date(trimmed, strategy: dateStrategy)
    }
}
