//
//  UserDefaultsKeys.swift
//  DockTile
//
//  Centralized UserDefaults key constants to prevent magic string bugs.
//  Swift 6 - Strict Concurrency
//

import Foundation

enum UserDefaultsKeys {
    static let hasAcknowledgedDockRestart = "hasAcknowledgedDockRestart"
    static let lastSelectedConfigId = "lastSelectedConfigId"
}
