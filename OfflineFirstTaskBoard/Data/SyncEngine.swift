//
//  SyncEngine.swift
//  OfflineFirstTaskBoard
//
//  Created by Kanagasabapathy on 15.08.26.
//

import Foundation

actor SyncEngine {
    private let store: TaskStore
    private let api: TaskAPI

    init(store: TaskStore, api: TaskAPI) {
        self.store = store
        self.api = api
    }

    /// Push then pull, last-write-wins by `updatedAt` on both sides:
    /// - push: the API keeps the remote copy when it is newer (see `TaskAPI`),
    ///   so pushing an older edit is a no-op instead of a clobber.
    /// - pull: `BoardRules.shouldApplyRemote` applies a newer remote over any
    ///   local row, which also repairs a device whose push lost the race.
    /// Net effect: the final state is the latest edit, not the last device
    /// that happened to sync.
    func sync() async throws {
        try await pushPending()
        try await pullRemote()
    }

    private func pushPending() async throws {
        let rows = try await store.fetchTasks()

        var firstError: Error?

        for task in rows where task.syncStatus == .pending || task.syncStatus == .failed {
            do {
                if task.isDeleted {
                    if task.existsOnRemote {
                        try await api.delete(id: task.id, updatedAt: task.updatedAt)
                    }
                    // Drop the tombstone either way; if a newer remote edit
                    // survived the guarded delete, the pull below restores it.
                    try await store.delete(id: task.id)
                    continue
                }

                if task.existsOnRemote {
                    try await api.update(task)
                } else {
                    try await api.create(task)
                }

                var synced = task
                synced.syncStatus = .synced
                synced.existsOnRemote = true
                synced.subtasks = synced.subtasks.map { item in
                    var item = item
                    item.syncStatus = .synced
                    item.existsOnRemote = true
                    return item
                }
                try await store.upsert(synced)
            } catch {
                var failed = task
                failed.syncStatus = .failed
                failed.subtasks = failed.subtasks.map { item in
                    var item = item
                    if item.syncStatus == .pending {
                        item.syncStatus = .failed
                    }
                    return item
                }
                try? await store.upsert(failed)
                firstError = error
            }
        }

        if let firstError {
            throw firstError
        }
    }

    private func pullRemote() async throws {

        let remote = try await api.fetchAll()
        let local = try await store.fetchTasks()
        let localByID = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0)})

        let remoteIDs = Set(remote.map(\.id))

        for var incoming in remote {
            let existing = localByID[incoming.id]
            guard BoardRules.shouldApplyRemote(incoming, over: existing) else { continue }
            incoming.existsOnRemote = true
            incoming.syncStatus = .synced
            try await store.upsert(incoming)
        }

        for task in local {
            guard task.syncStatus == .synced,
                  task.existsOnRemote,
                  !remoteIDs.contains(task.id) else { continue }
            try await store.delete(id: task.id)
        }
    }

}
