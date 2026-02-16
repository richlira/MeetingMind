//
//  SpeechAnalyzerProvider.swift
//  MeetingMind
//

import AVFoundation
import Foundation
import NaturalLanguage
import Speech

final class SpeechAnalyzerProvider: StreamingTranscriptionProvider, @unchecked Sendable {

    /// Locale locked after auto-detection on the first confirmed segment.
    private var detectedLocale: Locale?

    /// Default locale used before detection.
    private let defaultLocale = Locale(identifier: "es-MX")

    /// Candidate locales for auto-detection, ordered by priority.
    private static let candidateLocales: [(language: String, locale: Locale)] = [
        ("es", Locale(identifier: "es-MX")),
        ("en", Locale(identifier: "en-US")),
        ("pt", Locale(identifier: "pt-BR")),
        ("fr", Locale(identifier: "fr-FR")),
        ("de", Locale(identifier: "de-DE")),
        ("ja", Locale(identifier: "ja-JP")),
        ("zh", Locale(identifier: "zh-CN")),
    ]

    // MARK: - StreamingTranscriptionProvider

    func startStreaming(
        audioBuffers: AsyncStream<AVAudioPCMBuffer>,
        audioFormat: AVAudioFormat
    ) -> AsyncStream<TranscriptUpdate> {
        let locale = detectedLocale ?? defaultLocale
        print("[SpeechAnalyzer] startStreaming() locale: \(locale.identifier), detected: \(detectedLocale != nil)")

        return AsyncStream { [weak self] continuation in
            let task = Task { [weak self] in
                do {
                    try await self?.runStreamingPipeline(
                        audioBuffers: audioBuffers,
                        audioFormat: audioFormat,
                        locale: locale,
                        continuation: continuation
                    )
                } catch {
                    print("[SpeechAnalyzer] Streaming pipeline error: \(error)")
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - TranscriptionProvider (chunk-based fallback)

    func transcribe(audioData: Data, prompt: String? = nil) async throws -> String {
        // Minimal chunk-based implementation for protocol conformance.
        // In practice, streaming mode is used during recording.
        print("[SpeechAnalyzer] transcribe() chunk fallback, \(audioData.count) bytes")
        return ""
    }

    // MARK: - Private: Streaming Pipeline

    private func runStreamingPipeline(
        audioBuffers: AsyncStream<AVAudioPCMBuffer>,
        audioFormat: AVAudioFormat,
        locale: Locale,
        continuation: AsyncStream<TranscriptUpdate>.Continuation
    ) async throws {
        // Check authorization
        let status = SFSpeechRecognizer.authorizationStatus()
        if status == .denied || status == .restricted {
            throw SpeechAnalyzerError.permissionDenied
        }

        if status == .notDetermined {
            let granted = await withCheckedContinuation { cont in
                SFSpeechRecognizer.requestAuthorization { newStatus in
                    cont.resume(returning: newStatus == .authorized)
                }
            }
            if !granted {
                throw SpeechAnalyzerError.permissionDenied
            }
        }

        // Create transcriber
        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: []
        )
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        print("[SpeechAnalyzer] Created transcriber (locale: \(locale.identifier))")

        // Get analyzer's expected format
        guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
            compatibleWith: [transcriber]
        ) else {
            print("[SpeechAnalyzer] ERROR: bestAvailableAudioFormat returned nil")
            throw SpeechAnalyzerError.unavailable
        }
        print("[SpeechAnalyzer] Audio format: input=\(audioFormat.sampleRate)Hz/\(audioFormat.channelCount)ch, analyzer=\(analyzerFormat.sampleRate)Hz/\(analyzerFormat.channelCount)ch")

        // Create converter if formats differ
        let converter: AVAudioConverter?
        if audioFormat != analyzerFormat {
            converter = AVAudioConverter(from: audioFormat, to: analyzerFormat)
            print("[SpeechAnalyzer] Audio converter created")
        } else {
            converter = nil
        }

        // Create analyzer input stream
        let (inputStream, inputContinuation) = AsyncStream<AnalyzerInput>.makeStream()

        // Forward audio buffers (converting if needed).
        // This task runs for the entire recording and naturally ends when audioBuffers finishes.
        let forwardTask = Task { [analyzerFormat] in
            var buffersForwarded = 0
            for await buffer in audioBuffers {
                guard !Task.isCancelled else { break }

                let outputBuffer: AVAudioPCMBuffer
                if let converter {
                    let ratio = analyzerFormat.sampleRate / audioFormat.sampleRate
                    let outputFrames = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
                    guard let converted = AVAudioPCMBuffer(pcmFormat: analyzerFormat, frameCapacity: outputFrames) else { continue }

                    var consumed = false
                    converter.convert(to: converted, error: nil) { _, statusPtr in
                        if consumed {
                            statusPtr.pointee = .noDataNow
                            return nil
                        }
                        consumed = true
                        statusPtr.pointee = .haveData
                        return buffer
                    }
                    outputBuffer = converted
                } else {
                    outputBuffer = buffer
                }

                inputContinuation.yield(AnalyzerInput(buffer: outputBuffer))
                buffersForwarded += 1
            }
            inputContinuation.finish()
            print("[SpeechAnalyzer] Buffer forwarding done. Total: \(buffersForwarded)")
        }

        // Start analyzer in background (processes input stream internally)
        let analyzerTask = Task {
            do {
                try await analyzer.start(inputSequence: inputStream)
                print("[SpeechAnalyzer] analyzer.start() completed")
            } catch {
                print("[SpeechAnalyzer] analyzer.start() error: \(error)")
            }
        }

        // Collect results in a separate task.
        // transcriber.results never closes on its own, so this task runs until cancelled.
        let resultTask = Task { [weak self] in
            var confirmedText = ""
            var resultCount = 0

            do {
                for try await result in transcriber.results {
                    guard !Task.isCancelled else { break }
                    resultCount += 1
                    let text = String(result.text.characters)

                    if result.isFinal && !text.isEmpty {
                        let segmentText = text
                        if !confirmedText.isEmpty { confirmedText += " " }
                        confirmedText += segmentText

                        if self?.detectedLocale == nil {
                            if let detected = self?.detectLanguage(from: confirmedText) {
                                self?.detectedLocale = detected
                                print("[SpeechAnalyzer] Auto-detected language → \(detected.identifier)")
                            } else {
                                self?.detectedLocale = self?.defaultLocale
                            }
                        }

                        continuation.yield(TranscriptUpdate(
                            confirmedText: confirmedText,
                            partialText: "",
                            segmentText: segmentText,
                            isFinal: true
                        ))
                        print("[SpeechAnalyzer] Result #\(resultCount) FINAL: confirmed=\(confirmedText.split(separator: " ").count) words")
                    } else if !text.isEmpty {
                        continuation.yield(TranscriptUpdate(
                            confirmedText: confirmedText,
                            partialText: text,
                            segmentText: "",
                            isFinal: false
                        ))
                    }
                }
            } catch {
                if !(error is CancellationError) {
                    print("[SpeechAnalyzer] Result iteration error: \(error)")
                }
            }
            print("[SpeechAnalyzer] Result collection ended. Results: \(resultCount), confirmed words: \(confirmedText.split(separator: " ").count)")
        }

        // === ORCHESTRATION ===
        // Wait for all audio to be forwarded (blocks until recording stops).
        // During this time, results flow continuously via resultTask → continuation.
        await forwardTask.value
        print("[SpeechAnalyzer] Audio forwarding complete, waiting 2s for remaining processing...")

        // Give analyzer 2 seconds to finish processing any remaining buffered audio.
        // SpeechAnalyzer does NOT auto-complete when input ends — it hangs forever.
        try? await Task.sleep(for: .seconds(2))
        print("[SpeechAnalyzer] Grace period done, forcing completion")

        // Force-end recognition. All confirmed results were already yielded
        // to the continuation during recording + the 2s grace period.
        resultTask.cancel()
        await resultTask.value
        analyzerTask.cancel()
        print("[SpeechAnalyzer] Signaling stream completion")
    }

    // MARK: - Language Detection

    private func detectLanguage(from text: String) -> Locale? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        guard let dominant = recognizer.dominantLanguage else {
            print("[SpeechAnalyzer] NLLanguageRecognizer: no dominant language")
            return nil
        }

        let hypotheses = recognizer.languageHypotheses(withMaximum: 3)
        print("[SpeechAnalyzer] Language hypotheses: \(hypotheses.map { "\($0.key.rawValue): \(String(format: "%.2f", $0.value))" })")

        let langCode = dominant.rawValue
        for candidate in Self.candidateLocales {
            if langCode.hasPrefix(candidate.language) {
                return candidate.locale
            }
        }

        return Locale(identifier: langCode)
    }
}

// MARK: - Errors

enum SpeechAnalyzerError: LocalizedError {
    case permissionDenied
    case recognitionFailed(String)
    case unavailable

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Speech recognition permission denied. Enable it in Settings."
        case .recognitionFailed(let message):
            return "Speech recognition failed: \(message)"
        case .unavailable:
            return "On-device speech recognition is not available on this device."
        }
    }
}
