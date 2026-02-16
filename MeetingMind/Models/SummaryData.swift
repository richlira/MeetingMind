//
//  SummaryData.swift
//  MeetingMind
//

import Foundation

struct SummaryData: Codable {
    var summary: String
    var keyPoints: [String]
    var actionItems: [String]
    var participants: [String]
}
