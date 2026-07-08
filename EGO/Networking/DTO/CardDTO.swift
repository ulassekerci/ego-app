//
//  CardDTO.swift
//  EGO
//

import Foundation

/// A row from `AnkaraKartBakiye`.
struct CardBalanceDTO: Decodable {
    let kart: String
    let tarih: String?         // last used
    let aboSonTarih: String?   // subscription end date
    let isAbonman: String?     // "1" ⇒ has subscription
    let bakiye: String?        // balance in TRY (string, "." decimals)
}

/// A row from `AnkaraKartKullanim`.
struct CardTransactionDTO: Decodable {
    let tarih: String?
    let arac_no: String?
    let hat: String?
    let dusen: String?         // amount deducted
    let kalan: String?         // remaining balance
    let islem_ack: String?     // transaction type, e.g. "NORMAL BİNİŞ"
    let islem: String?         // full description
}
