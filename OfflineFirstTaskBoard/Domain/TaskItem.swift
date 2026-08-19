//
//  TaskItem.swift
//  OfflineFirstTaskBoard
//
//  Created by Kanagasabapathy on 14.08.26.
//

import Foundation

nonisolated struct TaskItem: Equatable, Sendable, Identifiable {
    let id: UUID
    var title: String
    var taskDescription: String
    var status: TaskStatus
    var createdAt: Date
    var updatedAt: Date
    var sortOrder: Int
    var syncStatus: SyncStatus
    var isDeleted: Bool
    var existsOnRemote: Bool
    var subtasks: [SubtaskItem] = []
    var isArchived: Bool
}
