//
//  SyncStatus.swift
//  OfflineFirstTaskBoard
//
//  Created by Kanagasabapathy on 14.08.26.
//

import Foundation

nonisolated enum SyncStatus: String, Equatable, Sendable {
    case pending
    case synced
    case failed
}
