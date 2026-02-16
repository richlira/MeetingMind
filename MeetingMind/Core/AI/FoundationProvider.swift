//
//  FoundationProvider.swift
//  MeetingMind
//

import Foundation
import FoundationModels

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
        let trimmed = response.content.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.uppercased().contains("NO_QUESTION") || trimmed.isEmpty {
            return nil
        }
        return trimmed
    }

    func generateSummary(transcript: String) async throws -> SummaryData {
        let session = LanguageModelSession(instructions: """
            Summarize conversation transcripts. Respond ONLY with valid JSON, no markdown. \
            Format: {"summary":"...","keyPoints":["..."],"actionItems":["..."],"participants":["..."]}
            Rules: participants = ONLY people speaking, NOT mentioned. \
            Empty array if no action items. Write in the SAME language as the transcript. \
            JSON keys stay in English.
            """)

        let response = try await session.respond(to: "Summarize:\n\n\(transcript)")
        let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip markdown code fences if present
        let jsonString = extractJSON(from: text)
        guard let jsonData = jsonString.data(using: .utf8) else {
            return SummaryData(summary: text, keyPoints: [], actionItems: [], participants: [])
        }

        do {
            return try JSONDecoder().decode(SummaryData.self, from: jsonData)
        } catch {
            return SummaryData(summary: text, keyPoints: [], actionItems: [], participants: [])
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
