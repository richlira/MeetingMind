//
//  Question.swift
//  MeetingMind
//

import Foundation
import SwiftData

@Model
final class Question {
    var id: UUID = UUID()
    var text: String = ""
    var timestamp: Date = Date()
    var session: Session?

    init(text: String) {
        self.text = text
        self.timestamp = Date()
    }
}
