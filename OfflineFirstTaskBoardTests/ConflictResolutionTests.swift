//
//  ConflictResolutionTests.swift
//  OfflineFirstTaskBoard
//
//  Created by Kanagasabapathy on 19.08.26.
//

import Foundation
import Testing
@testable import OfflineFirstTaskBoard

/// The same task edited on two devices must converge on the latest edit,
/// no matter which device syncs first.
@Suite("Conflict Resolution")
struct ConflictResolutionTests {

    private func makeDevice(api: MockTaskAPI) -> (store: TaskStore, repo: TaskRepositoryImpl) {
        let store = CoreDataTaskStore(stack: PersistenceController(inMemory: true))
        return (store, TaskRepositoryImpl(store: store, api: api))
    }

    private func makeTask(id: UUID = UUID(),
                          title: String,
                          updatedAt: Date,
                          syncStatus: SyncStatus = .synced,
                          isDeleted: Bool = false) -> TaskItem {
        TaskItem(id: id,
                 title: title,
                 taskDescription: "",
                 status: .todo,
                 createdAt: Date(timeIntervalSince1970: 0),
                 updatedAt: updatedAt,
                 sortOrder: 0,
                 syncStatus: syncStatus,
                 isDeleted: isDeleted,
                 existsOnRemote: true,
                 isArchived: false)
    }

    @Test("last edit wins even when the earlier editor syncs last",
          arguments: [true, false])
    func lastEditWinsRegardlessOfSyncOrder(laterEditorSyncsFirst: Bool) async throws {
        let api = MockTaskAPI()
        let deviceA = makeDevice(api: api)
        let deviceB = makeDevice(api: api)

        // One shared task, synced everywhere.
        let created = try await deviceA.repo.create(title: "Original", description: "", status: .todo)
        try await deviceA.repo.sync()
        _ = try await deviceB.repo.loadTasks()

        // A edits first, B edits later. updatedAt strictly increases.
        _ = try await deviceA.repo.edit(id: created.id, title: "Edit from A", description: "", status: .todo, subtasks: [])
        _ = try await deviceB.repo.edit(id: created.id, title: "Edit from B", description: "", status: .todo, subtasks: [])

        if laterEditorSyncsFirst {
            try await deviceB.repo.sync()
            try await deviceA.repo.sync()
            try await deviceB.repo.sync()
        } else {
            try await deviceA.repo.sync()
            try await deviceB.repo.sync()
            try await deviceA.repo.sync()
        }

        // B's edit is the newest, so it must win everywhere.
        #expect(try await api.fetchAll().map(\.title) == ["Edit from B"])
        #expect(try await deviceA.store.fetchTasks().map(\.title) == ["Edit from B"])
        #expect(try await deviceB.store.fetchTasks().map(\.title) == ["Edit from B"])
        #expect(try await deviceA.store.fetchTasks()[0].syncStatus == .synced)
        #expect(try await deviceB.store.fetchTasks()[0].syncStatus == .synced)
    }

    @Test("pushing an older edit never clobbers a newer remote copy")
    func pushSkipsOlderEditAndPullRepairsLocal() async throws {
        let api = MockTaskAPI()
        let store = CoreDataTaskStore(stack: PersistenceController(inMemory: true))
        let repo = TaskRepositoryImpl(store: store, api: api)

        let id = UUID()
        try await api.create(makeTask(id: id, title: "Newer remote", updatedAt: Date(timeIntervalSince1970: 300)))
        try await store.upsert(makeTask(id: id, title: "Older local", updatedAt: Date(timeIntervalSince1970: 0), syncStatus: .pending))

        try await repo.sync()

        #expect(try await api.fetchAll().map(\.title) == ["Newer remote"])
        let rows = try await store.fetchTasks()
        #expect(rows.map(\.title) == ["Newer remote"])
        #expect(rows[0].syncStatus == .synced)
    }

    @Test("a newer remote edit survives an older local delete")
    func newerRemoteEditSurvivesOlderDelete() async throws {
        let api = MockTaskAPI()
        let store = CoreDataTaskStore(stack: PersistenceController(inMemory: true))
        let repo = TaskRepositoryImpl(store: store, api: api)

        let id = UUID()
        try await api.create(makeTask(id: id, title: "Edited after delete", updatedAt: Date(timeIntervalSince1970: 300)))
        try await store.upsert(makeTask(id: id, title: "Doomed", updatedAt: Date(timeIntervalSince1970: 0), syncStatus: .pending, isDeleted: true))

        try await repo.sync()

        // The delete loses to the newer edit: server keeps the task and the
        // deleting device pulls it back.
        #expect(try await api.fetchAll().map(\.title) == ["Edited after delete"])
        let rows = try await store.fetchTasks()
        #expect(rows.map(\.title) == ["Edited after delete"])
        #expect(rows[0].isDeleted == false)
        #expect(rows[0].syncStatus == .synced)
    }

    @Test("a newer delete removes an older remote edit")
    func newerDeleteRemovesOlderRemoteEdit() async throws {
        let api = MockTaskAPI()
        let store = CoreDataTaskStore(stack: PersistenceController(inMemory: true))
        let repo = TaskRepositoryImpl(store: store, api: api)

        let id = UUID()
        try await api.create(makeTask(id: id, title: "Edited before delete", updatedAt: Date(timeIntervalSince1970: 0)))
        try await store.upsert(makeTask(id: id, title: "Tombstone", updatedAt: Date(timeIntervalSince1970: 300), syncStatus: .pending, isDeleted: true))

        try await repo.sync()

        #expect(try await api.fetchAll().isEmpty)
        #expect(try await store.fetchTasks().isEmpty)
    }
}
