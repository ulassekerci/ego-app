# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

EGO App is a from-scratch SwiftUI reimplementation of the public-transit app for Ankara, Turkey's EGO transit authority. It aims to improve on the usability and design of the official app. Branding: white text on `#E30A17` red.

The repo is currently **Xcode boilerplate only** (`EGOApp.swift`, `ContentView.swift`) — no networking or feature code exists yet. The documents under `docs/` are the source of truth for what to build:

- `docs/app-design.md` — full product spec: every screen and its behavior.
- `docs/ego-api.md` — the EGO JSON API (endpoints, sample requests/responses, quirks).
- `docs/plans/networking-layer.md` — the agreed implementation plan for the networking foundation (file layout, DTO→model mapping, UID lifecycle). Start here before writing networking code.

**Read these docs before implementing anything.** They contain decisions already locked in — don't re-litigate them.

## Commands

Single app target and scheme, both named `EGO`. There is **no test target yet**; add one (`com.apple.product-type.bundle.unit-test`, Swift Testing per the plan) before writing tests.

```sh
# Build (pick an installed simulator runtime; deployment target is iOS 26.5)
xcodebuild -scheme EGO -destination 'platform=iOS Simulator,name=iPhone 16' build

# Test (once a test target exists)
xcodebuild -scheme EGO -destination 'platform=iOS Simulator,name=iPhone 16' test

# Run a single test
xcodebuild -scheme EGO -destination 'platform=iOS Simulator,name=iPhone 16' \
  test -only-testing:EGOTests/SuiteName/testName
```

Prefer opening `EGO.xcodeproj` in Xcode for iterative work. Config: Swift 5.0, bundle id `com.ulas.EGO`, iOS 26.5 deployment target — so target **iOS 17+ APIs** (`@Observable`, async/await, `@MainActor`) as the plan specifies.

## Architecture (planned — see networking-layer.md)

The app sits on a typed async networking layer that hides the messy API from views:

- **DTO → Model split.** Raw `Codable` DTOs decode the API's JSON verbatim (Turkish field names, everything stringly-typed), then map to clean Swift domain models (Int/Double/Decimal/Date, English names). **Views never see DTOs or Turkish keys.**
- **`Session` (`@Observable @MainActor`)** owns the UID lifecycle. `EGOService` (`@MainActor`) owns an `APIClient` + `Session` and exposes typed async methods that map DTO→Model. `EGOApp` injects both via `.environment`; the root view renews the UID in `.task` on launch.
- **Selected stop** is shared UI state kept in an `@Observable` (no persistence) so multiple screens can read it without passing a stop code through navigation; the buses-on-line screen reads its code as the optional `DURAK` param. Whether this lives in its own type or is folded into existing app state is an open UI decision. **User cards** persist in `UserDefaults`.

### API quirks that will bite you (all confirmed in the design doc)

- **Auth is a mandatory `UID` query param**, not a login. It has a finite lifetime and is renewed by re-hitting `connect/androidConn.asp` on every launch. On **first run only**, omit `UID` entirely so the server mints one. UID expiry surfaces as an error — no transparent retry.
- **A valid Android `user-agent` header is mandatory** or the API returns nothing:
  `EGO Genel Mudurlugu-EGO Cepte-ANDROID-samsung-SM-S942B-osV:16.0.0-apV:-`
- **Do NOT set `accept-encoding` manually** — `URLSession` adds gzip and gunzips transparently.
- Every request also appends `LAN=tr`. Base URL: `https://egocptsrvios.ego.gov.tr/hibrit/`.
- Every number and date in responses is a **string**. Parse with `en_US_POSIX`; dates are `dd.MM.yyyy HH:mm:ss` in `Europe/Istanbul`.
- Success is signalled by `status == "TRUE"` in the JSON body (not just HTTP 200). Most responses wrap rows in a `table` array.
- **Bus objects are dual-shaped.** Discriminate on `arac_no`: `"-"` = a scheduled "next departure" placeholder (parse `sure`); otherwise a live bus. A live bus with `saniye == "999999"` / `sure == "T.V.Süresi"` exists but is past the selected stop → no arrival time. `detay` uses a `‚` (U+201A) separator — don't split on it; test `.contains("Körüklü")` (articulated) / `.contains("Engelli")` (accessible).
- The `yol` route string in line details is space-separated `lng,lat,0` triplets — **longitude comes first**.
- Skip the `doluluk` (occupancy) and `trafik` (traffic) fields in bus responses. `trafik` isn't needed and `doluluk` isn't provided by EGO yet.
