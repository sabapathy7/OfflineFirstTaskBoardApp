////
//  OfflineFirstTaskBoardApp.swift
//  OfflineFirstTaskBoard
//
//  Created on 14.08.26.
//


import SwiftUI
import FirebaseCore

@main
struct OfflineFirstTaskBoardApp: App {
    private let api: FirebaseTaskAPI
    private let repository: TaskRepository

    init() {
        FirebaseApp.configure()
        let api = FirebaseTaskAPI()
        self.api = api
        let store = CoreDataTaskStore(stack: PersistenceController.shared)
        self.repository = TaskRepositoryImpl(store: store, api: api)
    }

    var body: some Scene {
        WindowGroup {
            BoardView(viewModel: BoardViewModel(repository: repository, api: api))
        }
    }
}
