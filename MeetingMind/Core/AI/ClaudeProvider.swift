//
//  ClaudeProvider.swift
//  MeetingMind
//

import Foundation

struct ClaudeProvider: AIProvider {
    let apiKey: String
    let model: String = "claude-sonnet-4-5-20250929"

    func generateQuestion(context: String, previousQuestions: [String] = []) async throws -> String? {
        let system = """
        You are a sharp, experienced advisor listening to a live conversation. \
        Your job is to surface the most important question that the speaker or \
        audience should be thinking about RIGHT NOW based on what has been said so far.

        Look for: contradictions, decisions without data, unrealistic assumptions, \
        hidden risks, missing perspectives, logical gaps, or statements that deserve \
        to be challenged.

        You do NOT need to wait for the speaker to finish their full thought. \
        If you've already heard something questionable, ask about it.

        Generate ONE focused question. Keep it concise (max 2 sentences). \
        If there is truly nothing worth questioning, respond with exactly: NO_QUESTION

        IMPORTANT: Detect the language of the transcript and generate your question \
        in the SAME language. If the transcript is in Spanish, respond in Spanish. \
        If in English, respond in English. If Spanglish, match the dominant language.
        """

        var userMessage = "Conversation transcript so far:\n\n\(context)"

        if !previousQuestions.isEmpty {
            let questionList = previousQuestions.enumerated()
                .map { "\($0.offset + 1). \($0.element)" }
                .joined(separator: "\n")
            userMessage += "\n\nQuestions already asked:\n\(questionList)\n\nDo NOT repeat these. Find a NEW angle."
        }

        let response = try await sendMessage(
            system: system,
            messages: [["role": "user", "content": userMessage]]
        )

        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        // Filter NO_QUESTION and variations
        if trimmed.uppercased().contains("NO_QUESTION") || trimmed.isEmpty {
            return nil
        }
        return trimmed
    }

    func generateSummary(transcript: String) async throws -> SummaryData {
        let system = """
        Generate a structured summary from this conversation transcript. \
        Respond ONLY with valid JSON (no markdown, no code fences) in this exact format:
        {
          "summary": "Brief 2-3 sentence summary",
          "keyPoints": ["point 1", "point 2"],
          "actionItems": ["action 1", "action 2"],
          "participants": ["name/role if identifiable"]
        }

        If there are no clear action items, use an empty array. \
        Always provide at least a summary and key points.

        PARTICIPANTS: List ONLY the people who are actually SPEAKING in this recording. \
        Do NOT list people who are merely mentioned or referenced by the speaker. \
        For example, if Valentina says 'My boss the CEO thought I was crazy', \
        the CEO is NOT a participant — only Valentina is. \
        Distinguish between: \
        SPEAKER — someone whose voice/words are in the recording (they say 'I', 'we did', they introduce themselves). \
        MENTIONED — someone the speaker talks ABOUT but who is not present speaking. \
        Only list SPEAKERS as participants. For each speaker include their name and role if stated. \
        If only one person is speaking (like a presentation, podcast, or personal notes), list only that one person. \
        If you can't identify any speakers by name, use an empty array.

        IMPORTANT: Detect the language of the transcript and write ALL content \
        (summary, key points, action items) in the SAME language as the transcript. \
        If the transcript is in Spanish, write everything in Spanish. \
        If in English, write in English. Only the JSON keys stay in English.
        """

        let response = try await sendMessage(
            system: system,
            messages: [["role": "user", "content": "Generate a summary for this transcript:\n\n\(transcript)"]]
        )

        // Try to parse JSON from response, handling potential text wrapping
        let jsonString = extractJSON(from: response)
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw ClaudeError.invalidJSON
        }

        do {
            return try JSONDecoder().decode(SummaryData.self, from: jsonData)
        } catch {
            // Fallback: create basic summary from raw response
            return SummaryData(
                summary: response,
                keyPoints: [],
                actionItems: [],
                participants: []
            )
        }
    }

    func chat(message: String, transcript: String, history: [(role: String, content: String)]) async throws -> String {
        let system = """
        You are a helpful meeting assistant. The user has just finished a meeting/conversation \
        and wants to discuss it with you. Use the transcript below as context to answer their questions.

        Meeting transcript:
        \(transcript)

        Be concise and helpful. Reference specific parts of the conversation when relevant.

        IMPORTANT: Respond in the same language the user writes their message in. \
        If the user writes in Spanish, respond in Spanish. If in English, respond in English.
        """

        // Cap history to last 10 messages to prevent unbounded growth.
        // The transcript is already in the system prompt — no need to repeat context.
        let recentHistory = Array(history.suffix(10))
        var messages: [[String: String]] = recentHistory.map { ["role": $0.role, "content": $0.content] }
        messages.append(["role": "user", "content": message])

        return try await sendMessage(system: system, messages: messages)
    }

    // MARK: - Private

    private func sendMessage(system: String, messages: [[String: String]]) async throws -> String {
        guard !apiKey.isEmpty else {
            throw ClaudeError.missingAPIKey
        }

        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "system": system,
            "messages": messages
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ClaudeError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        let result = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        return result.content.first { $0.type == "text" }?.text ?? ""
    }

    private func extractJSON(from text: String) -> String {
        // Strip markdown code fences if present
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
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

// MARK: - Response Models

private struct ClaudeResponse: Codable {
    let content: [ContentBlock]

    struct ContentBlock: Codable {
        let type: String
        let text: String?
    }
}

// MARK: - Errors

enum ClaudeError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case invalidJSON
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Anthropic API key is not set. Add it in Settings."
        case .invalidResponse:
            return "Invalid response from Claude API."
        case .invalidJSON:
            return "Could not parse summary from Claude response."
        case .apiError(let code, let message):
            return "Claude API error (\(code)): \(message)"
        }
    }
}
