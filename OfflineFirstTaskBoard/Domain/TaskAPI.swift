//
//  TaskAPI.swift
//  OfflineFirstTaskBoard
//
//  Created by Kanagasabapathy on 15.08.26.
//

import Foundation

nonisolated protocol TaskAPI: Sendable {
    func fetchAll() async throws -> [TaskItem]
    func create(_ task: TaskItem) async throws
    func update(_ task: TaskItem) async throws
    func delete(id: UUID) async throws
}
