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
    init() {
        let key = "hasLaunchedBefore"
        if !UserDefaults.standard.bool(forKey: key) {
            // Keychain items survive app deletion. Clear them on fresh install.
            KeychainManager.delete(key: .openAIAPIKey)
            KeychainManager.delete(key: .anthropicAPIKey)

            // Smart-default providers based on device capability
            if DeviceCapability.canUseSpeechAnalyzer {
                ProviderSelection.transcriptionProvider = .speechAnalyzer
            }
            if DeviceCapability.canUseFoundationModels {
                ProviderSelection.aiProvider = .foundation
            }

            UserDefaults.standard.set(true, forKey: key)
        }

        // Validate saved selections — capability may disappear after OS/settings changes
        if ProviderSelection.transcriptionProvider == .speechAnalyzer && !DeviceCapability.canUseSpeechAnalyzer {
            print("[MeetingMindApp] SpeechAnalyzer no longer available — resetting to Whisper")
            ProviderSelection.transcriptionProvider = .whisper
        }
        if ProviderSelection.aiProvider == .foundation && !DeviceCapability.canUseFoundationModels {
            print("[MeetingMindApp] FoundationModels no longer available — resetting to Claude")
            ProviderSelection.aiProvider = .claude
        }

        DeviceCapability.logCapabilities()
    }

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
