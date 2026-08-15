//
//  SyncBanner.swift
//  OfflineFirstTaskBoard
//
//  Created by Kanagasabapathy on 15.08.26.
//

import SwiftUI

struct SyncBanner: View {
    let title: String
    var isFailed = false
    var isOffline = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
                .padding(8)
        }
        .foregroundStyle(isFailed ? Color.red : (isOffline ? Color.orange : Color.primary))
        .background(isFailed ? Color.red.opacity(0.12) : Color.clear)
    }
}

#Preview {
    SyncBanner(title: "Sync Now") {}
}
