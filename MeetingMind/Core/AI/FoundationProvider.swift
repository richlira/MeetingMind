//
//  FoundationProvider.swift
//  MeetingMind
//

import Foundation
import FoundationModels
import NaturalLanguage

struct FoundationProvider: AIProvider {

    func generateQuestion(context: String, previousQuestions: [String] = []) async throws -> String? {
        let session = LanguageModelSession(instructions: """
            You are listening to a live conversation. Identify ONE important question \
            that should be asked right now. Respond with ONLY the question, or exactly \
            NO_QUESTION if nothing is worth asking. Match the language of the transcript.
            """)

        var prompt = "Transcript:\n\(context)"

        if !previousQuestions.isEmpty {
            let list = previousQuestions.enumerated()
                .map { "\($0.offset + 1). \($0.element)" }
                .joined(separator: "\n")
            prompt += "\n\nAlready asked:\n\(list)\n\nAsk something NEW and different."
        }

        let response = try await session.respond(to: prompt)
        var trimmed = response.content.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip markdown formatting if model wraps the response
        if trimmed.hasPrefix("```") {
            trimmed = extractJSON(from: trimmed)
        }
        // Strip surrounding quotes if model wraps in quotes
        if trimmed.hasPrefix("\"") && trimmed.hasSuffix("\"") && trimmed.count > 2 {
            trimmed = String(trimmed.dropFirst().dropLast())
        }

        if trimmed.uppercased().contains("NO_QUESTION") || trimmed.isEmpty {
            return nil
        }
        return trimmed
    }

    func generateSummary(transcript: String) async throws -> SummaryData {
        let languageName = detectLanguageName(transcript)
        let languageInstruction = "IMPORTANT: The transcript is in \(languageName). Write summary, keyPoints, and actionItems in \(languageName). Only JSON keys stay in English."

        let session = LanguageModelSession(instructions: """
            Summarize conversation transcripts. Respond ONLY with valid JSON, no markdown, no code fences. \
            Format: {"summary":"...","keyPoints":["..."],"actionItems":["..."],"participants":["..."]}
            Rules: participants = ONLY people speaking, NOT mentioned. \
            Empty array if no action items. \
            \(languageInstruction)
            """)

        let response = try await session.respond(to: "Summarize:\n\n\(transcript)")
        let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        print("[Foundation] Raw response: \(String(text.prefix(200)))")

        // Strip markdown code fences if present
        let jsonString = extractJSON(from: text)
        guard let jsonData = jsonString.data(using: .utf8) else {
            print("[Foundation] JSON parse failed, using fallback")
            return SummaryData(summary: text, keyPoints: [], actionItems: [], participants: [])
        }

        do {
            let result = try JSONDecoder().decode(SummaryData.self, from: jsonData)
            print("[Foundation] Parsed summary successfully")
            return result
        } catch {
            print("[Foundation] JSON parse failed: \(error), using fallback")
            return SummaryData(summary: jsonString, keyPoints: [], actionItems: [], participants: [])
        }
    }

    func chat(message: String, transcript: String, history: [(role: String, content: String)]) async throws -> String {
        // Smaller context window — truncate more aggressively
        let maxChars = 4000
        let truncatedTranscript = transcript.count > maxChars
            ? String(transcript.suffix(maxChars))
            : transcript

        let session = LanguageModelSession(instructions: """
            You are a helpful meeting assistant. Use the transcript below to answer questions. \
            Be concise. Respond in the same language the user writes in.

            Meeting transcript:
            \(truncatedTranscript)
            """)

        // Build conversation context from recent history
        let recentHistory = Array(history.suffix(6))
        var prompt = ""
        if !recentHistory.isEmpty {
            for turn in recentHistory {
                let role = turn.role == "user" ? "User" : "Assistant"
                prompt += "\(role): \(turn.content)\n"
            }
            prompt += "\n"
        }
        prompt += message

        let response = try await session.respond(to: prompt)
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Private

    /// Detect the dominant language name using NLLanguageRecognizer.
    private func detectLanguageName(_ text: String) -> String {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(String(text.prefix(1000)))
        guard let lang = recognizer.dominantLanguage else { return "English" }
        return Locale.current.localizedString(forLanguageCode: lang.rawValue) ?? lang.rawValue
    }

    private func extractJSON(from text: String) -> String {
        var cleaned = text
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Errors

enum FoundationError: LocalizedError {
    case modelUnavailable
    case sessionFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelUnavailable:
            return "On-device AI is not available. Enable Apple Intelligence in Settings."
        case .sessionFailed(let message):
            return "On-device AI error: \(message)"
        }
    }
}
