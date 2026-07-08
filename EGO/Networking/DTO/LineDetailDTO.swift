//
//  LineDetailDTO.swift
//  EGO
//
//  `HatBilgileri` packs the line, its stops, its schedule, and a GPS route string
//  into one response.
//

import Foundation

struct LineDetailResponse: Decodable, EGOResponse {
    let table: [LineDTO]
    let table_durak: [StopDTO]
    let table_saat: [ScheduleRowDTO]
    /// Space-separated `lng,lat,0` triplets — note longitude comes first.
    let yol: String
    let message: String
    let status: String
}

struct ScheduleRowDTO: Decodable {
    let tur: String        // "HAFTA İÇİ" / "CUMARTESİ" / "PAZAR"
    let saat: String       // hour (string)
    let dakika: String     // minute (string)
    let detay: String?
}
