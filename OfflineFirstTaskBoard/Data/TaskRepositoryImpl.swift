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
    
    func create(title: String, description: String, status: TaskStatus) async throws -> TaskItem {
        let existing = try await store.fetchTasks()
        let column = existing.filter { $0.status == status && !$0.isDeleted }
        let taskItem = TaskItem(id: UUID(),
                                title: title,
                                taskDescription: description,
                                status: status,
                                createdAt: .now,
                                updatedAt: .now,
                                sortOrder: BoardRules.appendingSortOrder(in: column),
                                syncStatus: .pending,
                                isDeleted: false,
                                existsOnRemote: false)
        try await store.upsert(taskItem)
        return taskItem
    }
    
    func edit(id: UUID, title: String, description: String, status: TaskStatus) async throws -> TaskItem {
        let existing = try await store.fetchTasks()
        guard var task = existing.first(where: { $0.id == id && !$0.isDeleted }) else {
            throw TaskRepositoryError.notFound
        }

        if task.status != status {
            task = try await move(id: id, to: status)
        }

        task.title = title
        task.taskDescription = description
        task.updatedAt = .now
        task.syncStatus = .pending

        try await store.upsert(task)
        return task
    }
    
    func move(id: UUID, to status: TaskStatus) async throws -> TaskItem {
        let existing = try await store.fetchTasks()
        guard let task = existing.first(where: { $0.id == id && !$0.isDeleted }) else {
            throw TaskRepositoryError.notFound
        }

        let destination = existing.filter { $0.status == status && !$0.isDeleted && $0.id != id }
        let moved = BoardRules.moving(task, to: status, destinationColumn: destination, now: .now)
        try await store.upsert(moved)
        return moved
    }
    
    func reorder(in status: TaskStatus, fromOffsets: IndexSet, toOffset: Int) async throws -> [TaskItem] {
        let existing = try await store.fetchTasks()
        let column = existing
            .filter { $0.status == status && !$0.isDeleted }
            .sorted { $0.sortOrder < $1.sortOrder }

        let reordered = BoardRules.reordering(column, fromOffsets: fromOffsets, toOffset: toOffset, now: .now)
        for task in reordered {
            try await store.upsert(task)
        }
        return reordered.filter { !$0.isDeleted }
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
    
    func sync() async throws {
        try await syncEngine.sync()
    }
}
