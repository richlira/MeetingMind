//
//  MeetingMindApp.swift
//  MeetingMind
//
//  Created by Rich on 2/15/26.
//

import SwiftUI
import SwiftData

@main
struct MeetingMindApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Session.self,
            TranscriptSegment.self,
            Question.self,
            ChatMessage.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(sharedModelContainer)
    }
}
