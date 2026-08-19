//
//  BoardRules.swift
//  OfflineFirstTaskBoard
//
//  Created by Kanagasabapathy on 14.08.26.
//

import Foundation

nonisolated enum BoardRules: Sendable {
    static func appendingSortOrder(in column: [TaskItem]) -> Int {
        column.filter(isOnBoard).count
    }

    static func isOnBoard(_ task: TaskItem) -> Bool {
        !task.isDeleted && !task.isArchived
    }

    static func moving(_ task: TaskItem, to destination: TaskStatus, destinationColumn: [TaskItem], now: Date) -> TaskItem {
        var moved = task
        moved.status = destination
        moved.sortOrder = appendingSortOrder(in: destinationColumn)
        moved.syncStatus = .pending
        moved.updatedAt = now
        moved.subtasks = moved.subtasks.map { cascading($0, to: destination, now: now) }
        return moved
    }

    static func movingSubtask(in task: TaskItem, id: UUID, to destination: TaskStatus, now: Date) -> TaskItem {
        var task = task
        task.subtasks = task.subtasks.map { item in
            guard item.id == id, !item.isDeleted else { return item }
            return applying(destination, to: item, now: now)
        }
        task.syncStatus = .pending
        task.updatedAt = now
        return task
    }

    static func replacingSubtasks(on task: TaskItem, with subtasks: [SubtaskItem], now: Date) -> TaskItem {
        var task = task
        task.subtasks = subtasks.enumerated().map { index, item in
            var item = item
            item.taskID = task.id
            item.sortOrder = index
            item.subtaskStatus = .matching(item.status)
            item.syncStatus = .pending
            item.updatedAt = now
            return item
        }
        task.syncStatus = .pending
        task.updatedAt = now
        return task
    }

    static func removingSubtask(from task: TaskItem, id: UUID, now: Date) -> TaskItem {
        var task = task
        task.subtasks.removeAll { $0.id == id }
        task.syncStatus = .pending
        task.updatedAt = now
        return task
    }

    static func sections(from tasks: [TaskItem], in status: TaskStatus) -> [BoardSection] {
        let live = tasks.filter { !$0.isDeleted && !$0.isArchived }
        let parentsInColumn = live
            .filter { $0.status == status }
            .sorted { $0.sortOrder < $1.sortOrder }
        let parentIDs = Set(parentsInColumn.map(\.id))

        let parentSections = parentsInColumn.map { task in
            BoardSection(task: task, showsTask: true, subtasks: subtasks(in: status, from: task))
        }

        let childOnlySections = live
            .filter { !parentIDs.contains($0.id) }
            .compactMap { task -> BoardSection? in
                let children = subtasks(in: status, from: task)
                guard !children.isEmpty else { return nil }
                return BoardSection(task: task, showsTask: false, subtasks: children)
            }
            .sorted { $0.task.createdAt < $1.task.createdAt }

        return parentSections + childOnlySections
    }

    private static func subtasks(in status: TaskStatus, from task: TaskItem) -> [SubtaskItem] {
        task.subtasks
            .filter { !$0.isDeleted && $0.status == status }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private static func cascading(_ subtask: SubtaskItem, to destination: TaskStatus, now: Date) -> SubtaskItem {
        guard !subtask.isDeleted else { return subtask }
        return applying(destination, to: subtask, now: now)
    }

    private static func applying(_ destination: TaskStatus, to subtask: SubtaskItem, now: Date) -> SubtaskItem {
        var item = subtask
        item.status = destination
        item.subtaskStatus = .matching(destination)
        item.syncStatus = .pending
        item.updatedAt = now
        return item
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
            guard BoardRules.isOnBoard(column[i]) else { continue }
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

    /// Auto sync issue resolve
    static func shouldApplyRemote(_ remote: TaskItem, over local: TaskItem?) -> Bool {
        guard let local else { return true }
        switch local.syncStatus {
        case .synced:
            return true
        case .pending, .failed:
            return remote.updatedAt > local.updatedAt
        }
    }

    static func archiveTask(for task: TaskItem, now: Date) -> TaskItem {
        var task = task
        task.isArchived = true
        task.updatedAt = now
        task.syncStatus = .pending
        return task
    }

    static func restoreTask(for task: TaskItem, destinationColumn: [TaskItem], now: Date) -> TaskItem {
        var task = task
        task.isArchived = false
        task.sortOrder = appendingSortOrder(in: destinationColumn)
        task.updatedAt = now
        task.syncStatus = .pending
        return task
    }

    static func togglingSubtask(in task: TaskItem, id: UUID, now: Date) -> TaskItem {
        var task = task
        task.subtasks = task.subtasks.map { item in
            guard item.id == id, !item.isDeleted else { return item }
            var updated = item
            updated.subtaskStatus = item.subtaskStatus == .complete ? .incomplete : .complete
            updated.syncStatus = .pending
            updated.updatedAt = now
            return updated
        }
        task.syncStatus = .pending
        task.updatedAt = now
        return task
    }
}

nonisolated enum DeleteDecision: Equatable, Sendable {
    case dropLocally
    case markDeleted
}
