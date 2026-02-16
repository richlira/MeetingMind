//
//  SessionDetailView.swift
//  MeetingMind
//

import SwiftUI

struct SessionDetailView: View {
    let session: Session
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            Picker("View", selection: $selectedTab) {
                Text("Summary").tag(0)
                Text("Transcript").tag(1)
                Text("Chat").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()

            // Tab content
            switch selectedTab {
            case 0:
                SummaryView(session: session)
            case 1:
                TranscriptView(session: session)
            case 2:
                ChatView(session: session)
            default:
                EmptyView()
            }
        }
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
