//
//  CoreDataTaskStore.swift
//  OfflineFirstTaskBoard
//
//  Created by Kanagasabapathy on 15.08.26.
//

import CoreData

nonisolated protocol TaskStore: Sendable {
    func fetchTasks() async throws -> [TaskItem]
    func upsert(_ taskItem: TaskItem) async throws
    func delete(id: UUID) async throws
}

nonisolated final class CoreDataTaskStore: TaskStore {

    private let stack: PersistenceController
    init(stack: PersistenceController) {
        self.stack = stack
    }
    func fetchTasks() async throws -> [TaskItem] {
        let context = stack.newBackgroundContext()
        return try await context.perform {
            let request = TaskEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \TaskEntity.createdAt, ascending: false)]
            request.relationshipKeyPathsForPrefetching = [#keyPath(TaskEntity.subtasks)]
            return try context.fetch(request).compactMap(Self.makeTask)
        }
    }

    private static func makeTask(_ entity: TaskEntity) -> TaskItem? {
        guard let id = entity.id,
              let createdAt = entity.createdAt,
              let updatedAt = entity.updatedAt,
              let status = entity.status.flatMap(TaskStatus.init(rawValue:)),
              let syncStatus = entity.syncStatus.flatMap(SyncStatus.init(rawValue:)) else {
            return nil
        }
        return TaskItem(id: id,
                        title: entity.title ?? "",
                        taskDescription: entity.taskDescription ?? "",
                        status: status,
                        createdAt: createdAt,
                        updatedAt: updatedAt,
                        sortOrder: Int(entity.sortOrder),
                        syncStatus: syncStatus,
                        isDeleted: entity.hasDeleted,
                        existsOnRemote: entity.existsOnRemote,
                        subtasks: entity.subtasks.compactMap { makeSubtask($0, taskID: id) }.sorted { $0.sortOrder < $1.sortOrder },
                        isArchived: entity.hasArchived)
    }

    private static func makeSubtask(_ entity: SubTaskEntity, taskID: UUID) -> SubtaskItem? {
        guard let id = entity.id,
              let createdAt = entity.createdAt,
              let updatedAt = entity.updatedAt,
              let status = entity.status.flatMap(TaskStatus.init(rawValue:)),
              let syncStatus = entity.syncStatus.flatMap(SyncStatus.init(rawValue:)) else {
            return nil
        }
        let subtaskStatus = entity.subTaskStatus.flatMap(SubtaskStatus.init(rawValue:)) ?? .matching(status)
        return SubtaskItem(
            id: id,
            title: entity.title ?? "",
            taskDescription: entity.subTaskDescription ?? "",
            status: status,
            subtaskStatus: subtaskStatus,
            createdAt: createdAt,
            updatedAt: updatedAt,
            sortOrder: Int(entity.sortOrder),
            syncStatus: syncStatus,
            isDeleted: entity.hasDeleted,
            existsOnRemote: entity.existsOnRemote,
            taskID: entity.task?.id ?? taskID
        )
    }

    func upsert(_ taskItem: TaskItem) async throws {
        let context = stack.newBackgroundContext()
        try await context.perform {
            let request = TaskEntity.fetchRequest()
            request.predicate = NSPredicate(format: "%K == %@", #keyPath(TaskEntity.id), taskItem.id as CVarArg)
            request.fetchLimit = 1
            request.relationshipKeyPathsForPrefetching = [#keyPath(TaskEntity.subtasks)]

            let entity = try context.fetch(request).first ?? TaskEntity(context: context)
            Self.apply(taskItem, to: entity)
            try context.save()
        }
    }

    private static func apply(_ taskItem: TaskItem, to entity: TaskEntity) {
        entity.id = taskItem.id
        entity.title = taskItem.title
        entity.taskDescription = taskItem.taskDescription
        entity.status = taskItem.status.rawValue
        entity.createdAt = taskItem.createdAt
        entity.updatedAt = taskItem.updatedAt
        entity.sortOrder = Int64(taskItem.sortOrder)
        entity.syncStatus = taskItem.syncStatus.rawValue
        entity.hasDeleted = taskItem.isDeleted
        entity.existsOnRemote = taskItem.existsOnRemote
        entity.hasArchived = taskItem.isArchived
        applySubtasks(taskItem.subtasks, to: entity)
    }

    private static func applySubtasks(_ subtasks: [SubtaskItem], to entity: TaskEntity) {
        guard let context = entity.managedObjectContext else { return }

        let existing = Dictionary(uniqueKeysWithValues: entity.subtasks.compactMap { row -> (UUID, SubTaskEntity)? in
            guard let id = row.id else { return nil }
            return (id, row)
        })
        let keep = Set(subtasks.map(\.id))

        for item in subtasks {
            let row = existing[item.id] ?? SubTaskEntity(context: context)
            apply(item, to: row)
            row.task = entity
        }

        for (id, row) in existing where !keep.contains(id) {
            context.delete(row)
        }
    }

    private static func apply(_ item: SubtaskItem, to entity: SubTaskEntity) {
        entity.id = item.id
        entity.title = item.title
        entity.subTaskDescription = item.taskDescription
        entity.status = item.status.rawValue
        entity.subTaskStatus = item.subtaskStatus.rawValue
        entity.createdAt = item.createdAt
        entity.updatedAt = item.updatedAt
        entity.sortOrder = Int64(item.sortOrder)
        entity.syncStatus = item.syncStatus.rawValue
        entity.hasDeleted = item.isDeleted
        entity.existsOnRemote = item.existsOnRemote
    }

    func delete(id: UUID) async throws {
        let context = stack.newBackgroundContext()
        try await context.perform {
            let request = TaskEntity.fetchRequest()
            request.predicate = NSPredicate(format: "%K == %@", #keyPath(TaskEntity.id) ,id as CVarArg)

            request.fetchLimit = 1
            guard let entity = try context.fetch(request).first else {
                return
            }
            context.delete(entity)
            try context.save()
        }
    }
}
