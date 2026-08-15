//
//  TaskCard.swift
//  OfflineFirstTaskBoard
//
//  Created by Kanagasabapathy on 15.08.26.
//

import SwiftUI

struct TaskCard: View {
    let task: TaskItem
    var onRetry: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title).foregroundStyle(.primary)
                if !task.taskDescription.isEmpty {
                    Text(task.taskDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            syncGlyph
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
