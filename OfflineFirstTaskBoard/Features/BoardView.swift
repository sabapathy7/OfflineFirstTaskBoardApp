//
//  BoardView.swift
//  OfflineFirstTaskBoard
//
//  Created by Kanagasabapathy on 15.08.26.
//

import SwiftUI

private enum EditorRoute: Identifiable {
    case create
    case edit(TaskItem)

    var id: String {
        switch self {
        case .create: "create"
        case .edit(let task): task.id.uuidString
        }
    }
}

struct BoardView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: BoardViewModel
    @State private var editor: EditorRoute?
    @State private var selectedColumn = TaskStatus.todo

    init(viewModel: BoardViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Sync is automatic; the banner is status plus a manual retry.
                SyncBanner(
                    title: viewModel.banner.isEmpty ? "Sync" : viewModel.banner,
                    isFailed: viewModel.banner == "Sync failed",
                    isOffline: viewModel.banner == "Offline"
                ) {
                    Task { await viewModel.syncNow() }
                }

                Picker("Column", selection: $selectedColumn) {
                    ForEach(TaskStatus.allCases, id: \.self) { status in
                        Text(status.label).tag(status)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                BoardColumnView(
                    status: selectedColumn,
                    sections: viewModel.sections(in: selectedColumn),
                    onOpenTask: { editor = .edit($0) },
                    onDeleteTask: { task in Task { await viewModel.delete(task) } },
                    onArchiveTask: { task in Task { await viewModel.archive(task) }},
                    onMoveTask: { task, status in Task { await viewModel.move(task, to: status) } },
                    onDeleteSubtask: { task, subtask in
                        Task { await viewModel.deleteSubtask(subtask, of: task) }
                    },
                    onMoveSubtask: { task, subtask, status in
                        Task { await viewModel.moveSubtask(subtask, of: task, to: status) }
                    },
                    onToggleSubtaskCompletion: { task, subtask in
                        Task { await viewModel.toggleSubtaskCompletion(subtask, of: task) }
                    },
                    onReorder: { source, dest in
                        Task { await viewModel.reorder(in: selectedColumn, fromOffsets: source, toOffset: dest) }
                    },
                    onRetry: { Task { await viewModel.syncNow() } }
                )
            }
            .navigationTitle("Board")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add", systemImage: "plus") {
                        editor = .create
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        ArchiveView(
                            tasks: viewModel.archivedTasks,
                            onRestore: { task in Task { await viewModel.restore(task) } },
                            onRetry: { Task { await viewModel.syncNow() } }
                        )
                    } label: {
                        Label("Archive", systemImage: "archivebox")
                    }
                }
            }
            .sheet(item: $editor, content: editorSheet)
            .task {
                await viewModel.load()
                await viewModel.observeRemoteChanges()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await viewModel.syncNow() }
                }
            }
        }
    }

    private func editorSheet(for route: EditorRoute) -> EditorSheet {
        EditorSheet(task: {
            if case .edit(let task) = route { return task }
            return nil
        }()) { title, detail, status, subtasks in
            switch route {
            case .create:
                await viewModel.create(title: title, description: detail, status: status, subtasks: subtasks)
            case .edit(let task):
                await viewModel.edit(task, title: title, description: detail, status: status, subtasks: subtasks)
            }
        }
    }
}
