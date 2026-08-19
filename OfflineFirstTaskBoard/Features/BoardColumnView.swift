//
//  BoardColumnView.swift
//  OfflineFirstTaskBoard
//
//  Created by Kanagasabapathy on 19.08.26.
//

import SwiftUI

struct BoardColumnView: View {
    let status: TaskStatus
    let sections: [BoardSection]
    let onOpenTask: (TaskItem) -> Void
    let onDeleteTask: (TaskItem) -> Void
    let onArchiveTask: (TaskItem) -> Void
    let onMoveTask: (TaskItem, TaskStatus) -> Void
    let onDeleteSubtask: (TaskItem, SubtaskItem) -> Void
    let onMoveSubtask: (TaskItem, SubtaskItem, TaskStatus) -> Void
    let onToggleSubtaskCompletion: (TaskItem, SubtaskItem) -> Void
    let onReorder: (IndexSet, Int) -> Void
    let onRetry: () -> Void

    private var parentSections: [BoardSection] {
        sections.filter(\.showsTask)
    }

    private var childOnlySections: [BoardSection] {
        sections.filter { !$0.showsTask }
    }

    var body: some View {
        List {
            ForEach(parentSections) { section in
                group(section)
            }
            .onMove(perform: onReorder)

            ForEach(childOnlySections) { section in
                group(section)
            }
        }
    }

    private func group(_ section: BoardSection) -> some View {
        BoardTaskGroupView(
            section: section,
            onOpenTask: { onOpenTask(section.task) },
            onOpenSubtask: { _ in onOpenTask(section.task) },
            onDeleteTask: { onDeleteTask(section.task) },
            onArchiveTask: { onArchiveTask(section.task) },
            onMoveTask: { status in onMoveTask(section.task, status) },
            onDeleteSubtask: { subtask in onDeleteSubtask(section.task, subtask) },
            onMoveSubtask: { subtask, status in onMoveSubtask(section.task, subtask, status) },
            onRetry: onRetry,
            onToggleStatus: { subtask, _ in
                onToggleSubtaskCompletion(section.task, subtask)
            }
        )
    }
}
