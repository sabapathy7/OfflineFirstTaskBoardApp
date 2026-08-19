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

    private func makeSubtask(
        title: String = "Subtask1",
        status: TaskStatus = .todo,
        sortOrder: Int = 0,
        taskID: UUID = UUID()
    ) -> SubtaskItem {
        SubtaskItem(
            title: title,
            status: status,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0),
            sortOrder: sortOrder,
            taskID: taskID
        )
    }

    private func makeTask(
        title: String = "Task1",
        sortOrder: Int = 0,
        isDeleted: Bool = false,
        status: TaskStatus = .todo,
        subtasks: [SubtaskItem] = [],
        isArchived: Bool = false,
        existsOnRemote: Bool = false,
        syncStatus: SyncStatus = .pending
    ) -> TaskItem {
        TaskItem(
            id: UUID(),
            title: title,
            taskDescription: "",
            status: status,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0),
            sortOrder: sortOrder,
            syncStatus: syncStatus,
            isDeleted: isDeleted,
            existsOnRemote: existsOnRemote,
            subtasks: subtasks,
            isArchived: isArchived
        )
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

        let oneLiveOneArchived = [
            makeTask(sortOrder: 0),
            makeTask(sortOrder: 1, isArchived: true)
        ]
        #expect(BoardRules.appendingSortOrder(in: oneLiveOneArchived) == 1)
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

    @Test("parent move sets every subtask to the destination column", arguments: [TaskStatus.inProgress, TaskStatus.done])
    func parentMoveCascades(destination: TaskStatus) {
        let now = Date(timeIntervalSince1970: 1_000)
        let parentID = UUID()
        let task = makeTask(
            subtasks: [
                makeSubtask(title: "Subtask1", status: .todo, sortOrder: 0, taskID: parentID),
                makeSubtask(title: "Subtask2", status: .todo, sortOrder: 1, taskID: parentID)
            ]
        )

        let moved = BoardRules.moving(task, to: destination, destinationColumn: [], now: now)

        #expect(moved.status == destination)
        #expect(moved.subtasks.map(\.status) == [destination, destination])
        #expect(moved.subtasks.map(\.subtaskStatus) == [.matching(destination), .matching(destination)])
        #expect(moved.subtasks.allSatisfy { $0.syncStatus == .pending })
        #expect(moved.subtasks.allSatisfy { $0.updatedAt == now })
    }

    @Test("moving one subtask leaves the parent and siblings")
    func moveOneSubtask() {
        let now = Date(timeIntervalSince1970: 1_000)
        let parentID = UUID()
        let first = makeSubtask(title: "Subtask1", status: .todo, sortOrder: 0, taskID: parentID)
        let second = makeSubtask(title: "Subtask2", status: .todo, sortOrder: 1, taskID: parentID)
        let task = makeTask(subtasks: [first, second])

        let updated = BoardRules.movingSubtask(in: task, id: first.id, to: .inProgress, now: now)

        #expect(updated.status == .todo)
        let moved = updated.subtasks.first { $0.id == first.id }
        let sibling = updated.subtasks.first { $0.id == second.id }
        #expect(moved?.status == .inProgress)
        #expect(moved?.subtaskStatus == .incomplete)
        #expect(sibling?.status == .todo)
        #expect(updated.syncStatus == .pending)
    }

    @Test("in progress column lists a child under the parent name")
    func childOnlySectionUsesParentTitle() {
        let parentID = UUID()
        let child = makeSubtask(title: "Subtask1", status: .inProgress, taskID: parentID)
        let task = makeTask(title: "Task1", subtasks: [child])

        let todo = BoardRules.sections(from: [task], in: .todo)
        let progress = BoardRules.sections(from: [task], in: .inProgress)

        #expect(todo.count == 1)
        #expect(todo[0].showsTask)
        #expect(todo[0].task.title == "Task1")
        #expect(todo[0].subtasks.isEmpty)

        #expect(progress.count == 1)
        #expect(progress[0].showsTask == false)
        #expect(progress[0].task.title == "Task1")
        #expect(progress[0].subtasks.map(\.title) == ["Subtask1"])
    }

    @Test("parent move to in progress puts the task and its subtasks in that column")
    func parentMoveFillsColumnSection() {
        let parentID = UUID()
        let task = makeTask(
            title: "Task1",
            subtasks: [
                makeSubtask(title: "Subtask1", status: .todo, taskID: parentID),
                makeSubtask(title: "Subtask2", status: .todo, sortOrder: 1, taskID: parentID)
            ]
        )
        let moved = BoardRules.moving(task, to: .inProgress, destinationColumn: [], now: Date(timeIntervalSince1970: 1_000))
        let progress = BoardRules.sections(from: [moved], in: .inProgress)

        #expect(progress.count == 1)
        #expect(progress[0].showsTask)
        #expect(progress[0].task.title == "Task1")
        #expect(progress[0].subtasks.map(\.title) == ["Subtask1", "Subtask2"])
    }

    @Test("sections omit archived tasks")
    func sectionsSkipArchived() {
        let live = makeTask(title: "Live")
        let archived = makeTask(title: "Archived", isArchived: true)

        let sections = BoardRules.sections(from: [live, archived], in: .todo)

        #expect(sections.map(\.task.title) == ["Live"])
        #expect(BoardRules.sections(from: [archived], in: .todo).isEmpty)
    }

    @Test("archived parent does not leak subtasks onto the board")
    func archivedParentHidesChildren() {
        let parentID = UUID()
        let child = makeSubtask(title: "Subtask1", status: .inProgress, taskID: parentID)
        let archived = makeTask(
            title: "Task1",
            subtasks: [child],
            isArchived: true
        )

        #expect(BoardRules.sections(from: [archived], in: .todo).isEmpty)
        #expect(BoardRules.sections(from: [archived], in: .inProgress).isEmpty)
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

    @Test("archive locally marks pending without claiming remote")
    func archiveLocally() {
        let now = Date(timeIntervalSince1970: 1_000)
        let task = makeTask(status: .inProgress, existsOnRemote: false, syncStatus: .pending)

        let updated = BoardRules.archiveTask(for: task, now: now)

        #expect(updated.isArchived)
        #expect(updated.existsOnRemote == false)
        #expect(updated.isDeleted == false)
        #expect(updated.status == .inProgress)
        #expect(updated.syncStatus == .pending)
        #expect(updated.updatedAt == now)
        #expect(updated.id == task.id)
    }

    @Test("archive of a server-backed row keeps existsOnRemote")
    func archiveServerBacked() {
        let now = Date(timeIntervalSince1970: 1_000)
        let task = makeTask(status: .done, existsOnRemote: true, syncStatus: .synced)

        let updated = BoardRules.archiveTask(for: task, now: now)

        #expect(updated.isArchived)
        #expect(updated.existsOnRemote)
        #expect(updated.isDeleted == false)
        #expect(updated.status == .done)
        #expect(updated.syncStatus == .pending)
        #expect(updated.updatedAt == now)
    }

    @Test("restore locally unarchives without claiming remote")
    func restoreLocally() {
        let now = Date(timeIntervalSince1970: 1_000)
        let task = makeTask(
            status: .todo,
            isArchived: true,
            existsOnRemote: false,
            syncStatus: .synced
        )

        let updated = BoardRules.restoreTask(for: task, destinationColumn: [], now: now)

        #expect(updated.isArchived == false)
        #expect(updated.existsOnRemote == false)
        #expect(updated.status == .todo)
        #expect(updated.sortOrder == 0)
        #expect(updated.syncStatus == .pending)
        #expect(updated.updatedAt == now)
        #expect(updated.id == task.id)
    }

    @Test("restore appends to the live destination column")
    func restoreAppendsToColumn() {
        let now = Date(timeIntervalSince1970: 1_000)
        let live = makeTask(sortOrder: 0)
        let archived = makeTask(sortOrder: 0, isArchived: true)

        let updated = BoardRules.restoreTask(for: archived, destinationColumn: [live], now: now)

        #expect(updated.isArchived == false)
        #expect(updated.sortOrder == 1)
        #expect(updated.syncStatus == .pending)
        #expect(updated.updatedAt == now)
    }

    @Test("restore of a server-backed archived row keeps existsOnRemote")
    func restoreServerBacked() {
        let now = Date(timeIntervalSince1970: 1_000)
        let task = makeTask(
            status: .done,
            isArchived: true,
            existsOnRemote: true,
            syncStatus: .synced
        )

        let updated = BoardRules.restoreTask(for: task, destinationColumn: [], now: now)

        #expect(updated.isArchived == false)
        #expect(updated.existsOnRemote)
        #expect(updated.status == .done)
        #expect(updated.sortOrder == 0)
        #expect(updated.syncStatus == .pending)
        #expect(updated.updatedAt == now)
    }

    @Test("archive keeps column status", arguments: TaskStatus.allCases)
    func archiveKeepsStatus(status: TaskStatus) {
        let updated = BoardRules.archiveTask(
            for: makeTask(status: status, existsOnRemote: true, syncStatus: .synced),
            now: Date(timeIntervalSince1970: 1_000)
        )

        #expect(updated.status == status)
        #expect(updated.isArchived)
    }

    @Test("pull applies remote archive when local is synced")
    func pullAppliesRemoteArchive() {
        let local = makeTask(existsOnRemote: true, syncStatus: .synced)
        let remote = makeTask(isArchived: true, existsOnRemote: true, syncStatus: .synced)

        #expect(BoardRules.shouldApplyRemote(remote, over: local))
    }

    @Test("pull does not overwrite pending local archive")
    func pullSkipsPendingLocalArchive() {
        let local = makeTask(isArchived: true, existsOnRemote: true, syncStatus: .pending)
        let remote = makeTask(isArchived: false, existsOnRemote: true, syncStatus: .synced)

        #expect(BoardRules.shouldApplyRemote(remote, over: local) == false)
    }

    @Test("pull does not overwrite pending local restore")
    func pullSkipsPendingLocalRestore() {
        let local = makeTask(isArchived: false, existsOnRemote: true, syncStatus: .pending)
        let remote = makeTask(isArchived: true, existsOnRemote: true, syncStatus: .synced)

        #expect(BoardRules.shouldApplyRemote(remote, over: local) == false)
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

    @Test("pull does not overwrite local failed")
    func pullSkipsLocalFailed() {
        var local = makeTask()
        local.syncStatus = .failed
        let remote = makeTask()
        #expect(BoardRules.shouldApplyRemote(remote, over: local) == false)
    }
}
