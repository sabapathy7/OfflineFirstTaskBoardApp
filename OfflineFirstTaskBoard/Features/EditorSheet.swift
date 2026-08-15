//
//  EditorSheet.swift
//  OfflineFirstTaskBoard
//
//  Created by Kanagasabapathy on 15.08.26.
//

import SwiftUI

struct EditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    @State private var title = ""
    @State private var detail = ""
    @State private var status = TaskStatus.todo
    @State private var isSaving = false

    private let isEditing: Bool
    let onSave: (String, String, TaskStatus) async -> Void

    private enum Field: Hashable {
        case title
        case detail
    }

    init(task: TaskItem?, onSave: @escaping (String, String, TaskStatus) async -> Void) {
        _title = State(initialValue: task?.title ?? "")
        _detail = State(initialValue: task?.taskDescription ?? "")
        _status = State(initialValue: task?.status ?? .todo)
        self.isEditing = task != nil
        self.onSave = onSave
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                    .focused($focusedField, equals: .title)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .detail }
                TextField("Detail", text: $detail)
                    .focused($focusedField, equals: .detail)
                    .submitLabel(.done)
                    .onSubmit { save() }
                Picker("Column", selection: $status) {
                    Text("To Do").tag(TaskStatus.todo)
                    Text("In Progress").tag(TaskStatus.inProgress)
                    Text("Done").tag(TaskStatus.done)
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle(isEditing ? "Edit task" : "New task")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(trimmedTitle.isEmpty || isSaving)
                }
            }
        }
    }

    private func save() {
        let trimmed = trimmedTitle
        guard !trimmed.isEmpty, !isSaving else { return }
        focusedField = nil
        isSaving = true
        Task {
            await onSave(trimmed, detail, status)
            dismiss()
        }
    }
}
