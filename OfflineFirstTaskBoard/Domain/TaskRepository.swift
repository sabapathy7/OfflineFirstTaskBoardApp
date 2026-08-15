//
//  TaskRepository.swift
//  OfflineFirstTaskBoard
//
//  Created by Kanagasabapathy on 14.08.26.
//

import Foundation

nonisolated protocol TaskRepository: Sendable {
    func loadTasks() async throws -> [TaskItem]

    func create(title: String, description: String, status: TaskStatus) async throws -> TaskItem
    func edit(id: UUID, title: String, description: String, status: TaskStatus) async throws -> TaskItem
    func move(id: UUID, to status: TaskStatus) async throws -> TaskItem
    func reorder(in status: TaskStatus, fromOffsets: IndexSet, toOffset: Int) async throws -> [TaskItem]

    func delete(_ taskId: UUID) async throws

    func sync() async throws
}
