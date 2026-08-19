//
//  SubtaskStatus.swift
//  OfflineFirstTaskBoard
//
//  Created by Kanagasabapathy on 19.08.26.
//

import Foundation

nonisolated enum SubtaskStatus: String, Sendable, Equatable, CaseIterable {
    case complete
    case incomplete
}

nonisolated extension SubtaskStatus {
    static func matching(_ column: TaskStatus) -> SubtaskStatus {
        column == .done ? .complete : .incomplete
    }
}
