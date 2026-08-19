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

    /// Last-write-wins: implementations must keep the remote copy when it is
    /// newer than `task.updatedAt`, so the final state never depends on which
    /// device happened to sync first.
    func update(_ task: TaskItem) async throws

    /// `updatedAt` is the tombstone time. Implementations must keep a remote
    /// copy that was edited after the delete happened.
    func delete(id: UUID, updatedAt: Date) async throws

    /// Emits when another writer changes the remote board. Backends without
    /// change notifications use the default empty stream.
    var remoteChanges: AsyncStream<Void> { get }
}

extension TaskAPI {
    nonisolated var remoteChanges: AsyncStream<Void> {
        AsyncStream { $0.finish() }
    }
}
