//
//  TranscriptView.swift
//  MeetingMind
//

import SwiftUI

struct TranscriptView: View {
    let session: Session

    var body: some View {
        ScrollView {
            if session.transcriptText.isEmpty {
                ContentUnavailableView(
                    "No Transcript",
                    systemImage: "text.alignleft",
                    description: Text("No transcript was generated for this session.")
                )
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    // Full transcript
                    Text(session.transcriptText)
                        .font(.body)
                        .textSelection(.enabled)

                    // Segments with timestamps
                    if !session.segments.isEmpty {
                        Divider()

                        Text("Segments")
                            .font(.headline)
                            .padding(.top, 8)

                        ForEach(session.segments.sorted(by: { $0.order < $1.order })) { segment in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(segment.timestamp, style: .time)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(segment.text)
                                    .font(.body)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding()
            }
        }
    }
}
