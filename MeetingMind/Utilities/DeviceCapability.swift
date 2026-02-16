//
//  DeviceCapability.swift
//  MeetingMind
//

import Foundation
import FoundationModels
import Speech

enum DeviceCapability {
    /// Whether on-device SpeechAnalyzer transcription is available.
    static var canUseSpeechAnalyzer: Bool {
        guard let recognizer = SFSpeechRecognizer() else { return false }
        return recognizer.supportsOnDeviceRecognition
    }

    /// Whether on-device Foundation Models (Apple Intelligence) are available.
    static var canUseFoundationModels: Bool {
        SystemLanguageModel.default.availability == .available
    }
}
