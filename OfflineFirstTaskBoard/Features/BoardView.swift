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

    init(viewModel: BoardViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                SyncBanner(title: viewModel.banner.isEmpty ? "Sync Now" : viewModel.banner) {
                    Task { await viewModel.syncNow() }
                }

                TabView {
                    column(.todo)
                    column(.inProgress)
                    column(.done)
                }
                .tabViewStyle(.page)
            }
            .navigationTitle("Board")
            .toolbar {
                #if DEBUG
                ToolbarItem(placement: .topBarLeading) {
                    Toggle("Offline", isOn: forceOffline)
                }
                #endif

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
                    Task {
                        switch route {
                        case .create:
                            await viewModel.create(title: title, description: detail, status: status)
                        case .edit(let task):
                            await viewModel.edit(task, title: title, description: detail, status: status)
                        }
                    }
                }
            }
            .task {
                await viewModel.load()
            }
        }
    }

    private var forceOffline: Binding<Bool> {
        Binding(
            get: { viewModel.api.isForcedOffline },
            set: { viewModel.api.isForcedOffline = $0 }
        )
    }

    private func column(_ status: TaskStatus) -> some View {
        List {
            Section(status.label) {
                ForEach(viewModel.tasks(in: status)) { task in
                    TaskCard(
                        task: task,
                        onOpen: { editor = .edit(task) },
                        onDelete: { Task { await viewModel.delete(task) } },
                        onMoveNext: status.next.map { next in
                            { Task { await viewModel.move(task, to: next) } }
                        },
                        onMoveBack: status.previous.map { previous in
                            { Task { await viewModel.move(task, to: previous) } }
                        },
                        onRetry: { Task { await viewModel.syncNow() } }
                    )
                }
                .onMove { source, dest in
                    Task { await viewModel.reorder(in: status, fromOffsets: source, toOffset: dest) }
                }
            }
        }
    }
}
