//
//  SyncBanner.swift
//  OfflineFirstTaskBoard
//
//  Created by Kanagasabapathy on 15.08.26.
//

import SwiftUI

struct SyncBanner: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .frame(maxWidth: .infinity)
            .padding(8)
    }
}

#Preview {
    SyncBanner(title: "Sync Now") {
        
    }
}
