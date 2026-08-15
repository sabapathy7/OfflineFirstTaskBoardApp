//
//  EditorSheet.swift
//  OfflineFirstTaskBoard
//
//  Created by Kanagasabapathy on 15.08.26.
//

import SwiftUI

struct EditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var detail = ""
    @State private var status = TaskStatus.todo
    let onSave: (String, String, TaskStatus) -> Void

    init(task: TaskItem?, onSave: @escaping (String, String, TaskStatus) -> Void) {
        _title = State(initialValue: task?.title ?? "")
        _detail = State(initialValue: task?.taskDescription ?? "")
        _status = State(initialValue: task?.status ?? .todo)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextField("Detail", text: $detail)
                Picker("Action", selection: $status) {
                    Text("To Do").tag(TaskStatus.todo)
                    Text("In Progress").tag(TaskStatus.inProgress)
                    Text("Done").tag(TaskStatus.done)
                }
            }
            .navigationTitle(title.isEmpty ? "New task" : "Edit task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        onSave(trimmed, detail, status)
                        dismiss()
                    }
                }
            }
        }
    }
}
