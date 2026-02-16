//
//  SessionManager.swift
//  MeetingMind
//

import AVFoundation
import Foundation
import SwiftData

@Observable
final class SessionManager {
    // UI-observable state
    var isRecording = false
    var isProcessing = false
    var transcriptText = ""
    var liveQuestions: [String] = []
    var error: String?
    var currentSession: Session?
    var recordingDuration: TimeInterval = 0
    var summaryReady = false

    // Dependencies
    private let audioManager = AudioManager()
    private var transcriptionProvider: (any TranscriptionProvider)?
    private var aiProvider: (any AIProvider)?

    // Internal state
    private var transcriptionTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?
    private var wordCountSinceLastQuestion = 0
    private var segmentOrder = 0
    private let questionWordThreshold = 50
    private var isStreamingMode = false
    private var confirmedTranscript = ""

    // MARK: - Public

    /// Start a new recording session
    func startRecording(modelContext: ModelContext) async {
        // Refresh providers (in case API keys changed)
        transcriptionProvider = ProviderConfig.makeTranscriptionProvider()
        aiProvider = ProviderConfig.makeAIProvider()

        // Request mic permission
        let granted = await audioManager.requestPermission()
        guard granted else {
            error = "Microphone permission denied. Enable it in Settings."
            return
        }

        // Create new session
        let session = Session(title: "Recording \(Date().formatted(date: .abbreviated, time: .shortened))")
        modelContext.insert(session)
        currentSession = session

        // Reset state
        transcriptText = ""
        confirmedTranscript = ""
        liveQuestions = []
        wordCountSinceLastQuestion = 0
        segmentOrder = 0
        error = nil
        summaryReady = false
        isStreamingMode = false

        do {
            try await audioManager.startRecording()
            isRecording = true

            // Choose transcription mode based on provider type
            if let streaming = transcriptionProvider as? StreamingTranscriptionProvider,
               let bufferStream = audioManager.audioBufferStream,
               let format = audioManager.recordingFormat {
                isStreamingMode = true
                print("[SessionManager] Starting STREAMING transcription")
                startStreamingTranscription(
                    streaming,
                    bufferStream: bufferStream,
                    format: format,
                    session: session,
                    modelContext: modelContext
                )
            } else {
                isStreamingMode = false
                print("[SessionManager] Starting CHUNK transcription")
                startTranscriptionLoop(session: session, modelContext: modelContext)
            }

            startTimer()
        } catch {
            self.error = "Failed to start recording: \(error.localizedDescription)"
            modelContext.delete(session)
            currentSession = nil
        }
    }

    /// Stop recording and generate summary
    func stopRecording(modelContext: ModelContext) async {
        isRecording = false
        isProcessing = true
        timerTask?.cancel()

        print("[SUMMARY-DEBUG-1] Recording stopped")

        if isStreamingMode {
            // Streaming mode: stop audio (finishes buffer stream),
            // then wait for transcription to process remaining audio
            _ = audioManager.stopRecording()
            print("[SessionManager] Audio stopped, waiting for streaming transcription to finish...")

            // Wait for streaming to finish with 5-second safety timeout
            let streamingCompleted = await withTaskGroup(of: Bool.self) { group in
                group.addTask {
                    await self.transcriptionTask?.value
                    return true
                }
                group.addTask {
                    try? await Task.sleep(for: .seconds(5))
                    return false
                }
                let result = await group.next() ?? false
                group.cancelAll()
                return result
            }

            if !streamingCompleted {
                print("[SessionManager] WARNING: Streaming timed out after 5s, forcing completion")
                transcriptionTask?.cancel()
                await transcriptionTask?.value
            }
            transcriptionTask = nil
            print("[SessionManager] Streaming transcription finished")

            // Use confirmed transcript (no partials)
            transcriptText = confirmedTranscript
            print("[SUMMARY-DEBUG-2] Confirmed transcript word count: \(confirmedTranscript.split(separator: " ").count)")
            print("[SUMMARY-DEBUG-3] Confirmed transcript is empty: \(confirmedTranscript.isEmpty)")
            print("[SUMMARY-DEBUG-4] First 300 chars: \(String(confirmedTranscript.prefix(300)))")
        } else {
            // Chunk mode: cancel loop, process last chunk
            transcriptionTask?.cancel()
            let lastChunkData = audioManager.stopRecording()

            if let session = currentSession, let lastChunkData {
                await transcribeChunk(lastChunkData, session: session, modelContext: modelContext)
            }
        }

        guard let session = currentSession else {
            isProcessing = false
            return
        }

        session.status = .processing
        session.duration = recordingDuration

        if let audioURL = audioManager.fullRecordingURL {
            session.audioFilePath = audioURL.lastPathComponent
        }

        session.transcriptText = transcriptText

        guard !transcriptText.isEmpty else {
            print("[SessionManager] Empty transcript, skipping summary")
            session.status = .completed
            try? modelContext.save()
            isProcessing = false
            summaryReady = true
            return
        }

        // Generate summary with timeout
        let wordCount = transcriptText.split(separator: " ").count
        print("[SessionManager] Generating summary, transcript: \(wordCount) words")
        await generateSummaryWithTimeout(session: session, modelContext: modelContext)

        session.status = .completed
        try? modelContext.save()
        isProcessing = false
        summaryReady = true
    }

    // MARK: - Streaming Transcription

    private func startStreamingTranscription(
        _ provider: StreamingTranscriptionProvider,
        bufferStream: AsyncStream<AVAudioPCMBuffer>,
        format: AVAudioFormat,
        session: Session,
        modelContext: ModelContext
    ) {
        confirmedTranscript = ""
        wordCountSinceLastQuestion = 0
        var lastConfirmedWordCount = 0

        let updates = provider.startStreaming(audioBuffers: bufferStream, audioFormat: format)

        transcriptionTask = Task {
            for await update in updates {
                guard !Task.isCancelled else { break }

                // Update UI: confirmed + partial (gives "live typing" effect)
                if update.partialText.isEmpty {
                    transcriptText = update.confirmedText
                } else if update.confirmedText.isEmpty {
                    transcriptText = update.partialText
                } else {
                    transcriptText = update.confirmedText + " " + update.partialText
                }

                if update.isFinal {
                    confirmedTranscript = update.confirmedText
                    session.transcriptText = confirmedTranscript

                    // Save segment
                    if !update.segmentText.isEmpty {
                        let segment = TranscriptSegment(text: update.segmentText, order: segmentOrder)
                        segment.session = session
                        modelContext.insert(segment)
                        segmentOrder += 1
                    }

                    // Track words for question generation (confirmed text only)
                    let currentWordCount = confirmedTranscript.split(separator: " ").count
                    let newWords = currentWordCount - lastConfirmedWordCount
                    lastConfirmedWordCount = currentWordCount
                    wordCountSinceLastQuestion += newWords

                    print("[SessionManager] Streaming: +\(newWords) words, accumulated: \(wordCountSinceLastQuestion)/\(questionWordThreshold), total: \(currentWordCount)")

                    if wordCountSinceLastQuestion >= questionWordThreshold {
                        wordCountSinceLastQuestion = 0
                        // Use confirmed text for question generation
                        await generateQuestion(transcript: confirmedTranscript, session: session, modelContext: modelContext)
                    }
                }
            }
            print("[SessionManager] Streaming transcription task ended")
        }
    }

    // MARK: - Chunk Transcription (Whisper)

    private func startTranscriptionLoop(session: Session, modelContext: ModelContext) {
        transcriptionTask = Task {
            print("[SessionManager] Transcription loop started")
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(12))
                guard !Task.isCancelled else {
                    print("[SessionManager] Transcription loop cancelled")
                    return
                }

                if let chunkData = self.audioManager.getNextChunkData() {
                    print("[SessionManager] Got chunk: \(chunkData.count) bytes")
                    await self.transcribeChunk(chunkData, session: session, modelContext: modelContext)
                } else {
                    print("[SessionManager] No chunk data available")
                }
            }
        }
    }

    private func transcribeChunk(_ data: Data, session: Session?, modelContext: ModelContext) async {
        guard let provider = transcriptionProvider else { return }

        do {
            let prompt = transcriptText.isEmpty ? nil : transcriptText
            let text = try await provider.transcribe(audioData: data, prompt: prompt)
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

            if !transcriptText.isEmpty {
                transcriptText += " "
            }
            transcriptText += text

            let segment = TranscriptSegment(text: text, order: segmentOrder)
            segment.session = session
            modelContext.insert(segment)
            segmentOrder += 1

            session?.transcriptText = transcriptText

            let chunkWordCount = text.split(separator: " ").count
            wordCountSinceLastQuestion += chunkWordCount
            let totalWords = transcriptText.split(separator: " ").count
            print("[SessionManager] Chunk: +\(chunkWordCount) words, accumulated: \(wordCountSinceLastQuestion)/\(questionWordThreshold), total: \(totalWords)")

            if wordCountSinceLastQuestion >= questionWordThreshold {
                wordCountSinceLastQuestion = 0
                await generateQuestion(transcript: transcriptText, session: session, modelContext: modelContext)
            }
        } catch {
            print("[SessionManager] Transcription error: \(error)")
            if error is SpeechAnalyzerError {
                print("[SessionManager] On-device transcription failed, falling back to cloud")
                transcriptionProvider = ProviderConfig.makeTranscriptionProvider()
            }
        }
    }

    // MARK: - Question Generation

    private func generateQuestion(transcript: String, session: Session?, modelContext: ModelContext) async {
        guard let ai = aiProvider else {
            print("[SessionManager] No AI provider available")
            return
        }

        do {
            let question = try await ai.generateQuestion(context: transcript, previousQuestions: liveQuestions)
            print("[SessionManager] AI response: \(question ?? "NO_QUESTION")")

            if let question {
                liveQuestions.append(question)
                print("[SessionManager] Question added. Total: \(liveQuestions.count)")

                let questionModel = Question(text: question)
                questionModel.session = session
                modelContext.insert(questionModel)
            }
        } catch {
            print("[SessionManager] Question generation error: \(error)")
            if error is FoundationError {
                print("[SessionManager] On-device AI failed, falling back to cloud")
                aiProvider = ProviderConfig.makeAIProvider()
            }
        }
    }

    // MARK: - Summary Generation (with timeout)

    private func generateSummaryWithTimeout(session: Session, modelContext: ModelContext) async {
        guard let ai = aiProvider else { return }

        let transcript = transcriptText

        // Race: summary vs 30-second timeout
        print("[SUMMARY-DEBUG-5] Calling generateSummary now...")
        let summaryTask = Task {
            try await ai.generateSummary(transcript: transcript)
        }

        let timeoutTask = Task {
            try await Task.sleep(for: .seconds(30))
            summaryTask.cancel()
        }

        do {
            let summary = try await summaryTask.value
            timeoutTask.cancel()
            session.summaryText = summary.summary
            session.keyPoints = summary.keyPoints
            session.actionItems = summary.actionItems
            session.participants = summary.participants
            print("[SessionManager] Summary generated successfully")
        } catch {
            timeoutTask.cancel()

            // If on-device AI failed, retry with cloud fallback
            if error is FoundationError {
                print("[SessionManager] On-device AI failed for summary, falling back to cloud")
                aiProvider = ProviderConfig.makeAIProvider()
                if let ai = aiProvider {
                    do {
                        let summary = try await ai.generateSummary(transcript: transcript)
                        session.summaryText = summary.summary
                        session.keyPoints = summary.keyPoints
                        session.actionItems = summary.actionItems
                        session.participants = summary.participants
                    } catch {
                        self.error = "Failed to generate summary: \(error.localizedDescription)"
                    }
                }
            } else if error is CancellationError {
                self.error = "Summary generation timed out. Your transcript is saved."
                print("[SessionManager] Summary timed out after 30s")
            } else {
                self.error = "Failed to generate summary: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Timer

    private func startTimer() {
        recordingDuration = 0
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self.recordingDuration = self.audioManager.elapsedTime
            }
        }
    }
}
