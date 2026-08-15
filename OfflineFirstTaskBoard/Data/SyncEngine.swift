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
                        try await api.delete(id: task.id)
                    }
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
                try await store.upsert(synced)
            } catch {
                var failed = task
                failed.syncStatus = .failed
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

        for var incoming in remote {
            let existing = localByID[incoming.id]
            guard BoardRules.shouldApplyRemote(incoming, over: existing) else { continue }
            incoming.existsOnRemote = true
            incoming.syncStatus = .synced
            try await store.upsert(incoming)
        }

    }

}
