//
//  AIProvider.swift
//  MeetingMind
//

import Foundation

protocol AIProvider: Sendable {
    /// Generate a suggested question based on the conversation context.
    /// Returns nil if there's nothing interesting to ask.
    func generateQuestion(context: String, previousQuestions: [String]) async throws -> String?

    /// Generate a structured summary from the full transcript.
    func generateSummary(transcript: String) async throws -> SummaryData

    /// Chat about the session content using the transcript as context.
    func chat(message: String, transcript: String, history: [(role: String, content: String)]) async throws -> String
}
