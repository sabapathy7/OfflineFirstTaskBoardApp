//
//  RepositoryTests.swift
//  OfflineFirstTaskBoard
//
//  Created by Kanagasabapathy on 15.08.26.
//


import Foundation
import Testing
@testable import OfflineFirstTaskBoard

@Suite("Repository Tests")
struct RepositoryTests {
    private let stack: PersistenceController
    private let store: TaskStore
    private let api: MockTaskAPI

    init() {
        let stack = PersistenceController(inMemory: true)
        self.stack = stack
        self.store = CoreDataTaskStore(stack: stack)
        self.api = MockTaskAPI()
    }

    @Test("create is local first")
    func createIsLocalFirst() async throws {
        
        let repo = TaskRepositoryImpl(store: store, api: api)
        let task = try await repo.create(
            title: "Main Screen",
            description: "Create new UI and add navigation logic",
            status: .todo)

        #expect(task.syncStatus == .pending)
        #expect(task.existsOnRemote == false)
        #expect(try await store.fetchTasks().count == 1)
        #expect(try await api.fetchAll().isEmpty)
    }

    @Test("move changes status and destination sortOrder")
    func moveUpdatesColumn() async throws {
        
        let repo = TaskRepositoryImpl(store: store, api: api)
        let task = try await repo.create(title: "A", description: "", status: .todo)
        let moved = try await repo.move(id: task.id, to: .done)

        #expect(moved.status == .done)
        #expect(moved.sortOrder == 0)
        #expect(moved.syncStatus == .pending)
        #expect(try await api.fetchAll().isEmpty)
    }

    @Test("reorder rewrites 0...n-1")
    func reorderRewritesOrder() async throws {
        let repo = TaskRepositoryImpl(store: store, api: MockTaskAPI())
        let a = try await repo.create(title: "A", description: "", status: .todo)
        let b = try await repo.create(title: "B", description: "", status: .todo)
        let c = try await repo.create(title: "C", description: "", status: .todo)
        let reordered = try await repo.reorder(
            in: .todo,
            fromOffsets: IndexSet(integer: 0),
            toOffset: 3
        )

        #expect(reordered.map(\.id) == [b.id, c.id, a.id])
        #expect(reordered.map(\.sortOrder) == [0, 1, 2])
        #expect(reordered.allSatisfy { $0.syncStatus == .pending })
    }

    @Test("delete pending create drops locally and never hits API")
    func deletePendingCreateDrops() async throws {
        
        let repo = TaskRepositoryImpl(store: store, api: api)
        let task = try await repo.create(title: "Temp", description: "", status: .todo)
        try await repo.delete(task.id)

        #expect(try await store.fetchTasks().isEmpty)
        #expect(try await api.fetchAll().isEmpty)
    }

    @Test("delete synced row tombstones locally")
    func deleteSyncedMarksDeleted() async throws {
        
        let repo = TaskRepositoryImpl(store: store, api: api)
        var task = try await repo.create(title: "Synced", description: "", status: .todo)
        task.existsOnRemote = true
        task.syncStatus = .synced

        try await store.upsert(task)

        try await repo.delete(task.id)

        let rows = try await store.fetchTasks()

        #expect(rows.count == 1)
        #expect(rows[0].isDeleted)
        #expect(rows[0].syncStatus == .pending)
        #expect(rows[0].existsOnRemote)
        #expect(try await repo.loadTasks().isEmpty)
        #expect(try await api.fetchAll().isEmpty)
    }

    @Test("loadTasks hydrates from API when local is empty")
    func loadHydratesWhenEmpty() async throws {
        
        let remote = TaskItem(
            id: UUID(),
            title: "From remote",
            taskDescription: "",
            status: .todo,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0),
            sortOrder: 0,
            syncStatus: .synced,
            isDeleted: false,
            existsOnRemote: true
        )

        try await api.create(remote)
        let repo = TaskRepositoryImpl(store: store, api: api)

        let loaded = try await repo.loadTasks()

        #expect(loaded.map(\.id) == [remote.id])
        #expect(loaded[0].existsOnRemote)
        #expect(loaded[0].syncStatus == .synced)
        #expect(try await store.fetchTasks().count == 1)
    }

    @Test("sync pushes pending create")
    func syncPushesCreate() async throws {
        let repo = TaskRepositoryImpl(store: store, api: api)
        let task = try await repo.create(title: "Push Me", description: "", status: .todo)

        try await repo.sync()

        let remote = try await api.fetchAll()
        #expect(remote.map(\.id) == [task.id])

        let local = try await store.fetchTasks()
        #expect(local[0].syncStatus == .synced)
        #expect(local[0].existsOnRemote)
    }

    @Test("sync failure leaves row failed")
    func syncFailureMarksFailed() async throws {
        let repo = TaskRepositoryImpl(store: store, api: api)
        _ = try await repo.create(title: "Fail", description: "", status: .todo)
        await api.setShouldFail(true)

        await #expect(throws: MockTaskAPIError.forcedFailure) {
            try await repo.sync()
        }

        let local = try await store.fetchTasks()
        #expect(local[0].syncStatus == .failed)
        #expect(local[0].existsOnRemote == false)
    }
}
