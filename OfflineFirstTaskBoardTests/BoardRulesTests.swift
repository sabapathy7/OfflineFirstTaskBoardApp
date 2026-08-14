//
//  BoardRulesTests.swift
//  OfflineFirstTaskBoard
//
//  Created by Kanagasabapathy on 15.08.26.
//

import Foundation
import Testing
@testable import OfflineFirstTaskBoard

@Suite("Board Rules Tests")
struct BoardRulesTests {

    private func makeTask(sortOrder: Int = 0, isDeleted: Bool = false) -> TaskItem {
        TaskItem(id: UUID(),
                 title: "Task",
                 taskDescription: "",
                 status: .todo,
                 createdAt: Date(timeIntervalSince1970: 0),
                 updatedAt: Date(timeIntervalSince1970: 0),
                 sortOrder: sortOrder,
                 syncStatus: .pending,
                 isDeleted: isDeleted,
                 existsOnRemote: false)
    }

    @Test("append sort order skips deleted")
    func append() {
        #expect(BoardRules.appendingSortOrder(in: []) == 0)

        let twoLive = [makeTask(sortOrder: 0), makeTask(sortOrder: 1)]
        #expect(BoardRules.appendingSortOrder(in: twoLive) == 2)

        let oneLiveOneDeleted = [
            makeTask(sortOrder: 0),
            makeTask(sortOrder: 1, isDeleted: true)
        ]

        #expect(BoardRules.appendingSortOrder(in: oneLiveOneDeleted) == 1)
    }

    @Test("move appends to destination and marks pending")
    func moveTodos()  {
        let now = Date(timeIntervalSince1970: 1_000)
        let destination = [makeTask(sortOrder: 0), makeTask(sortOrder: 1)]
        let task = makeTask(sortOrder: 0)

        let moved = BoardRules.moving(task,
                                      to: .inProgress,
                                      destinationColumn: destination,
                                      now: now)

        #expect(moved.status == .inProgress)
        #expect(moved.sortOrder == 2)
        #expect(moved.syncStatus == .pending)
        #expect(moved.updatedAt == now)
        #expect(moved.id == task.id)
    }

    @Test("reorder rewrites 0...n-1")
    func reorderTodos()  {
        let now = Date(timeIntervalSince1970: 1_000)
        let a = makeTask(sortOrder: 0)
        let b = makeTask(sortOrder: 1)
        let c = makeTask(sortOrder: 2)


        let reordered = BoardRules.reordering([a, b, c], fromOffsets: IndexSet(integer: 0), toOffset: 3, now: now)

        #expect(reordered.map(\.id) == [b.id, c.id, a.id])
        #expect(reordered.map(\.sortOrder) == [0, 1, 2])
        #expect(reordered.allSatisfy { $0.syncStatus == .pending })
        #expect(reordered.allSatisfy { $0.updatedAt == now })
    }

    @Test("never on remote drops locally")
    func deleteLocally()  {
        let task = makeTask()
        #expect(BoardRules.delete(for: task) == .dropLocally)
    }

    @Test("on remote marks deleted even if pending")
    func markDeleted()  {
        var task = makeTask()
        task.existsOnRemote = true
        task.syncStatus = .pending

        #expect(BoardRules.delete(for: task) == .markDeleted)
    }

    @Test("Mark Deleted")
    func markDelete()  {
        let now = Date(timeIntervalSince1970: 1_000)
        var task = makeTask()
        task.existsOnRemote = true
        task.syncStatus = .synced

        let updated = BoardRules.markDelete(for: task, now: now)

        #expect(updated.isDeleted)
        #expect(updated.syncStatus == .pending)
        #expect(updated.updatedAt == now)
        #expect(updated.existsOnRemote)
        #expect(updated.id == task.id)
    }

    @Test("pull applies remote when local is missing")
    func pullWhenLocalMissing() {
        let remote = makeTask()
        #expect(BoardRules.shouldApplyRemote(remote, over: nil))
    }

    @Test("pull does not overwrite local pending")
    func pullSkipsLocalPending() {
        var local = makeTask()
        local.syncStatus = .pending
        let remote = makeTask()
        #expect(BoardRules.shouldApplyRemote(remote, over: local) == false)
    }

    @Test("pull applies remote when local is synced")
    func pullWhenLocalSynced() {
        var local = makeTask()
        local.existsOnRemote = true
        local.syncStatus = .synced
        let remote = makeTask()
        #expect(BoardRules.shouldApplyRemote(remote, over: local))
    }
}
