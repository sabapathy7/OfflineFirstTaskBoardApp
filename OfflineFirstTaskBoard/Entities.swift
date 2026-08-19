//
//  Entities.swift
//  OfflineFirstTaskBoard
//
//  Created by Kanagasabapathy on 15.08.26.
//

import CoreData
import Foundation

@objc(TaskEntity)
nonisolated public final class TaskEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var taskDescription: String?
    @NSManaged public var status: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var sortOrder: Int64
    @NSManaged public var syncStatus: String?
    @NSManaged public var hasDeleted: Bool
    @NSManaged public var existsOnRemote: Bool
    @NSManaged public var hasArchived: Bool
    @NSManaged public var subtasks: Set<SubTaskEntity>
}

nonisolated extension TaskEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<TaskEntity> {
        NSFetchRequest<TaskEntity>(entityName: "TaskEntity")
    }
}

@objc(SubTaskEntity)
nonisolated public final class SubTaskEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var subTaskDescription: String?
    @NSManaged public var status: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var sortOrder: Int64
    @NSManaged public var syncStatus: String?
    @NSManaged public var hasDeleted: Bool
    @NSManaged public var existsOnRemote: Bool
    @NSManaged public var subTaskStatus: String?
    @NSManaged public var task: TaskEntity?
}

nonisolated extension SubTaskEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<SubTaskEntity> {
        NSFetchRequest<SubTaskEntity>(entityName: "SubTaskEntity")
    }
}
