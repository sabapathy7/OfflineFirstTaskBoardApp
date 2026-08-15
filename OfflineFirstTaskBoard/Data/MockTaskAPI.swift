//
//  MockTaskAPI.swift
//  OfflineFirstTaskBoard
//
//  Created by Kanagasabapathy on 15.08.26.
//

import Foundation

nonisolated enum MockTaskAPIError: Error, Sendable {
    case forcedFailure
}
actor MockTaskAPI: TaskAPI {
    private var storage: [UUID: TaskItem] = [:]
    var shouldFail = false

    func setShouldFail(_ value: Bool) {
        shouldFail = value
    }

    func fetchAll() async throws -> [TaskItem] {
        if shouldFail {
            throw MockTaskAPIError.forcedFailure
        }
        return Array(storage.values)
    }
    
    func create(_ task: TaskItem) async throws {
        if shouldFail {
            throw MockTaskAPIError.forcedFailure
        }
        storage[task.id] = task
    }
    
    func update(_ task: TaskItem) async throws {
        if shouldFail {
            throw MockTaskAPIError.forcedFailure
        }
        storage[task.id] = task
    }
    
    func delete(id: UUID) async throws {
        if shouldFail {
            throw MockTaskAPIError.forcedFailure
        }
        storage.removeValue(forKey: id)
    }
}
