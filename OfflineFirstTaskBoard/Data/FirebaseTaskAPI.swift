//
//  FirebaseTaskAPI.swift
//  OfflineFirstTaskBoard
//
//  Created by Kanagasabapathy on 15.08.26.
//

import Foundation
import FirebaseFirestore

nonisolated enum FirebaseTaskAPIError: Error, Sendable {
    case forcedOffline
    case invalidDocument
}

nonisolated final class FirebaseTaskAPI: TaskAPI, @unchecked Sendable {
    var isForcedOffline = false

    private let collection: CollectionReference

    init(db: Firestore = Firestore.firestore()) {
        let settings = FirestoreSettings()
        settings.cacheSettings = MemoryCacheSettings()
        db.settings = settings
        collection = db.collection("boards").document("demo").collection("tasks")
    }

    private func checkOnline() throws {
        if isForcedOffline {
            throw FirebaseTaskAPIError.forcedOffline
        }
    }

    private static func data(from task: TaskItem) -> [String: Any] {
        [
            "title": task.title,
            "taskDescription": task.taskDescription,
            "status": task.status.rawValue,
            "createdAt": Timestamp(date: task.createdAt),
            "updatedAt": Timestamp(date: task.updatedAt),
            "sortOrder": task.sortOrder
        ]
    }

    private static func task(from doc: QueryDocumentSnapshot) throws -> TaskItem {
        let data = doc.data()
        guard
            let id = UUID(uuidString: doc.documentID),
            let title = data["title"] as? String,
            let statusRaw = data["status"] as? String,
            let status = TaskStatus(rawValue: statusRaw),
            let created = (data["createdAt"] as? Timestamp)?.dateValue(),
            let updated = (data["updatedAt"] as? Timestamp)?.dateValue()
        else {
            throw FirebaseTaskAPIError.invalidDocument
        }

        return TaskItem(id: id,
                        title: title,
                        taskDescription: data["taskDescription"] as? String ?? "",
                        status: status,
                        createdAt: created,
                        updatedAt: updated,
                        sortOrder: data["sortOrder"] as? Int ?? 0,
                        syncStatus: .synced,
                        isDeleted: false,
                        existsOnRemote: true)

    }

    func fetchAll() async throws -> [TaskItem] {
        try checkOnline()
        let snapshot = try await collection.getDocuments()
        return try snapshot.documents.map(Self.task)
    }
    
    func create(_ task: TaskItem) async throws {
        try checkOnline()
        try await collection.document(task.id.uuidString).setData(Self.data(from: task))
    }
    
    func update(_ task: TaskItem) async throws {
        try checkOnline()
        try await collection.document(task.id.uuidString).setData(Self.data(from: task))
    }
    
    func delete(id: UUID) async throws {
        try checkOnline()
        try await collection.document(id.uuidString).delete()
    }
}
