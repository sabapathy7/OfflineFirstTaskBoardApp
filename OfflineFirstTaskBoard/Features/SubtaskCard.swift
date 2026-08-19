//
//  SubtaskCard.swift
//  OfflineFirstTaskBoard
//
//  Created by Kanagasabapathy on 19.08.26.
//

import SwiftUI

struct SubtaskCard: View {
    let subtask: SubtaskItem
    let parentTitle: String
    var onRetry: () -> Void
    var onToggleStatus: (SubtaskItem, SubtaskStatus) -> Void

    var body: some View {
        HStack {
            Image(systemName: subtask.subtaskStatus == .complete ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(subtask.subtaskStatus == .complete ? Color.green : Color.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(subtask.title).foregroundStyle(.primary)
                if !subtask.taskDescription.isEmpty {
                    Text(subtask.taskDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                onToggleStatus(subtask, subtask.subtaskStatus == .complete ? .incomplete : .complete)
            } label: {
                Image(systemName: subtask.subtaskStatus == .complete ? "checkmark.circle.fill" : "circle")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(subtask.subtaskStatus == .complete
                                    ? "Mark incomplete" : "Mark complete")
            syncGlyph
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let state = subtask.subtaskStatus == .complete ? "complete" : "incomplete"
        return "\(subtask.title), subtask of \(parentTitle), \(state)"
    }

    @ViewBuilder
    private var syncGlyph: some View {
        switch subtask.syncStatus {
        case .pending:
            Text("●")
                .foregroundStyle(.orange)
                .accessibilityLabel("Pending sync")
        case .failed:
            Button("Retry sync", systemImage: "exclamationmark", action: onRetry)
                .labelStyle(.iconOnly)
                .foregroundStyle(.red)
        case .synced:
            EmptyView()
        }
    }
}
