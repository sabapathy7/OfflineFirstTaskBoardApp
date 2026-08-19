//
//  TaskRepository.swift
//  OfflineFirstTaskBoard
//
//  Created by Kanagasabapathy on 14.08.26.
//

import Foundation

nonisolated protocol TaskRepository: Sendable {
    func loadTasks() async throws -> [TaskItem]

    func create(title: String, description: String, status: TaskStatus, subtasks: [SubtaskItem]) async throws -> TaskItem
    func edit(id: UUID, title: String, description: String, status: TaskStatus, subtasks: [SubtaskItem]) async throws -> TaskItem
    func move(id: UUID, to status: TaskStatus) async throws -> TaskItem
    func moveSubtask(taskId: UUID, subtaskId: UUID, to status: TaskStatus) async throws -> TaskItem
    func toggleSubtaskCompletion(taskId: UUID, subtaskId: UUID) async throws -> TaskItem
    func reorder(in status: TaskStatus, fromOffsets: IndexSet, toOffset: Int) async throws -> [TaskItem]

    func delete(_ taskId: UUID) async throws
    func deleteSubtask(taskId: UUID, subtaskId: UUID) async throws

    func sync() async throws

    /// Fires when another device changes the remote board, so the UI can sync
    /// without anyone tapping anything.
    var remoteChanges: AsyncStream<Void> { get }

    func archiving(_ taskId: UUID) async throws
    func restoring(_ taskId: UUID) async throws
}

extension TaskRepository {
    func create(title: String, description: String, status: TaskStatus) async throws -> TaskItem {
        try await create(title: title, description: description, status: status, subtasks: [])
    }
}
