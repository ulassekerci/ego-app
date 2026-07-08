//
//  EGOService.swift
//  EGO
//
//  Typed async API surface for the app. Each method reads the session UID, calls
//  the client, and maps the raw DTOs into clean domain models. Views only ever see
//  the models — never DTOs or Turkish field names.
//

import CoreLocation
import Foundation

@MainActor
@Observable
final class EGOService {
    private let client: APIClient
    private let session: Session

    init(session: Session, client: APIClient? = nil) {
        self.session = session
        self.client = client ?? APIClient()
    }

    // MARK: - Lines

    func lines(query: String = "") async throws -> [Line] {
        let uid = try session.currentUID
        let response: TableResponse<LineDTO> = try await client.request(.lines(query: query), uid: uid)
        return response.table.map(Self.mapLine)
    }

    func lineDetails(code: String) async throws -> LineDetail {
        let uid = try session.currentUID
        let response: LineDetailResponse = try await client.request(.lineDetails(code: code), uid: uid)
        return try Self.mapLineDetail(response)
    }

    // MARK: - Stops

    func stop(code: String) async throws -> Stop {
        let uid = try session.currentUID
        let response: TableResponse<StopDTO> = try await client.request(.stop(code: code), uid: uid)
        guard let dto = response.table.first else { throw APIError.invalidResponse }
        return Self.mapStop(dto)
    }

    func searchStops(_ query: String) async throws -> [Stop] {
        let uid = try session.currentUID
        let response: TableResponse<StopDTO> = try await client.request(.searchStops(query: query), uid: uid)
        return response.table.map(Self.mapStop)
    }

    // MARK: - Buses

    func busesAtStop(_ stopCode: String) async throws -> [BusArrival] {
        let uid = try session.currentUID
        let response: TableResponse<BusDTO> = try await client.request(.busesAtStop(stopCode: stopCode), uid: uid)
        return response.table.map(Self.mapBusArrival)
    }

    func buses(line: String, stop: String?) async throws -> [BusArrival] {
        let uid = try session.currentUID
        let response: TableResponse<BusDTO> = try await client.request(
            .busesByLine(lineCode: line, stopCode: stop), uid: uid
        )
        return response.table.map(Self.mapBusArrival)
    }

    // MARK: - Card

    func cardBalance(_ card: String) async throws -> CardBalance {
        let uid = try session.currentUID
        let response: TableResponse<CardBalanceDTO> = try await client.request(.cardBalance(card: card), uid: uid)
        guard let dto = response.table.first else { throw APIError.invalidResponse }
        return Self.mapCardBalance(dto)
    }

    func cardUsage(_ card: String) async throws -> [CardTransaction] {
        let uid = try session.currentUID
        let response: TableResponse<CardTransactionDTO> = try await client.request(.cardUsage(card: card), uid: uid)
        return response.table.map(Self.mapCardTransaction)
    }
}

// MARK: - DTO → Model mapping
//
// Kept as pure static functions so they can be unit-tested directly against the
// sample fixtures in ego-api.md.

extension EGOService {
    static func mapLine(_ dto: LineDTO) -> Line {
        Line(
            id: dto.id,
            code: dto.kod,
            name: dto.ad,
            type: LineType(tur: dto.tur),
            durationMinutes: EGOParse.int(dto.sure),
            distanceKm: EGOParse.int(dto.mesafe)
        )
    }

    static func mapStop(_ dto: StopDTO) -> Stop {
        Stop(
            id: dto.id,
            code: dto.kod,
            name: dto.ad,
            location: dto.konum,
            coordinate: coordinate(lat: dto.lat, lng: dto.lng),
            order: EGOParse.int(dto.sira)
        )
    }

    static func mapLineDetail(_ response: LineDetailResponse) throws -> LineDetail {
        guard let lineDTO = response.table.first else { throw APIError.invalidResponse }

        var schedule: [DayType: [Departure]] = [:]
        for row in response.table_saat {
            guard let day = DayType(tur: row.tur) else { continue }
            schedule[day, default: []].append(
                Departure(hour: EGOParse.int(row.saat), minute: EGOParse.int(row.dakika), detail: row.detay)
            )
        }

        return LineDetail(
            line: mapLine(lineDTO),
            stops: response.table_durak.map(mapStop),
            schedule: schedule,
            routeCoordinates: parseRoute(response.yol)
        )
    }

    static func mapBusArrival(_ dto: BusDTO) -> BusArrival {
        let lineCode = dto.hat_kod ?? dto.hat_no ?? ""
        let lineName = dto.hat_ad ?? ""

        // "-" marks a placeholder for the next scheduled departure (no live bus).
        guard dto.arac_no != "-" else {
            let sure = dto.sure ?? ""
            return .scheduled(NextDeparture(
                lineCode: lineCode,
                lineName: lineName,
                nextDepartureText: nextDepartureText(from: sure),
                minutesUntil: minutesUntil(from: sure)
            ))
        }

        let detay = dto.detay ?? ""
        return .live(LiveBus(
            lineCode: lineCode,
            lineName: lineName,
            vehicleNo: dto.arac_no,
            plate: dto.plaka_no,
            coordinate: coordinate(lat: dto.lat, lng: dto.lng),
            remainingSeconds: remainingSeconds(from: dto),
            // detay uses a ‚ (U+201A) separator; test membership rather than split.
            isArticulated: detay.contains("Körüklü"),
            isAccessible: detay.contains("Engelli"),
            stopNo: dto.durak_no,
            prevStopNo: dto.onceki_durak_no
        ))
    }

    static func mapCardBalance(_ dto: CardBalanceDTO) -> CardBalance {
        CardBalance(
            card: dto.kart,
            balance: EGOParse.decimal(dto.bakiye),
            lastUsed: EGOParse.date(dto.tarih),
            subscriptionEnd: EGOParse.date(dto.aboSonTarih),
            hasSubscription: dto.isAbonman == "1"
        )
    }

    static func mapCardTransaction(_ dto: CardTransactionDTO) -> CardTransaction {
        CardTransaction(
            date: EGOParse.date(dto.tarih),
            amount: EGOParse.decimal(dto.dusen),
            remaining: EGOParse.decimal(dto.kalan),
            line: dto.hat,
            type: dto.islem_ack,
            description: dto.islem
        )
    }

    // MARK: Parsing helpers

    static func coordinate(lat: String?, lng: String?) -> CLLocationCoordinate2D? {
        guard let latitude = EGOParse.double(lat), let longitude = EGOParse.double(lng) else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// A live bus with `saniye == "999999"` (or `sure == "T.V.Süresi"`) exists but is
    /// past the selected stop, so it has no arrival time.
    static func remainingSeconds(from dto: BusDTO) -> Int? {
        if dto.sure == "T.V.Süresi" { return nil }
        guard let saniye = dto.saniye, saniye != "999999" else { return nil }
        return EGOParse.int(saniye)
    }

    /// The `sure` string is `"<header>\n<text>"`; we keep the text after the newline.
    static func nextDepartureText(from sure: String) -> String {
        let parts = sure.split(separator: "\n", omittingEmptySubsequences: false)
        let text = parts.last.map(String.init) ?? sure
        return text.trimmingCharacters(in: .whitespaces)
    }

    /// Minutes from the `/ N dk Sonra` fragment when present.
    static func minutesUntil(from sure: String) -> Int? {
        guard let range = sure.range(of: #"\d+\s*dk"#, options: .regularExpression) else { return nil }
        let digits = sure[range].prefix { $0.isNumber }
        return Int(digits)
    }

    /// `yol` is space-separated `lng,lat,0` triplets — longitude comes first.
    static func parseRoute(_ yol: String) -> [CLLocationCoordinate2D] {
        yol.split(separator: " ").compactMap { triplet in
            let parts = triplet.split(separator: ",")
            guard parts.count >= 2, let lng = Double(parts[0]), let lat = Double(parts[1]) else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
    }
}
