//
//  EGOEndpoint.swift
//  EGO
//
//  Describes each API call as a path + its endpoint-specific query items. The
//  shared `UID` and `LAN=tr` params are appended by `APIClient`, not here.
//

import Foundation

enum EGOEndpoint {
    /// Acquire (first run, no UID) or renew (with UID) the session UID.
    case connect
    case lines(query: String)
    case lineDetails(code: String)
    case stop(code: String)
    case searchStops(query: String)
    case busesAtStop(stopCode: String)
    /// `stopCode == nil` omits the `DURAK` param — valid for this endpoint.
    case busesByLine(lineCode: String, stopCode: String?)
    case cardBalance(card: String)
    case cardUsage(card: String)

    var path: String {
        switch self {
        case .connect:
            return "connect/androidConn.asp"
        case .lines, .lineDetails:
            return "act.asp"
        case .stop, .searchStops, .cardBalance, .cardUsage:
            return "action.asp"
        case .busesAtStop, .busesByLine:
            return "srv.asp"
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .connect:
            return [
                URLQueryItem(name: "FNC", value: "Connect"),
                URLQueryItem(name: "D", value: APIConfig.device),
                URLQueryItem(name: "VER", value: APIConfig.version),
                URLQueryItem(name: "T", value: "red"),
            ]
        case .lines(let query):
            return [
                URLQueryItem(name: "FNC", value: "Hatlar"),
                URLQueryItem(name: "QUERY", value: query),
            ]
        case .lineDetails(let code):
            return [
                URLQueryItem(name: "FNC", value: "HatBilgileri"),
                URLQueryItem(name: "YOL", value: "TRUE"),
                URLQueryItem(name: "KOD", value: code),
            ]
        case .stop(let code):
            return [
                URLQueryItem(name: "FNC", value: "Durak"),
                URLQueryItem(name: "KOD", value: code),
            ]
        case .searchStops(let query):
            return [
                URLQueryItem(name: "FNC", value: "Duraklar"),
                URLQueryItem(name: "QUERY", value: query),
            ]
        case .busesAtStop(let stopCode):
            return [
                URLQueryItem(name: "FNC", value: "Otobusler"),
                URLQueryItem(name: "DURAK", value: stopCode),
            ]
        case .busesByLine(let lineCode, let stopCode):
            var items = [
                URLQueryItem(name: "FNC", value: "Otobus"),
                URLQueryItem(name: "HAT", value: lineCode),
            ]
            if let stopCode {
                items.append(URLQueryItem(name: "DURAK", value: stopCode))
            }
            return items
        case .cardBalance(let card):
            return [
                URLQueryItem(name: "FNC", value: "AnkaraKartBakiye"),
                URLQueryItem(name: "KART", value: card),
            ]
        case .cardUsage(let card):
            return [
                URLQueryItem(name: "FNC", value: "AnkaraKartKullanim"),
                URLQueryItem(name: "KART", value: card),
            ]
        }
    }
}
