//
//  BoardViewModel.swift
//  OfflineFirstTaskBoard
//
//  Created by Kanagasabapathy on 15.08.26.
//

import Observation
import Foundation

@Observable
final class BoardViewModel {
    var tasks: [TaskItem] = []
    var banner: String = ""
    var isSyncing = false

    private let repository: TaskRepository
    let api: FirebaseTaskAPI

    init(repository: TaskRepository, api: FirebaseTaskAPI) {
        self.repository = repository
        self.api = api
    }

    func tasks(in status: TaskStatus) -> [TaskItem] {
        tasks.filter { $0.status == status }.sorted { $0.sortOrder < $1.sortOrder }
    }

    func load() async {
        do {
            tasks = try await repository.loadTasks()
            if tasks.isEmpty { try await seed() }
            banner = "Load synced - locally"
        } catch {
            banner = "Load failed - retry"
        }
    }

    func create(title: String, description: String, status: TaskStatus) async {
        do {
            _ = try await repository.create(title: title, description: description, status: status)
            tasks = try await repository.loadTasks()
        } catch {
            banner = "Save failed"
        }
    }

    func edit(_ task: TaskItem, title: String, description: String, status: TaskStatus) async {
        _ = try? await repository.edit(id: task.id, title: title, description: description, status: status)
        tasks = (try? await repository.loadTasks()) ?? tasks
    }

    func move(_ task: TaskItem, to status: TaskStatus) async {
        _ = try? await repository.move(id: task.id, to: status)
        tasks = (try? await repository.loadTasks()) ?? tasks
    }

    func reorder(in status: TaskStatus, fromOffsets: IndexSet, toOffset: Int) async {
        _ = try? await repository.reorder(in: status, fromOffsets: fromOffsets, toOffset: toOffset)
        tasks = (try? await repository.loadTasks()) ?? tasks
    }

    func delete(_ task: TaskItem) async {
        _ = try? await repository.delete(task.id)
        tasks = (try? await repository.loadTasks()) ?? tasks
    }

    func syncNow() async {
        isSyncing = true
        banner = "Syncing"
        do {
            try await repository.sync()
            tasks = try await repository.loadTasks()
            banner = "Last synced"
        } catch {
            banner = "Sync failed - tap to retry"
        }
        isSyncing = false
    }

    private func seed() async throws {
        _ = try await repository.create(title: "Read the Brief", description: "To Do Seed", status: .todo)
        _ = try await repository.create(title: "Build the board", description: "In Progress seed", status: .inProgress)
        _ = try await repository.create(title: "Write the README", description: "Done seed", status: .done)
        tasks = try await repository.loadTasks()
    }

}
