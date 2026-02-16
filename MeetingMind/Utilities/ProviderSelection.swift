//
//  ProviderSelection.swift
//  MeetingMind
//

import Foundation

enum TranscriptionProviderType: String {
    case whisper
    case speechAnalyzer
}

enum AIProviderType: String {
    case claude
    case foundation
}

enum ProviderSelection {
    private static let transcriptionKey = "transcription_provider"
    private static let aiKey = "ai_provider"

    static var transcriptionProvider: TranscriptionProviderType {
        get {
            let raw = UserDefaults.standard.string(forKey: transcriptionKey) ?? "whisper"
            return TranscriptionProviderType(rawValue: raw) ?? .whisper
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: transcriptionKey)
        }
    }

    static var aiProvider: AIProviderType {
        get {
            let raw = UserDefaults.standard.string(forKey: aiKey) ?? "claude"
            return AIProviderType(rawValue: raw) ?? .claude
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: aiKey)
        }
    }
}
