//
//  SnatchApp.swift
//  Snatch
//
//  Entry point. Sets up SwiftData container and the tab-based navigation.
//
//  PERFORMANCE STRATEGY:
//  - The app opens directly to HomeView (the blank paste area)
//  - HomeView has ZERO database queries on init - it's just a blank VStack
//  - WordListView and FlashcardView use @Query, but they're in separate tabs
//    so SwiftUI only initializes them when the user actually navigates there
//  - This gives us near-instant launch time
//
//  FUTURE: SwiftData + CloudKit sync for mac-phone sync (just add
//  a CloudKit container to the modelContainer configuration).
//

import SwiftUI
import SwiftData

@main
struct SnatchApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(for: [WordEntry.self, LanguageConfig.self])
    }
}

/// Tab-based navigation. HomeView loads immediately.
/// Other tabs are lazy - SwiftUI only creates them when selected.
struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 0: Home (paste area) - loads immediately, zero overhead
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "doc.on.clipboard")
                }
                .tag(0)

            // Tab 1: Word List - lazy loaded (only when user taps this tab)
            WordListView()
                .tabItem {
                    Label("Words", systemImage: "list.bullet")
                }
                .tag(1)

            // Tab 2: Flashcards - lazy loaded
            FlashcardView()
                .tabItem {
                    Label("Flashcards", systemImage: "rectangle.on.rectangle")
                }
                .tag(2)

            // Tab 3: Settings - lazy loaded
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(3)
        }
        .frame(minWidth: 600, minHeight: 450)
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [WordEntry.self, LanguageConfig.self], inMemory: true)
}
