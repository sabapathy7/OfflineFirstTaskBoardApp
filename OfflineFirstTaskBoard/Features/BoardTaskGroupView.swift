//
//  BoardTaskGroupView.swift
//  OfflineFirstTaskBoard
//
//  Created by Kanagasabapathy on 19.08.26.
//

import SwiftUI

struct BoardTaskGroupView: View {
    let section: BoardSection
    let onOpenTask: () -> Void
    let onOpenSubtask: (SubtaskItem) -> Void
    let onDeleteTask: () -> Void
    let onArchiveTask: () -> Void
    let onMoveTask: (TaskStatus) -> Void
    let onDeleteSubtask: (SubtaskItem) -> Void
    let onMoveSubtask: (SubtaskItem, TaskStatus) -> Void
    let onRetry: () -> Void
    let onToggleStatus: (SubtaskItem, SubtaskStatus) -> Void

    var body: some View {
        Section(section.task.title) {
            if section.showsTask {
                taskRow
            }
            ForEach(section.subtasks) { subtask in
                subtaskRow(subtask)
            }
        }
    }

    private var taskRow: some View {
        Button(action: onOpenTask) {
            TaskCard(task: section.task, onRetry: onRetry)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("Delete", role: .destructive, action: onDeleteTask)
            if let next = section.task.status.next {
                Button("Move") { onMoveTask(next) }
                    .tint(.blue)
            }
            Button("Archive", action: onArchiveTask)
                .tint(.orange)
        }
        .swipeActions(edge: .leading) {
            if let previous = section.task.status.previous {
                Button("Back") { onMoveTask(previous) }
                    .tint(.indigo)
            }
        }
        .accessibilityHint("Parent task")
    }

    private func subtaskRow(_ subtask: SubtaskItem) -> some View {
        Button {
            onOpenSubtask(subtask)
        } label: {
            SubtaskCard(subtask: subtask, parentTitle: section.task.title, onRetry: onRetry, onToggleStatus: onToggleStatus)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("Delete", role: .destructive) {
                onDeleteSubtask(subtask)
            }
            if let next = subtask.status.next {
                Button("Move") { onMoveSubtask(subtask, next) }
                    .tint(.blue)
            }
            Button("Archive") {
                onArchiveTask()
            }
        }
        .swipeActions(edge: .leading) {
            if let previous = subtask.status.previous {
                Button("Back") { onMoveSubtask(subtask, previous) }
                    .tint(.indigo)
            }
        }
    }
}
