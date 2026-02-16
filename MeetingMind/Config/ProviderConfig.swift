//
//  ProviderConfig.swift
//  MeetingMind
//

import Foundation

enum ProviderConfig {
    /// Creates the active transcription provider.
    /// Phase 1: Whisper API (cloud)
    /// Phase 2: SpeechAnalyzer (on-device)
    static func makeTranscriptionProvider() -> any TranscriptionProvider {
        let apiKey = KeychainManager.apiKey(for: .openAIAPIKey)
        return WhisperProvider(apiKey: apiKey)
    }

    /// Creates the active AI provider.
    /// Phase 1: Claude API (cloud)
    /// Phase 2: Foundation Models (on-device)
    static func makeAIProvider() -> any AIProvider {
        let apiKey = KeychainManager.apiKey(for: .anthropicAPIKey)
        return ClaudeProvider(apiKey: apiKey)
    }
}
