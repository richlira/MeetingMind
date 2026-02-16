//
//  ProviderConfig.swift
//  MeetingMind
//

import Foundation

enum ProviderConfig {
    /// Creates the active transcription provider based on user selection.
    static func makeTranscriptionProvider() -> any TranscriptionProvider {
        let selection = ProviderSelection.transcriptionProvider

        if selection == .speechAnalyzer && DeviceCapability.canUseSpeechAnalyzer {
            return SpeechAnalyzerProvider()
        }

        // Default / fallback: Whisper cloud
        let apiKey = KeychainManager.apiKey(for: .openAIAPIKey)
        return WhisperProvider(apiKey: apiKey)
    }

    /// Creates the active AI provider based on user selection.
    static func makeAIProvider() -> any AIProvider {
        let selection = ProviderSelection.aiProvider

        if selection == .foundation && DeviceCapability.canUseFoundationModels {
            return FoundationProvider()
        }

        // Default / fallback: Claude cloud
        let apiKey = KeychainManager.apiKey(for: .anthropicAPIKey)
        return ClaudeProvider(apiKey: apiKey)
    }
}
