//
//  Session.swift
//  MeetingMind
//

import Foundation
import SwiftData

enum SessionStatus: String, Codable {
    case recording
    case processing
    case completed
}

@Model
final class Session {
    @Attribute(.unique) var id: UUID = UUID()
    var title: String = ""
    var date: Date = Date()
    var duration: TimeInterval = 0
    var status: SessionStatus = SessionStatus.recording
    var transcriptText: String = ""
    var audioFilePath: String?

    // Summary
    var summaryText: String?
    var keyPoints: [String] = []
    var actionItems: [String] = []
    var participants: [String] = []

    @Relationship(deleteRule: .cascade, inverse: \TranscriptSegment.session)
    var segments: [TranscriptSegment] = []

    @Relationship(deleteRule: .cascade, inverse: \Question.session)
    var questions: [Question] = []

    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.session)
    var chatMessages: [ChatMessage] = []

    init(title: String = "") {
        self.title = title
        self.date = Date()
    }
}
