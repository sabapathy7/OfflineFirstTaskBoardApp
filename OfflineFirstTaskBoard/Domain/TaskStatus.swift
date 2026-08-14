//
//  TaskStatus.swift
//  OfflineFirstTaskBoard
//
//  Created by Kanagasabapathy on 14.08.26.
//

import Foundation

nonisolated enum TaskStatus: Sendable, Equatable {
    case todo
    case inProgress
    case done
}
