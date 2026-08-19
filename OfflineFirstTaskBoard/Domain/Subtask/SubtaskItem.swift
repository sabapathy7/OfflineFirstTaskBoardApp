//
//  SubtaskItem.swift
//  OfflineFirstTaskBoard
//
//  Created by Kanagasabapathy on 19.08.26.
//

import Foundation

nonisolated struct SubtaskItem: Equatable, Sendable, Identifiable {
    let id: UUID
    var title: String
    var taskDescription: String
    var status: TaskStatus
    var subtaskStatus: SubtaskStatus
    var createdAt: Date
    var updatedAt: Date
    var sortOrder: Int
    var syncStatus: SyncStatus
    var isDeleted: Bool
    var existsOnRemote: Bool
    var taskID: UUID

    init(
        id: UUID = UUID(),
        title: String,
        taskDescription: String = "",
        status: TaskStatus,
        subtaskStatus: SubtaskStatus? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        sortOrder: Int,
        syncStatus: SyncStatus = .pending,
        isDeleted: Bool = false,
        existsOnRemote: Bool = false,
        taskID: UUID
    ) {
        self.id = id
        self.title = title
        self.taskDescription = taskDescription
        self.status = status
        self.subtaskStatus = subtaskStatus ?? .matching(status)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sortOrder = sortOrder
        self.syncStatus = syncStatus
        self.isDeleted = isDeleted
        self.existsOnRemote = existsOnRemote
        self.taskID = taskID
    }
}
