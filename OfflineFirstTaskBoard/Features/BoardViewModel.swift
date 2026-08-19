//
//  BoardViewModel.swift
//  OfflineFirstTaskBoard
//
//  Created by Kanagasabapathy on 15.08.26.
//

import Observation
import Foundation
import Network

@Observable
final class BoardViewModel {
    var tasks: [TaskItem] = []
    var banner: String = ""
    var isSyncing = false
    var isOffline = false

    /// A sync was requested while one was running; run one more pass so a
    /// remote change arriving mid-sync is never dropped.
    private var syncQueued = false
    private let repository: TaskRepository
    private let pathMonitor = NWPathMonitor()
    private let pathQueue = DispatchQueue(label: "OfflineFirstTaskBoard.path")

    init(repository: TaskRepository) {
        self.repository = repository
        startPathMonitor()
    }

    func tasks(in status: TaskStatus) -> [TaskItem] {
        tasks
            .filter { BoardRules.isOnBoard($0) && $0.status == status }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var archivedTasks: [TaskItem] {
        tasks.filter(\.isArchived)
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func sections(in status: TaskStatus) -> [BoardSection] {
        BoardRules.sections(from: tasks, in: status)
    }

    func load() async {
        do {
            tasks = try await repository.loadTasks()
            if tasks.isEmpty { try await seed() }
            await syncNow()
        } catch {
            banner = "Sync failed"
        }
    }

    func create(title: String, description: String, status: TaskStatus, subtasks: [SubtaskItem] = []) async {
        do {
            _ = try await repository.create(title: title, description: description, status: status, subtasks: subtasks)
            tasks = try await repository.loadTasks()
            await syncNow()
        } catch {
            banner = "Save failed"
        }
    }

    func edit(_ task: TaskItem, title: String, description: String, status: TaskStatus, subtasks: [SubtaskItem]) async {
        do {
            _ = try await repository.edit(id: task.id, title: title, description: description, status: status, subtasks: subtasks)
            tasks = try await repository.loadTasks()
            await syncNow()
        } catch {
            banner = "Save failed"
        }
    }

    func move(_ task: TaskItem, to status: TaskStatus) async {
        do {
            _ = try await repository.move(id: task.id, to: status)
            tasks = try await repository.loadTasks()
            await syncNow()
        } catch {
            banner = "Save failed"
        }
    }

    func reorder(in status: TaskStatus, fromOffsets: IndexSet, toOffset: Int) async {
        do {
            _ = try await repository.reorder(in: status, fromOffsets: fromOffsets, toOffset: toOffset)
            tasks = try await repository.loadTasks()
            await syncNow()
        } catch {
            banner = "Save failed"
        }
    }

    func delete(_ task: TaskItem) async {
        do {
            try await repository.delete(task.id)
            tasks = try await repository.loadTasks()
            await syncNow()
        } catch {
            banner = "Save failed"
        }
    }

    func archive(_ task: TaskItem) async {
        do {
            try await repository.archiving(task.id)
            tasks = try await repository.loadTasks()
            await syncNow()
        } catch {
            banner = "Save failed"
        }
    }

    func restore(_ task: TaskItem) async {
        do {
            try await repository.restoring(task.id)
            tasks = try await repository.loadTasks()
            await syncNow()
        } catch {
            banner = "Save failed"
        }
    }

    func moveSubtask(_ subtask: SubtaskItem, of task: TaskItem, to status: TaskStatus) async {
        do {
            _ = try await repository.moveSubtask(taskId: task.id, subtaskId: subtask.id, to: status)
            tasks = try await repository.loadTasks()
            await syncNow()
        } catch {
            banner = "Save failed"
        }
    }

    func toggleSubtaskCompletion(_ subtask: SubtaskItem, of task: TaskItem) async {
        do {
            _ = try await repository.toggleSubtaskCompletion(taskId: task.id, subtaskId: subtask.id)
            tasks = try await repository.loadTasks()
            await syncNow()
        } catch {
            banner = "Save failed"
        }
    }

    func deleteSubtask(_ subtask: SubtaskItem, of task: TaskItem) async {
        do {
            try await repository.deleteSubtask(taskId: task.id, subtaskId: subtask.id)
            tasks = try await repository.loadTasks()
            await syncNow()
        } catch {
            banner = "Save failed"
        }
    }

    /// Runs until the board and the server agree. Requests that arrive while
    /// a sync is in flight are coalesced into one extra pass.
    func syncNow() async {
        if isOffline {
            banner = "Offline"
            return
        }
        if isSyncing {
            syncQueued = true
            return
        }
        isSyncing = true
        banner = "Syncing"
        repeat {
            syncQueued = false
            do {
                try await repository.sync()
                tasks = try await repository.loadTasks()
                banner = isOffline ? "Offline" : "Last synced"
            } catch {
                tasks = (try? await repository.loadTasks()) ?? tasks
                banner = isOffline ? "Offline" : "Sync failed"
            }
        } while syncQueued && !isOffline
        isSyncing = false
    }

    /// Pulls every remote change as it happens, so edits made on another
    /// device land here without anyone tapping the banner. Runs for the life
    /// of the view's `.task` and stops when that task is cancelled.
    func observeRemoteChanges() async {
        for await _ in repository.remoteChanges {
            await syncNow()
        }
    }

    private func startPathMonitor() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            let offline = path.status != .satisfied
            Task { @MainActor in
                self?.applyPath(offline: offline)
            }
        }
        pathMonitor.start(queue: pathQueue)
    }

    private func applyPath(offline: Bool) {
        let wasOffline = isOffline
        isOffline = offline
        if offline {
            banner = "Offline"
            return
        }
        if banner == "Offline" {
            banner = ""
        }
        // Back online: push what queued up while offline, pull what we missed.
        if wasOffline {
            Task {
                await syncNow()
            }
        }
    }

    private func seed() async throws {
        _ = try await repository.create(
            title: "Task1",
            description: "Parent task",
            status: .todo,
            subtasks: [
                SubtaskItem(title: "Subtask1", status: .todo, sortOrder: 0, taskID: UUID()),
                SubtaskItem(title: "Subtask2", status: .todo, sortOrder: 1, taskID: UUID())
            ]
        )
        _ = try await repository.create(title: "Build the board", description: "In Progress seed", status: .inProgress)
        _ = try await repository.create(title: "Write the README", description: "Done seed", status: .done)
        tasks = try await repository.loadTasks()
    }

}
