//
//  SummaryView.swift
//  MeetingMind
//

import SwiftUI

struct SummaryView: View {
    let session: Session

    /// Filter out any NO_QUESTION entries that may have leaked through
    private var validQuestions: [Question] {
        session.questions.filter { question in
            let text = question.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return !text.isEmpty && !text.uppercased().contains("NO_QUESTION")
        }
        .sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Summary
                if let summary = session.summaryText, !summary.isEmpty {
                    Section {
                        Text(summary)
                            .font(.body)
                    } header: {
                        Label("Summary", systemImage: "doc.text")
                            .font(.headline)
                    }
                }

                // Key Points
                if !session.keyPoints.isEmpty {
                    Section {
                        ForEach(session.keyPoints, id: \.self) { point in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                    .padding(.top, 6)
                                Text(point)
                            }
                        }
                    } header: {
                        Label("Key Points", systemImage: "list.bullet")
                            .font(.headline)
                    }
                }

                // Action Items
                if !session.actionItems.isEmpty {
                    Section {
                        ForEach(session.actionItems, id: \.self) { item in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "checkmark.circle")
                                    .foregroundStyle(.green)
                                Text(item)
                            }
                        }
                    } header: {
                        Label("Action Items", systemImage: "checklist")
                            .font(.headline)
                    }
                }

                // Participants
                if !session.participants.isEmpty {
                    Section {
                        ForEach(session.participants, id: \.self) { participant in
                            HStack(spacing: 8) {
                                Image(systemName: "person.fill")
                                    .foregroundStyle(.blue)
                                Text(participant)
                            }
                        }
                    } header: {
                        Label("Participants", systemImage: "person.3")
                            .font(.headline)
                    }
                }

                // Questions generated during recording (Issue 4: only real questions)
                if !validQuestions.isEmpty {
                    Section {
                        ForEach(validQuestions) { question in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundStyle(.yellow)
                                Text(question.text)
                            }
                        }
                    } header: {
                        Label("Suggested Questions", systemImage: "questionmark.bubble")
                            .font(.headline)
                    }
                }

                // Empty state
                if session.summaryText == nil && session.status == .completed {
                    ContentUnavailableView(
                        "No Summary Available",
                        systemImage: "doc.text",
                        description: Text("The recording was too short to generate a summary.")
                    )
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func Section<Content: View, Header: View>(
        @ViewBuilder content: () -> Content,
        @ViewBuilder header: () -> Header
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            header()
            content()
        }
    }
}
