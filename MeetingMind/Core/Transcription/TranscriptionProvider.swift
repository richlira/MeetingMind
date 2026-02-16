//
//  TranscriptionProvider.swift
//  MeetingMind
//

import AVFoundation
import Foundation

protocol TranscriptionProvider: Sendable {
    /// Transcribe audio data and return the text (chunk-based, used by Whisper)
    func transcribe(audioData: Data, prompt: String?) async throws -> String
}

// MARK: - Streaming Support

/// Update emitted by streaming transcription providers.
struct TranscriptUpdate: Sendable {
    /// All finalized (isFinal=true) text accumulated so far.
    let confirmedText: String
    /// Current in-progress segment (isFinal=false). Empty when update is final.
    let partialText: String
    /// The text of the just-finalized segment (only meaningful when isFinal=true).
    let segmentText: String
    /// Whether this update includes a newly finalized segment.
    let isFinal: Bool
}

/// Protocol for providers that process a continuous audio stream (e.g., SpeechAnalyzer).
/// The stream naturally ends when the audio buffer stream finishes (recording stopped).
protocol StreamingTranscriptionProvider: TranscriptionProvider {
    func startStreaming(
        audioBuffers: AsyncStream<AVAudioPCMBuffer>,
        audioFormat: AVAudioFormat
    ) -> AsyncStream<TranscriptUpdate>
}
