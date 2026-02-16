//
//  TranscriptionProvider.swift
//  MeetingMind
//

import Foundation

protocol TranscriptionProvider: Sendable {
    /// Transcribe audio data and return the text
    func transcribe(audioData: Data, prompt: String?) async throws -> String
}
