//
//  FirebaseTaskAPI.swift
//  OfflineFirstTaskBoard
//
//  Created by Kanagasabapathy on 15.08.26.
//

import Foundation
import FirebaseFirestore

nonisolated enum FirebaseTaskAPIError: Error, Sendable {
    case invalidDocument
}

nonisolated final class FirebaseTaskAPI: TaskAPI, @unchecked Sendable {
    private let db: Firestore
    private let collection: CollectionReference

    init(db: Firestore = Firestore.firestore()) {
        let settings = FirestoreSettings()
        settings.cacheSettings = MemoryCacheSettings()
        db.settings = settings
        self.db = db
        collection = db.collection("boards").document("demo").collection("tasks")
    }

    private static func data(from task: TaskItem) -> [String: Any] {
        [
            "title": task.title,
            "taskDescription": task.taskDescription,
            "status": task.status.rawValue,
            "createdAt": Timestamp(date: task.createdAt),
            "updatedAt": Timestamp(date: task.updatedAt),
            "sortOrder": task.sortOrder,
            "isArchived": task.isArchived,
            "subtasks": task.subtasks.filter { !$0.isDeleted }.map { Self.subtaskData(from: $0) }
        ]
    }

    private static func subtaskData(from item: SubtaskItem) -> [String: Any] {
        [
            "id": item.id.uuidString,
            "title": item.title,
            "taskDescription": item.taskDescription,
            "status": item.status.rawValue,
            "subtaskStatus": item.subtaskStatus.rawValue,
            "createdAt": Timestamp(date: item.createdAt),
            "updatedAt": Timestamp(date: item.updatedAt),
            "sortOrder": item.sortOrder
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
                        sortOrder: (data["sortOrder"] as? NSNumber)?.intValue ?? 0,
                        syncStatus: .synced,
                        isDeleted: false,
                        existsOnRemote: true,
                        subtasks: subtasks(from: data, taskID: id),
                        isArchived: data["isArchived"] as? Bool ?? false)

    }

    private static func subtasks(from data: [String: Any], taskID: UUID) -> [SubtaskItem] {
        let raw = data["subtasks"] as? [[String: Any]] ?? []
        return raw.compactMap { dict in
            guard
                let idString = dict["id"] as? String,
                let id = UUID(uuidString: idString),
                let title = dict["title"] as? String,
                let statusRaw = dict["status"] as? String,
                let status = TaskStatus(rawValue: statusRaw)
            else {
                return nil
            }
            let created = (dict["createdAt"] as? Timestamp)?.dateValue() ?? Date(timeIntervalSince1970: 0)
            let updated = (dict["updatedAt"] as? Timestamp)?.dateValue() ?? created
            let subtaskStatus = (dict["subtaskStatus"] as? String).flatMap(SubtaskStatus.init(rawValue:)) ?? .matching(status)
            return SubtaskItem(
                id: id,
                title: title,
                taskDescription: dict["taskDescription"] as? String ?? "",
                status: status,
                subtaskStatus: subtaskStatus,
                createdAt: created,
                updatedAt: updated,
                sortOrder: (dict["sortOrder"] as? NSNumber)?.intValue ?? 0,
                syncStatus: .synced,
                isDeleted: false,
                existsOnRemote: true,
                taskID: taskID
            )
        }
        .sorted { $0.sortOrder < $1.sortOrder }
    }

    func fetchAll() async throws -> [TaskItem] {
        let snapshot = try await collection.getDocuments(source: .server)
        return try snapshot.documents.map(Self.task)
    }
    
    func create(_ task: TaskItem) async throws {
        try await collection.document(task.id.uuidString).setData(Self.data(from: task))
    }

    /// Write-if-newer inside a transaction: a device pushing an older edit is
    /// a no-op, so the server always keeps the latest edit regardless of which
    /// device synced first. The pull that follows the push repairs the loser.
    func update(_ task: TaskItem) async throws {
        let ref = collection.document(task.id.uuidString)
        _ = try await db.runTransaction { transaction, errorPointer in
            let snapshot: DocumentSnapshot
            do {
                snapshot = try transaction.getDocument(ref)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
            guard !Self.isRemote(snapshot, newerThan: task.updatedAt) else { return nil }
            transaction.setData(Self.data(from: task), forDocument: ref)
            return nil
        }
    }

    /// Delete only if nobody edited the task after the tombstone was written;
    /// a newer remote edit survives and the deleting device pulls it back.
    func delete(id: UUID, updatedAt: Date) async throws {
        let ref = collection.document(id.uuidString)
        _ = try await db.runTransaction { transaction, errorPointer in
            let snapshot: DocumentSnapshot
            do {
                snapshot = try transaction.getDocument(ref)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
            guard snapshot.exists, !Self.isRemote(snapshot, newerThan: updatedAt) else { return nil }
            transaction.deleteDocument(ref)
            return nil
        }
    }

    // ListenerRegistration.remove() is thread-safe but the type is not
    // Sendable-annotated; the box carries it into onTermination.
    private final class ListenerBox: @unchecked Sendable {
        let listener: ListenerRegistration
        init(_ listener: ListenerRegistration) { self.listener = listener }
    }

    var remoteChanges: AsyncStream<Void> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { [collection] continuation in
            let box = ListenerBox(collection.addSnapshotListener { snapshot, _ in
                // hasPendingWrites is the local echo of our own write.
                guard let snapshot, !snapshot.metadata.hasPendingWrites else { return }
                continuation.yield()
            })
            continuation.onTermination = { _ in box.listener.remove() }
        }
    }

    // 0.5 ms tolerance absorbs Date <-> Timestamp rounding.
    private static func isRemote(_ snapshot: DocumentSnapshot, newerThan date: Date) -> Bool {
        guard let stamp = snapshot.data()?["updatedAt"] as? Timestamp else { return false }
        return stamp.dateValue().timeIntervalSince(date) > 0.0005
    }
}
