//
//  ChatMessage.swift
//  MeetingMind
//

import Foundation
import SwiftData

@Model
final class ChatMessage {
    var id: UUID = UUID()
    var content: String = ""
    var isUser: Bool = true
    var timestamp: Date = Date()
    var session: Session?

    init(content: String, isUser: Bool) {
        self.content = content
        self.isUser = isUser
        self.timestamp = Date()
    }
}
