//
//  BoardRules.swift
//  OfflineFirstTaskBoard
//
//  Created by Kanagasabapathy on 14.08.26.
//

import Foundation

nonisolated enum BoardRules: Sendable {
    static func appendingSortOrder(in column: [TaskItem]) -> Int {
        column.filter { !$0.isDeleted }.count
    }

    static func moving(_ task: TaskItem, to destination: TaskStatus, destinationColumn: [TaskItem], now: Date) -> TaskItem {
        var moved = task
        moved.status = destination
        moved.sortOrder = appendingSortOrder(in: destinationColumn)
        moved.syncStatus = .pending
        moved.updatedAt = now
        return moved
    }

    static func reordering(_ column: [TaskItem], fromOffsets: IndexSet, toOffset: Int, now: Date) -> [TaskItem] {
        var column = column

        let moving = fromOffsets.sorted().map { column[$0] }
        for index in fromOffsets.sorted(by: >) {
            column.remove(at: index)
        }

        let dest = toOffset - fromOffsets.filter { $0 < toOffset }.count
        column.insert(contentsOf: moving, at: dest)

        var order = 0
        for i in column.indices {
            guard !column[i].isDeleted else { continue }
            column[i].sortOrder = order
            column[i].syncStatus = .pending
            column[i].updatedAt = now
            order += 1
        }
        return column
    }

    static func delete(for task: TaskItem) -> DeleteDecision {
        if !task.isDeleted && !task.existsOnRemote {
            return .dropLocally
        }
        if task.existsOnRemote {
            return .markDeleted
        }
        return .dropLocally
    }

    static func markDelete(for task: TaskItem, now: Date) -> TaskItem {
        var task = task
        task.isDeleted = true
        task.updatedAt = now
        task.syncStatus = .pending
        return task
    }

    static func shouldApplyRemote(_ remote: TaskItem, over local: TaskItem?) -> Bool {
        switch local?.syncStatus {
        case .pending, .failed:
            return false
        case .synced, .none:
            return true
        }
    }
}

nonisolated enum DeleteDecision: Equatable, Sendable {
    case dropLocally
    case markDeleted
}
