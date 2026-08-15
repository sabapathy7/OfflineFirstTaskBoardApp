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
    @State private var viewModel: BoardViewModel
    @State private var editor: EditorRoute?
    @State private var selectedColumn = TaskStatus.todo

    init(viewModel: BoardViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SyncBanner(
                    title: viewModel.banner.isEmpty ? "Sync Now" : viewModel.banner,
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

                column(selectedColumn)
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
            }
            .sheet(item: $editor) { route in
                EditorSheet(task: {
                    if case .edit(let task) = route { return task }
                    return nil
                }()) { title, detail, status in
                    switch route {
                    case .create:
                        await viewModel.create(title: title, description: detail, status: status)
                    case .edit(let task):
                        await viewModel.edit(task, title: title, description: detail, status: status)
                    }
                }
            }
            .task {
                await viewModel.load()
            }
        }
    }

    private func column(_ status: TaskStatus) -> some View {
        List {
            Section(status.label) {
                ForEach(viewModel.tasks(in: status)) { task in
                    Button {
                        editor = .edit(task)
                    } label: {
                        TaskCard(task: task) {
                            Task { await viewModel.syncNow() }
                        }
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button("Delete", role: .destructive) {
                            Task { await viewModel.delete(task) }
                        }
                        if let next = status.next {
                            Button("Move") {
                                Task { await viewModel.move(task, to: next) }
                            }
                            .tint(.blue)
                        }
                    }
                    .swipeActions(edge: .leading) {
                        if let previous = status.previous {
                            Button("Back") {
                                Task { await viewModel.move(task, to: previous) }
                            }
                            .tint(.indigo)
                        }
                    }
                }
                .onMove { source, dest in
                    Task { await viewModel.reorder(in: status, fromOffsets: source, toOffset: dest) }
                }
            }
        }
    }
}
