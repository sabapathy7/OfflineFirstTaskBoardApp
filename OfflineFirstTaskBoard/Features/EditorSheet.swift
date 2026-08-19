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
    @State private var drafts: [DraftSubtask] = []
    @State private var newSubtaskTitle = ""
    @State private var newSubtaskDetail = ""
    @State private var isSaving = false

    private let isEditing: Bool
    private let parentID: UUID?
    private let originals: [UUID: SubtaskItem]
    let onSave: (String, String, TaskStatus, [SubtaskItem]) async -> Void

    private enum Field: Hashable {
        case title
        case detail
        case newSubtask
        case newSubtaskDetail
    }

    init(task: TaskItem?, onSave: @escaping (String, String, TaskStatus, [SubtaskItem]) async -> Void) {
        let existing = task?.subtasks.filter { !$0.isDeleted } ?? []
        _title = State(initialValue: task?.title ?? "")
        _detail = State(initialValue: task?.taskDescription ?? "")
        _status = State(initialValue: task?.status ?? .todo)
        _drafts = State(initialValue: existing.map {
            DraftSubtask(id: $0.id, title: $0.title, detail: $0.taskDescription, status: $0.status)
        })
        self.isEditing = task != nil
        self.parentID = task?.id
        self.originals = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
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
                    .submitLabel(.next)
                    .onSubmit { focusedField = .newSubtask }
                Picker("Column", selection: $status) {
                    Text("To Do").tag(TaskStatus.todo)
                    Text("In Progress").tag(TaskStatus.inProgress)
                    Text("Done").tag(TaskStatus.done)
                }

                Section("Subtasks") {
                    // One row per draft so swipe-to-delete maps to a subtask,
                    // not to an individual field.
                    ForEach($drafts) { $draft in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Subtask title", text: $draft.title)
                            TextField("Subtask detail", text: $draft.detail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Picker("Column", selection: $draft.status) {
                                Text("To Do").tag(TaskStatus.todo)
                                Text("In Progress").tag(TaskStatus.inProgress)
                                Text("Done").tag(TaskStatus.done)
                            }
                        }
                    }
                    .onDelete(perform: deleteDrafts)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("New subtask", text: $newSubtaskTitle)
                                .focused($focusedField, equals: .newSubtask)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .newSubtaskDetail }
                            Button("Add", action: addSubtask)
                                .disabled(newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        TextField("New subtask detail", text: $newSubtaskDetail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .focused($focusedField, equals: .newSubtaskDetail)
                            .submitLabel(.done)
                            .onSubmit(addSubtask)
                    }
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
                    Button("Save", action: save)
                        .disabled(trimmedTitle.isEmpty || isSaving)
                }
            }
            .onChange(of: status) { _, newStatus in
                for index in drafts.indices {
                    drafts[index].status = newStatus
                }
            }
        }
    }

    private func addSubtask() {
        let trimmed = newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        drafts.append(
            DraftSubtask(
                id: UUID(),
                title: trimmed,
                detail: newSubtaskDetail.trimmingCharacters(in: .whitespacesAndNewlines),
                status: status
            )
        )
        newSubtaskTitle = ""
        newSubtaskDetail = ""
        focusedField = .newSubtask
    }

    private func deleteDrafts(at offsets: IndexSet) {
        drafts.remove(atOffsets: offsets)
    }

    private func save() {
        let trimmed = trimmedTitle
        guard !trimmed.isEmpty, !isSaving else { return }
        focusedField = nil
        isSaving = true
        let subtasks = makeSubtasks()
        Task {
            await onSave(trimmed, detail, status, subtasks)
            dismiss()
        }
    }

    private func makeSubtasks() -> [SubtaskItem] {
        drafts.enumerated().compactMap { index, draft in
            let trimmed = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedDetail = draft.detail.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            if var original = originals[draft.id] {
                original.title = trimmed
                original.taskDescription = trimmedDetail
                original.status = draft.status
                original.subtaskStatus = .matching(draft.status)
                original.sortOrder = index
                original.syncStatus = .pending
                original.updatedAt = .now
                return original
            }
            return SubtaskItem(
                title: trimmed,
                taskDescription: trimmedDetail,
                status: draft.status,
                sortOrder: index,
                taskID: parentID ?? originals.values.first?.taskID ?? UUID()
            )
        }
    }
}

private struct DraftSubtask: Identifiable, Equatable {
    let id: UUID
    var title: String
    var detail: String
    var status: TaskStatus
}
