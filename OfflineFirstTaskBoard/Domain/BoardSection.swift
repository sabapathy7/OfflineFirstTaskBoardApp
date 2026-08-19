//
//  BoardSection.swift
//  OfflineFirstTaskBoard
//
//  Created by Kanagasabapathy on 19.08.26.
//

import Foundation

nonisolated struct BoardSection: Equatable, Sendable, Identifiable {
    var id: UUID { task.id }
    let task: TaskItem
    let showsTask: Bool
    let subtasks: [SubtaskItem]
}
