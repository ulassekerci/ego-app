//
//  SelectedStopStore.swift
//  EGO
//
//  Shared UI state for the most recently viewed stop. Not persisted — it only
//  exists so screens like the buses-on-line tab can read the stop code without
//  it being passed through navigation.
//

import Foundation

@MainActor
@Observable
final class SelectedStopStore {
    var stop: Stop?
}
