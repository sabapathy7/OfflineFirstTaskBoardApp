////
//  OfflineFirstTaskBoardApp.swift
//  OfflineFirstTaskBoard
//
//  Created on 14.08.26.
//


import SwiftUI
import CoreData
import FirebaseCore

@main
struct OfflineFirstTaskBoardApp: App {
    let persistenceController = PersistenceController.shared

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
