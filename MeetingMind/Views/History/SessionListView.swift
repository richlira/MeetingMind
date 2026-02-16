//
//  SessionListView.swift
//  MeetingMind
//

import SwiftUI
import SwiftData

struct SessionListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Session.date, order: .reverse) private var sessions: [Session]

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No Sessions",
                        systemImage: "mic.slash",
                        description: Text("Record a conversation to see it here.")
                    )
                } else {
                    List {
                        ForEach(sessions) { session in
                            NavigationLink(destination: SessionDetailView(session: session)) {
                                SessionRow(session: session)
                            }
                        }
                        .onDelete(perform: deleteSessions)
                    }
                }
            }
            .navigationTitle("History")
        }
    }

    private func deleteSessions(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sessions[index])
        }
    }
}

// MARK: - Session Row

private struct SessionRow: View {
    let session: Session

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.title)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                statusBadge
            }

            HStack {
                Text(session.date, style: .date)
                Text(session.date, style: .time)
                if session.duration > 0 {
                    Text("(\(formatDuration(session.duration)))")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let summary = session.summaryText, !summary.isEmpty {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch session.status {
        case .recording:
            Label("Recording", systemImage: "mic.fill")
                .font(.caption2)
                .foregroundStyle(.red)
        case .processing:
            Label("Processing", systemImage: "brain")
                .font(.caption2)
                .foregroundStyle(.orange)
        case .completed:
            EmptyView()
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
