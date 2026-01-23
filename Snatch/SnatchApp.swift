//
//  SnatchApp.swift
//  Snatch
//
//  Created by Lia An on 1/23/26.
//

import SwiftUI

@main
struct SnatchApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
