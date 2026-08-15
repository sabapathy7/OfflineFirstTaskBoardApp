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
}

nonisolated extension TaskEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<TaskEntity> {
        NSFetchRequest<TaskEntity>(entityName: "TaskEntity")
    }
}
