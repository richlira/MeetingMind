//
//  TranscriptSegment.swift
//  MeetingMind
//

import Foundation
import SwiftData

@Model
final class TranscriptSegment {
    var id: UUID = UUID()
    var text: String = ""
    var timestamp: Date = Date()
    var order: Int = 0
    var session: Session?

    init(text: String, order: Int) {
        self.text = text
        self.order = order
        self.timestamp = Date()
    }
}
