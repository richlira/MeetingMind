//
//  SessionManager.swift
//  MeetingMind
//

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
        liveQuestions = []
        wordCountSinceLastQuestion = 0
        segmentOrder = 0
        error = nil
        summaryReady = false

        do {
            try await audioManager.startRecording()
            isRecording = true

            // Start transcription loop
            startTranscriptionLoop(session: session, modelContext: modelContext)

            // Start timer
            startTimer()
        } catch {
            self.error = "Failed to start recording: \(error.localizedDescription)"
            modelContext.delete(session)
            currentSession = nil
        }
    }

    /// Stop recording and generate summary
    func stopRecording(modelContext: ModelContext) async {
        // Immediately show processing state (Issue 2)
        isRecording = false
        isProcessing = true
        transcriptionTask?.cancel()
        timerTask?.cancel()

        // Stop audio and get last chunk
        let lastChunkData = audioManager.stopRecording()

        guard let session = currentSession else {
            isProcessing = false
            return
        }

        session.status = .processing
        session.duration = recordingDuration

        if let audioURL = audioManager.fullRecordingURL {
            session.audioFilePath = audioURL.lastPathComponent
        }

        // Transcribe last chunk
        if let lastChunkData {
            await transcribeChunk(lastChunkData, session: session, modelContext: modelContext)
        }

        session.transcriptText = transcriptText

        guard !transcriptText.isEmpty else {
            session.status = .completed
            try? modelContext.save()
            isProcessing = false
            summaryReady = true
            return
        }

        // Generate summary
        do {
            if let ai = aiProvider {
                let summary = try await ai.generateSummary(transcript: transcriptText)
                session.summaryText = summary.summary
                session.keyPoints = summary.keyPoints
                session.actionItems = summary.actionItems
                session.participants = summary.participants
            }
        } catch {
            self.error = "Failed to generate summary: \(error.localizedDescription)"
        }

        session.status = .completed
        try? modelContext.save()
        isProcessing = false
        summaryReady = true
    }

    // MARK: - Private

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
            // Use previous transcript as context for better continuity
            let prompt = transcriptText.isEmpty ? nil : transcriptText
            let text = try await provider.transcribe(audioData: data, prompt: prompt)
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

            // Append to transcript
            if !transcriptText.isEmpty {
                transcriptText += " "
            }
            transcriptText += text

            // Save segment
            let segment = TranscriptSegment(text: text, order: segmentOrder)
            segment.session = session
            modelContext.insert(segment)
            segmentOrder += 1

            // Update session
            session?.transcriptText = transcriptText

            // Check if we should generate a question
            let chunkWordCount = text.split(separator: " ").count
            wordCountSinceLastQuestion += chunkWordCount
            let totalWords = transcriptText.split(separator: " ").count
            print("[SessionManager] Chunk: +\(chunkWordCount) words, accumulated: \(wordCountSinceLastQuestion)/\(questionWordThreshold), total transcript: \(totalWords) words")

            if wordCountSinceLastQuestion >= questionWordThreshold {
                print("[SessionManager] Triggering question generation with \(totalWords) words of context")
                wordCountSinceLastQuestion = 0
                await generateQuestion(session: session, modelContext: modelContext)
            }
        } catch {
            print("[SessionManager] Transcription error: \(error)")
        }
    }

    private func generateQuestion(session: Session?, modelContext: ModelContext) async {
        guard let ai = aiProvider else {
            print("[SessionManager] No AI provider available")
            return
        }

        do {
            let question = try await ai.generateQuestion(context: transcriptText, previousQuestions: liveQuestions)
            print("[SessionManager] Claude response: \(question ?? "NO_QUESTION")")

            if let question {
                liveQuestions.append(question)
                print("[SessionManager] Question added to UI. Total questions: \(liveQuestions.count)")

                let questionModel = Question(text: question)
                questionModel.session = session
                modelContext.insert(questionModel)
            }
        } catch {
            print("[SessionManager] Question generation error: \(error)")
        }
    }

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
