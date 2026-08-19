//
//  TaskRepositoryImpl.swift
//  OfflineFirstTaskBoard
//
//  Created by Kanagasabapathy on 15.08.26.
//

import Foundation

nonisolated enum TaskRepositoryError: Error, Equatable, Sendable {
    case notFound
}

actor TaskRepositoryImpl: TaskRepository {

    private let store: TaskStore
    private let api: TaskAPI
    private let syncEngine: SyncEngine

    init(store: TaskStore, api: TaskAPI) {
        self.store = store
        self.api = api
        self.syncEngine = SyncEngine(store: store, api: api)
    }

    func loadTasks() async throws -> [TaskItem] {
        let local = try await store.fetchTasks()
        if !local.isEmpty {
            return local.filter { !$0.isDeleted }
        }

        guard let remote = try? await api.fetchAll() else { return [] }

        for var task in remote {
            task.existsOnRemote = true
            task.syncStatus = .synced
            task.isDeleted = false
            try await store.upsert(task)
        }
        return remote.filter { !$0.isDeleted }
    }
    
    func create(title: String, description: String, status: TaskStatus, subtasks: [SubtaskItem]) async throws -> TaskItem {
        let existing = try await store.fetchTasks()
        let column = existing.filter { $0.status == status && BoardRules.isOnBoard($0) }
        var taskItem = TaskItem(id: UUID(),
                                title: title,
                                taskDescription: description,
                                status: status,
                                createdAt: .now,
                                updatedAt: .now,
                                sortOrder: BoardRules.appendingSortOrder(in: column),
                                syncStatus: .pending,
                                isDeleted: false,
                                existsOnRemote: false,
                                subtasks: [],
                                isArchived: false)
        if !subtasks.isEmpty {
            taskItem = BoardRules.replacingSubtasks(on: taskItem, with: subtasks, now: taskItem.createdAt)
        }
        try await store.upsert(taskItem)
        return taskItem
    }
    
    func edit(id: UUID, title: String, description: String, status: TaskStatus, subtasks: [SubtaskItem]) async throws -> TaskItem {
        let existing = try await store.fetchTasks()
        guard var task = existing.first(where: { $0.id == id && !$0.isDeleted && !$0.isArchived }) else {
            throw TaskRepositoryError.notFound
        }

        if task.status != status {
            let destination = existing.filter { $0.status == status && !$0.isDeleted && !$0.isArchived && $0.id != id }
            task = BoardRules.moving(task, to: status, destinationColumn: destination, now: .now)
        }

        task.title = title
        task.taskDescription = description
        task = BoardRules.replacingSubtasks(on: task, with: subtasks, now: .now)
        try await store.upsert(task)
        return task
    }
    
    func move(id: UUID, to status: TaskStatus) async throws -> TaskItem {
        let existing = try await store.fetchTasks()
        guard let task = existing.first(where: { $0.id == id && !$0.isDeleted && !$0.isArchived }) else {
            throw TaskRepositoryError.notFound
        }

        let destination = existing.filter { $0.status == status && !$0.isDeleted && !$0.isArchived && $0.id != id }
        let moved = BoardRules.moving(task, to: status, destinationColumn: destination, now: .now)
        try await store.upsert(moved)
        return moved
    }

    func moveSubtask(taskId: UUID, subtaskId: UUID, to status: TaskStatus) async throws -> TaskItem {
        let existing = try await store.fetchTasks()
        guard let task = existing.first(where: { $0.id == taskId && !$0.isDeleted && !$0.isArchived }) else {
            throw TaskRepositoryError.notFound
        }
        guard task.subtasks.contains(where: { $0.id == subtaskId && !$0.isDeleted }) else {
            throw TaskRepositoryError.notFound
        }

        let moved = BoardRules.movingSubtask(in: task, id: subtaskId, to: status, now: .now)
        try await store.upsert(moved)
        return moved
    }

    func toggleSubtaskCompletion(taskId: UUID, subtaskId: UUID) async throws -> TaskItem {
        let existing = try await store.fetchTasks()
        guard let task = existing.first(where: { $0.id == taskId && !$0.isDeleted && !$0.isArchived }) else {
            throw TaskRepositoryError.notFound
        }
        guard task.subtasks.contains(where: { $0.id == subtaskId && !$0.isDeleted }) else {
            throw TaskRepositoryError.notFound
        }

        let toggled = BoardRules.togglingSubtask(in: task, id: subtaskId, now: .now)
        try await store.upsert(toggled)
        return toggled
    }
    
    func reorder(in status: TaskStatus, fromOffsets: IndexSet, toOffset: Int) async throws -> [TaskItem] {
        let existing = try await store.fetchTasks()
        let column = existing
            .filter { $0.status == status && BoardRules.isOnBoard($0) }
            .sorted { $0.sortOrder < $1.sortOrder }

        let reordered = BoardRules.reordering(column, fromOffsets: fromOffsets, toOffset: toOffset, now: .now)
        for task in reordered {
            try await store.upsert(task)
        }
        return reordered.filter { !$0.isDeleted && !$0.isArchived  }
    }
    
    func delete(_ taskId: UUID) async throws {
        let existing = try await store.fetchTasks()
        guard let task = existing.first(where: { $0.id == taskId }) else {
            throw TaskRepositoryError.notFound
        }

        switch BoardRules.delete(for: task) {
        case .dropLocally:
            try await store.delete(id: taskId)
        case .markDeleted:
            let hidden = BoardRules.markDelete(for: task, now: .now)
            try await store.upsert(hidden)
        }
    }

    func deleteSubtask(taskId: UUID, subtaskId: UUID) async throws {
        let existing = try await store.fetchTasks()
        guard let task = existing.first(where: { $0.id == taskId && !$0.isDeleted && !$0.isArchived  }) else {
            throw TaskRepositoryError.notFound
        }
        guard task.subtasks.contains(where: { $0.id == subtaskId }) else {
            throw TaskRepositoryError.notFound
        }

        let updated = BoardRules.removingSubtask(from: task, id: subtaskId, now: .now)
        try await store.upsert(updated)
    }
    
    func sync() async throws {
        try await syncEngine.sync()
    }

    nonisolated var remoteChanges: AsyncStream<Void> {
        api.remoteChanges
    }

    func archiving(_ taskId: UUID) async throws {
        let existing = try await store.fetchTasks()
        guard let task = existing.first(where: { $0.id == taskId && !$0.isDeleted }) else {
            throw TaskRepositoryError.notFound
        }
        try await store.upsert(BoardRules.archiveTask(for: task, now: .now))
    }

    func restoring(_ taskId: UUID) async throws {
        let existing = try await store.fetchTasks()
        guard let task = existing.first(where: { $0.id == taskId && !$0.isDeleted }) else {
            throw TaskRepositoryError.notFound
        }
        let column = existing.filter {
            $0.status == task.status && BoardRules.isOnBoard($0) && $0.id != task.id
        }
        try await store.upsert(BoardRules.restoreTask(for: task, destinationColumn: column, now: .now))
    }
}
