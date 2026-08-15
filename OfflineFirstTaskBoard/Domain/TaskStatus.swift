//
//  TaskStatus.swift
//  OfflineFirstTaskBoard
//
//  Created by Kanagasabapathy on 14.08.26.
//

import Foundation

nonisolated enum TaskStatus: String, Sendable, Equatable, CaseIterable {
    case todo
    case inProgress
    case done
}

nonisolated extension TaskStatus {
    var next: TaskStatus? {
        switch self {
        case .todo: .inProgress
        case .inProgress: .done
        case .done: nil
        }
    }

    var previous: TaskStatus? {
        switch self {
        case .todo: nil
        case .inProgress: .todo
        case .done: .inProgress
        }
    }

    var label: String {
        switch self {
        case .todo: "To Do"
        case .inProgress: "In Progress"
        case .done: "Done"
        }
    }
}
