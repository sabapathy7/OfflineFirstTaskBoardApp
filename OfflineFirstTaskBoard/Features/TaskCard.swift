//
//  TaskCard.swift
//  OfflineFirstTaskBoard
//
//  Created by Kanagasabapathy on 15.08.26.
//

import SwiftUI

struct TaskCard: View {
    let task: TaskItem
    var onOpen: () -> Void
    var onDelete: () -> Void
    var onMoveNext: (() -> Void)?
    var onMoveBack: (() -> Void)?
    var onRetry: () -> Void

    var body: some View {
        HStack {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title).foregroundStyle(.primary)
                    if !task.taskDescription.isEmpty {
                        Text(task.taskDescription)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            syncGlyph
        }
        .swipeActions(edge: .trailing) {
            Button("Delete", role: .destructive, action: onDelete)
            if let onMoveNext {
                Button("Move", action: onMoveNext)
            }
        }
        .swipeActions(edge: .leading) {
            if let onMoveBack {
                Button("Back", action: onMoveBack)
            }
        }
    }

    @ViewBuilder
    private var syncGlyph: some View {
        switch task.syncStatus {
        case .pending:
            Text("●")
                .foregroundStyle(.orange)
                .accessibilityLabel("Pending sync")
        case .failed:
            Button("!", action: onRetry)
                .foregroundStyle(.red)
                .accessibilityLabel("Sync failed, tap to retry")
        case .synced:
            EmptyView()
        }
    }
}
