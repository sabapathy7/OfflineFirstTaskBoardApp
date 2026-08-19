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

    @Test("archive is local first")
    func archiveIsLocalFirst() async throws {
        let repo = TaskRepositoryImpl(store: store, api: api)
        let task = try await repo.create(title: "Archiving", description: "", status: .todo)

        try await repo.archiving(task.id)

        let rows = try await store.fetchTasks()
        #expect(rows.count == 1)
        #expect(rows[0].isArchived)
        #expect(rows[0].status == .todo)
        #expect(rows[0].syncStatus == .pending)
        #expect(rows[0].existsOnRemote == false)
        #expect(try await api.fetchAll().isEmpty)
        let loaded = try await repo.loadTasks()
        #expect(loaded.count == 1)
        #expect(loaded[0].isArchived)
        #expect(BoardRules.sections(from: loaded, in: .todo).isEmpty)
    }

    @Test("restore is local first")
    func restoreIsLocalFirst() async throws {
        let repo = TaskRepositoryImpl(store: store, api: api)
        let task = try await repo.create(title: "Restoring", description: "", status: .inProgress)

        try await repo.archiving(task.id)
        try await repo.restoring(task.id)

        let rows = try await store.fetchTasks()
        #expect(rows.count == 1)
        #expect(rows[0].isArchived == false)
        #expect(rows[0].status == .inProgress)
        #expect(rows[0].syncStatus == .pending)
        #expect(try await api.fetchAll().isEmpty)
    }

    @Test("sync pushes local archive to server")
    func syncPushesLocalArchive() async throws {
        let repo = TaskRepositoryImpl(store: store, api: api)
        let task = try await repo.create(title: "Archive me", description: "", status: .todo)

        try await repo.archiving(task.id)
        try await repo.sync()

        let remote = try await api.fetchAll()
        #expect(remote.map(\.id) == [task.id])
        #expect(remote[0].isArchived)

        let local = try await store.fetchTasks()
        #expect(local[0].isArchived)
        #expect(local[0].syncStatus == .synced)
        #expect(local[0].existsOnRemote)
    }

    @Test("archive of synced row stays local until sync updates server")
    func archiveSyncedThenPush() async throws {
        let repo = TaskRepositoryImpl(store: store, api: api)
        var task = try await repo.create(title: "Synced archive", description: "", status: .done)
        task.existsOnRemote = true
        task.syncStatus = .synced
        try await store.upsert(task)
        try await api.create(task)

        try await repo.archiving(task.id)

        let beforeSync = try await api.fetchAll()
        #expect(beforeSync[0].isArchived == false)
        #expect(try await store.fetchTasks()[0].isArchived)
        #expect(try await store.fetchTasks()[0].syncStatus == .pending)

        try await repo.sync()

        let remote = try await api.fetchAll()
        #expect(remote[0].isArchived)

        let local = try await store.fetchTasks()
        #expect(local[0].isArchived)
        #expect(local[0].syncStatus == .synced)
        #expect(local[0].existsOnRemote)
    }

    @Test("restore of synced archived row stays local until sync updates server")
    func restoreSyncedThenPush() async throws {
        let repo = TaskRepositoryImpl(store: store, api: api)
        var task = try await repo.create(title: "Synced restore", description: "", status: .todo)
        task.existsOnRemote = true
        task.syncStatus = .synced
        task.isArchived = true
        try await store.upsert(task)
        try await api.create(task)

        try await repo.restoring(task.id)

        let beforeSync = try await api.fetchAll()
        #expect(beforeSync[0].isArchived)
        #expect(try await store.fetchTasks()[0].isArchived == false)
        #expect(try await store.fetchTasks()[0].syncStatus == .pending)

        try await repo.sync()

        let remote = try await api.fetchAll()
        #expect(remote[0].isArchived == false)

        let local = try await store.fetchTasks()
        #expect(local[0].isArchived == false)
        #expect(local[0].syncStatus == .synced)
        #expect(local[0].existsOnRemote)
    }

    @Test("loadTasks hydrates archived task from API when local is empty")
    func loadHydratesArchivedFromServer() async throws {
        let remote = TaskItem(
            id: UUID(),
            title: "Archived remote",
            taskDescription: "",
            status: .done,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0),
            sortOrder: 0,
            syncStatus: .synced,
            isDeleted: false,
            existsOnRemote: true,
            isArchived: true
        )
        try await api.create(remote)
        let repo = TaskRepositoryImpl(store: store, api: api)

        let loaded = try await repo.loadTasks()

        #expect(loaded.map(\.id) == [remote.id])
        #expect(loaded[0].isArchived)
        #expect(loaded[0].existsOnRemote)
        #expect(loaded[0].syncStatus == .synced)
        #expect(try await store.fetchTasks()[0].isArchived)
    }

    @Test("sync keeps pending local archive over remote live task")
    func syncKeepsPendingLocalArchive() async throws {
        let id = UUID()
        let remote = TaskItem(
            id: id,
            title: "Live on server",
            taskDescription: "",
            status: .todo,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0),
            sortOrder: 0,
            syncStatus: .synced,
            isDeleted: false,
            existsOnRemote: true,
            isArchived: false
        )
        try await api.create(remote)

        var local = remote
        local.isArchived = true
        local.syncStatus = .pending
        try await store.upsert(local)

        let repo = TaskRepositoryImpl(store: store, api: api)
        try await repo.sync()

        #expect(try await store.fetchTasks()[0].isArchived)
        #expect(try await api.fetchAll()[0].isArchived)
    }

    @Test("sync keeps pending local restore over remote archive")
    func syncKeepsPendingLocalRestore() async throws {
        let id = UUID()
        let remote = TaskItem(
            id: id,
            title: "Archived on server",
            taskDescription: "",
            status: .todo,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0),
            sortOrder: 0,
            syncStatus: .synced,
            isDeleted: false,
            existsOnRemote: true,
            isArchived: true
        )
        try await api.create(remote)

        var local = remote
        local.isArchived = false
        local.syncStatus = .pending
        try await store.upsert(local)

        let repo = TaskRepositoryImpl(store: store, api: api)
        try await repo.sync()

        #expect(try await store.fetchTasks()[0].isArchived == false)
        #expect(try await api.fetchAll()[0].isArchived == false)
    }

    @Test("archiving unknown id throws")
    func archiveUnknownThrows() async {
        let repo = TaskRepositoryImpl(store: store, api: api)
        await #expect(throws: TaskRepositoryError.notFound) {
            try await repo.archiving(UUID())
        }
    }

    @Test("restoring unknown id throws")
    func restoreUnknownThrows() async {
        let repo = TaskRepositoryImpl(store: store, api: api)
        await #expect(throws: TaskRepositoryError.notFound) {
            try await repo.restoring(UUID())
        }
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
            existsOnRemote: true,
            isArchived: false
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

    @Test("synced delete then sync removes remote")
    func syncPushesTombstone() async throws {
        let repo = TaskRepositoryImpl(store: store, api: api)
        var task = try await repo.create(title: "Gone", description: "", status: .todo)
        task.existsOnRemote = true
        task.syncStatus = .synced
        try await store.upsert(task)
        try await api.create(task)

        try await repo.delete(task.id)
        try await repo.sync()

        #expect(try await api.fetchAll().isEmpty)
        #expect(try await store.fetchTasks().isEmpty)
    }

    @Test("sync keeps pending local title over remote")
    func syncKeepsPendingLocalTitle() async throws {
        let id = UUID()
        let remote = TaskItem(
            id: id,
            title: "Remote",
            taskDescription: "",
            status: .todo,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0),
            sortOrder: 0,
            syncStatus: .synced,
            isDeleted: false,
            existsOnRemote: true,
            isArchived: false
        )
        try await api.create(remote)

        var local = remote
        local.title = "Local"
        local.syncStatus = .pending
        try await store.upsert(local)

        let repo = TaskRepositoryImpl(store: store, api: api)
        try await repo.sync()

        let rows = try await store.fetchTasks()
        #expect(rows[0].title == "Local")
        #expect(try await api.fetchAll()[0].title == "Local")
    }

    @Test("move parent persists cascaded subtask columns")
    func moveParentCascadesStoredSubtasks() async throws {
        let repo = TaskRepositoryImpl(store: store, api: api)
        let task = try await repo.create(
            title: "Task1",
            description: "",
            status: .todo,
            subtasks: [
                SubtaskItem(title: "Subtask1", status: .todo, sortOrder: 0, taskID: UUID()),
                SubtaskItem(title: "Subtask2", status: .todo, sortOrder: 1, taskID: UUID())
            ]
        )

        let moved = try await repo.move(id: task.id, to: .inProgress)
        let stored = try #require(try await store.fetchTasks().first)

        #expect(moved.status == .inProgress)
        #expect(moved.subtasks.map(\.status) == [.inProgress, .inProgress])
        #expect(stored.subtasks.map(\.status) == [.inProgress, .inProgress])
        #expect(stored.subtasks.map(\.title) == ["Subtask1", "Subtask2"])
    }

    @Test("subtask detail survives store and sync round trip")
    func subtaskDetailRoundTrips() async throws {
        let repo = TaskRepositoryImpl(store: store, api: api)
        let task = try await repo.create(
            title: "Task1",
            description: "",
            status: .todo,
            subtasks: [
                SubtaskItem(title: "Subtask1", taskDescription: "Why it matters", status: .todo, sortOrder: 0, taskID: UUID())
            ]
        )

        let stored = try #require(try await store.fetchTasks().first)
        #expect(stored.subtasks.map(\.taskDescription) == ["Why it matters"])

        try await repo.sync()
        #expect(try await api.fetchAll()[0].subtasks.map(\.taskDescription) == ["Why it matters"])

        // Editing the detail alone marks the task pending again.
        var edited = try #require(task.subtasks.first)
        edited.taskDescription = "Rewritten"
        _ = try await repo.edit(id: task.id, title: task.title, description: "", status: .todo, subtasks: [edited])

        let after = try #require(try await store.fetchTasks().first)
        #expect(after.subtasks.map(\.taskDescription) == ["Rewritten"])
        #expect(after.syncStatus == .pending)
    }

    @Test("move subtask does not move the parent")
    func moveSubtaskLeavesParent() async throws {
        let repo = TaskRepositoryImpl(store: store, api: api)
        let task = try await repo.create(
            title: "Task1",
            description: "",
            status: .todo,
            subtasks: [
                SubtaskItem(title: "Subtask1", status: .todo, sortOrder: 0, taskID: UUID()),
                SubtaskItem(title: "Subtask2", status: .todo, sortOrder: 1, taskID: UUID())
            ]
        )
        let first = try #require(task.subtasks.first)

        let updated = try await repo.moveSubtask(taskId: task.id, subtaskId: first.id, to: .inProgress)
        let stored = try #require(try await store.fetchTasks().first)
        let moved = try #require(stored.subtasks.first { $0.id == first.id })
        let sibling = try #require(stored.subtasks.first { $0.id != first.id })

        #expect(updated.status == .todo)
        #expect(moved.status == .inProgress)
        #expect(sibling.status == .todo)
        #expect(stored.status == .todo)
    }
}
