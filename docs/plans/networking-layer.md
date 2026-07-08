# EGO — Networking Layer Plan

## Context

EGO is a from-scratch SwiftUI reimplementation of Ankara's public-transit app. The
repo is currently Xcode boilerplate only (`EGOApp.swift`, `ContentView.swift`) — there
is no networking code yet. Every screen in the design (Home stop lookup, Lines list,
Stop detail, Line detail, Card) is driven by EGO JSON API documented in `ego-api.md`.
This plan builds the full networking foundation so the UI work can sit on typed, testable
async methods.

The API is quirky: no real auth but a mandatory `UID` param with a finite lifetime renewed
on launch; a required Android `user-agent`; every number/date is a **string**; most
responses wrap rows in a `table` array; bus objects are **dual-shaped** (a live bus vs a
"next departure" placeholder); and one endpoint (`HatBilgileri`) returns stops, schedule,
and a packed GPS route string all at once.

**Decisions locked in:**

- **UID expiry → surface error only.** No transparent retry. Launch always renews; screens
  refetch on-appear / pull-to-refresh.
- **Clean domain models.** Raw `Codable` DTOs decode the JSON, then map to clean Swift
  models (Int/Double/Date, English names, a `BusArrival` enum). Views never see Turkish
  field names or stringly-typed numbers.
- iOS 17+, `@Observable` + async/await, `@MainActor` (no actors needed — network calls are
  async and won't block UI; `URLSession` is thread-safe).

## Endpoint inventory (9)

Base URL: `https://egocptsrvios.ego.gov.tr/hibrit/` — all paths relative to it.
Client appends `UID` + `LAN=tr`. Each endpoint adds `FNC` + its own params. The one
exception: the first-run `Connect` call **omits `UID` entirely** so the server mints one.

| Purpose                     | Path                      | FNC                  | Params                             | Response shape                                       |
| --------------------------- | ------------------------- | -------------------- | ---------------------------------- | ---------------------------------------------------- |
| Connect (acquire/renew UID) | `connect/androidConn.asp` | `Connect`            | `D`(device), `VER`, `T=red`, `UID` | flat object w/ `userID`                              |
| Lines list                  | `act.asp`                 | `Hatlar`             | `QUERY`                            | `table[]`                                            |
| Line details                | `act.asp`                 | `HatBilgileri`       | `YOL=TRUE`, `KOD`                  | `table[]` + `table_durak[]` + `table_saat[]` + `yol` |
| Stop details                | `action.asp`              | `Durak`              | `KOD`                              | `table[]`                                            |
| Stop search                 | `action.asp`              | `Duraklar`           | `QUERY`                            | `table[]`                                            |
| Buses at stop               | `srv.asp`                 | `Otobusler`          | `DURAK`                            | `table[]` (dual-shape)                               |
| Buses on line               | `srv.asp`                 | `Otobus`             | `HAT`, `DURAK`(optional)           | `table[]` (dual-shape)                               |
| Card balance                | `action.asp`              | `AnkaraKartBakiye`   | `KART`                             | `table[]`                                            |
| Card usage                  | `action.asp`              | `AnkaraKartKullanim` | `KART`                             | `table[]`                                            |

## File structure (new group `EGO/Networking/`)

```
Networking/
  APIConfig.swift        constants (baseURL, userAgent, version, device string)
  APIError.swift         error enum
  EGOEndpoint.swift      enum: path + queryItems per endpoint
  APIClient.swift        builds request, sets headers, decodes, checks status
  Session.swift          @Observable @MainActor — UID lifecycle (connect/renew)
  Decoding.swift         helpers: string→Int/Double/Decimal, dd.MM.yyyy date
DTO/
  ConnectDTO.swift, LineDTO.swift, LineDetailDTO.swift,
  StopDTO.swift, BusDTO.swift, CardDTO.swift
Models/
  Line.swift, LineDetail.swift, Stop.swift,
  BusArrival.swift, Card.swift
Services/
  EGOService.swift       typed async methods; DTO→Model mapping
```

## Components

### APIConfig

```swift
enum APIConfig {
  static let baseURL   = URL(string: "https://egocptsrvios.ego.gov.tr/hibrit/")!
  static let userAgent = "EGO Genel Mudurlugu-EGO Cepte-ANDROID-samsung-SM-S942B-osV:16.0.0-apV:-"
  static let version   = "4.1.6"
  static let device    = "ANDROID-samsung-SM-S942B-osV:16.0.0-apV:-"
}
```

### Headers (in APIClient)

Set `user-agent` (mandatory), `accept: application/json; charset=UTF-8`, `connection: keep-alive`.
**Do NOT set `accept-encoding` manually** — `URLSession` adds it and transparently gunzips;
setting it ourselves would force manual decompression. The server does **not** require an
explicit `accept-encoding: gzip`, so there is nothing to work around here.

### EGOEndpoint

`enum EGOEndpoint` with cases per row above; computed `path: String` and
`queryItems: [URLQueryItem]` (FNC + endpoint-specific only). Built via `URLComponents`
against `APIConfig.baseURL`. `busesByLine(lineCode:stopCode:)` omits `DURAK` when `stopCode == nil`.

### APIClient

Non-actor struct holding a `URLSession`.

- `func request<T: Decodable>(_ endpoint: EGOEndpoint, uid: String) async throws -> T`
  — builds the `URLRequest`, appends `UID`+`LAN=tr`, sets headers, runs the call, checks
  HTTP status, decodes `T`, then validates the API `status == "TRUE"` via an `EGOResponse`
  protocol (`var status: String`, `var message: String`) that every top-level response conforms
  to. Throws `APIError.apiStatus(message:)` otherwise.
- Two top-level response wrappers:
  - `TableResponse<Row: Decodable>: EGOResponse { table: [Row]; message; status }` — used by 7 endpoints.
  - `ConnectResponse` and `LineDetailResponse` — bespoke (multiple arrays / flat object).

### Session (`@Observable @MainActor`)

- Holds `private(set) var uid: String?`, persisted in `UserDefaults` (survives relaunch,
  still renewed each launch).
- `func connect() async throws` → hits `Connect`, adopts the returned `userID`, persists it.
  Called from the root view's `.task` on launch.
  - **First run:** simply **omit the `UID` param** — `androidConn.asp` is the only endpoint that
    allows this, and the server generates and returns a fresh `userID`. No empty string / no
    generated UUID needed.
  - **Subsequent launches:** send the stored UID to renew it; adopt whatever `userID` comes back.
- `var currentUID: String get throws` — throws `APIError.notConnected` if nil.

### EGOService (`@MainActor`)

Owns an `APIClient` + a reference to `Session`. Each method reads `session.currentUID`, calls
`client.request`, and maps DTO→Model:

```swift
func lines(query: String = "") async throws -> [Line]
func lineDetails(code: String) async throws -> LineDetail
func stop(code: String) async throws -> Stop
func searchStops(_ query: String) async throws -> [Stop]
func busesAtStop(_ stopCode: String) async throws -> [BusArrival]
func buses(line: String, stop: String?) async throws -> [BusArrival]
func cardBalance(_ card: String) async throws -> CardBalance
func cardUsage(_ card: String) async throws -> [CardTransaction]
```

## Domain models & mapping rules

**Line** — `id, code(kod), name(ad), type: LineType, durationMinutes(sure), distanceKm(mesafe)`.
`LineType { bus, metro, ankaray, suburban }` parsed from `tur` (`EGO, OTOBÜS`→bus, `METRO`→metro,
`ANKARAY`→ankaray, `BANLİYO`→suburban). Lines segmented control = `bus` vs rail(rest).

**Stop** — `id, code(kod), name(ad), location(konum), coordinate: CLLocationCoordinate2D?(lat,lng),
order: Int?(sira, line-detail only)`.

**BusArrival** — `enum { live(LiveBus), scheduled(NextDeparture) }`. Discriminate by `arac_no != "-"`.

- `LiveBus`: `lineCode(hat_kod/hat_no), lineName(hat_ad), vehicleNo(arac_no), plate(plaka_no),
coordinate, remainingSeconds(saniye), isArticulated, isAccessible, stopNo, prevStopNo`.
  - `saniye == "999999"` / `sure == "T.V.Süresi"` ⇒ bus exists but not arriving at the selected
    stop (past it) → `remainingSeconds = nil`.
  - `detay` uses a `‚` (U+201A) separator, e.g. `"Solo‚ Engelli"` — **do not split on it**; just
    `isArticulated = detay.contains("Körüklü")`, `isAccessible = detay.contains("Engelli")`.
- `NextDeparture`: `lineCode, lineName, nextDepartureText, minutesUntil?` — parse `sure`
  (`"Sonraki Hareket Saati İlk Duraktan\n00:01 / 1 dk Sonra"`): text after `\n`, and minutes
  from the `/ N dk Sonra` fragment when present.

**LineDetail** — one `HatBilgileri` response →
`{ line: Line, stops: [Stop], schedule: [DayType: [Departure]], routeCoordinates: [CLLocationCoordinate2D] }`.

- `stops` from `table_durak` (carry `sira` into `Stop.order`).
- `schedule` from `table_saat`, grouped by `tur`: `HAFTA İÇİ`→weekday, `CUMARTESİ`→saturday,
  `PAZAR`→sunday. `Departure { hour(saat), minute(dakika), detail(detay) }`. `DayType` maps to the
  Departures tab segmented control.
- `routeCoordinates` from `yol`: space-separated triplets `"lng,lat,0"` — **note lng comes first**,
  build `CLLocationCoordinate2D(latitude: parts[1], longitude: parts[0])`.

**CardBalance** — `card(kart), balance: Decimal(bakiye, TRY), lastUsed: Date?(tarih),
subscriptionEnd: Date?(aboSonTarih), hasSubscription(isAbonman == "1")`.
**CardTransaction** — `date(tarih), amount(dusen), remaining(kalan), line(hat), type(islem_ack),
description(islem)`.

### Decoding.swift helpers

- Numbers: values are strings but use `.` decimals here (`"10.01"`, `"788.96"`) → `Int(_)`,
  `Double(_)`, `Decimal(string:)` with `Locale(identifier: "en_US_POSIX")`.
- Dates: `"dd.MM.yyyy HH:mm:ss"`, `en_US_POSIX`, `TimeZone(identifier: "Europe/Istanbul")`.
- Reusable `DateFormatter`/parse funcs shared across DTO mapping.

### APIError

`invalidResponse | http(Int) | apiStatus(message: String) | decoding(Error) | notConnected`.

## App integration (brief)

- `EGOApp` creates a `Session` + `EGOService`, injects them via `.environment`.
- Root view `.task { try? await session.connect() }` on launch to acquire/renew the UID.
- Selected stop is shared UI state held in an `@Observable` so multiple screens (e.g. the
  buses-on-line tab) can read it without threading a stop code through navigation — the exact
  placement (its own type vs. folded into existing app state) is a UI decision, out of scope for
  this networking plan. The buses-on-line call reads its code as the optional `DURAK`.
- Cards persisted in `UserDefaults` (per design tips) — consumed by card service calls.

## Verification

1. **DTO decoding unit tests** — paste each sample JSON from `ego-api.md` as a fixture
   and assert the DTO decodes and maps to the expected model. Cover both bus shapes (live +
   next-departure), the `HatBilgileri` multi-array response, and card balance/usage.
2. **Parser unit tests** — `tur`→`LineType`; `detay`→`isArticulated`/`isAccessible` (incl. the
   `‚` separator); `yol`→coordinates (assert lat/lng order is correct); `sure`→`minutesUntil`;
   `saniye == "999999"`→nil; date + Decimal parsing.
3. **Live smoke test** — a temporary debug button (or an async `@Test` hitting the network) that
   calls `session.connect()` then `service.lines()` / `service.stop(code: "11123")` /
   `service.busesAtStop("11123")` and prints results; compare against the `curl` examples in the
   design doc. Confirm the no-`accept-encoding` decision returns valid JSON.
4. Build & run in the simulator; verify launch `connect()` populates a UID and a follow-up call
   succeeds.
