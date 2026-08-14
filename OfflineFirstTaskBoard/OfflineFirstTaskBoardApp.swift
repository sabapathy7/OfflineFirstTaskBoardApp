////
//  OfflineFirstTaskBoardApp.swift
//  OfflineFirstTaskBoard
//
//  Created on 14.08.26.
//


import SwiftUI
import CoreData

@main
struct OfflineFirstTaskBoardApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
