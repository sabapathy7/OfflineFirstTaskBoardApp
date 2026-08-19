//
//  ArchiveView.swift
//  OfflineFirstTaskBoard
//
//  Created by Kanagasabapathy on 19.08.26.
//

import SwiftUI

struct ArchiveView: View {
    let tasks: [TaskItem]
    let onRestore: (TaskItem) -> Void
    let onRetry: () -> Void

    var body: some View {
        List {
            ForEach(tasks) { task in
                TaskCard(task: task, onRetry: onRetry)
                    .swipeActions(edge: .trailing) {
                        Button("Restore") { onRestore(task) }
                            .tint(.blue)
                    }
            }
        }
        .overlay {
            if tasks.isEmpty {
                ContentUnavailableView("No archived tasks", systemImage: "archivebox")
            }
        }
        .navigationTitle("Archive")
        .navigationBarTitleDisplayMode(.inline)
    }
}
