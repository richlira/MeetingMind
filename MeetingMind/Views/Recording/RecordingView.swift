//
//  RecordingView.swift
//  MeetingMind
//

import SwiftUI
import SwiftData

struct RecordingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var sessionManager = SessionManager()
    @State private var showResults = false
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Timer
                Text(formatDuration(sessionManager.recordingDuration))
                    .font(.system(size: 48, weight: .light, design: .monospaced))
                    .foregroundStyle(Color(.label))
                    .padding(.top, 24)

                // MARK: - Status indicator
                Group {
                    if sessionManager.isProcessing {
                        ProgressView("Generating summary...")
                    } else if sessionManager.isRecording {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(.systemRed))
                                .frame(width: 8, height: 8)
                            Text("Grabando")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color(.systemRed))
                        }
                    } else {
                        Text("Tap to start recording")
                            .font(.subheadline)
                            .foregroundStyle(Color(.secondaryLabel))
                    }
                }
                .padding(.top, 4)

                // MARK: - Record / Stop button
                Button {
                    Task {
                        if sessionManager.isRecording {
                            await sessionManager.stopRecording(modelContext: modelContext)
                        } else {
                            await sessionManager.startRecording(modelContext: modelContext)
                        }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(.systemRed))
                            .frame(width: 72, height: 72)

                        if sessionManager.isRecording {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.white)
                                .frame(width: 26, height: 26)
                        } else {
                            Circle()
                                .fill(.white)
                                .frame(width: 30, height: 30)
                        }
                    }
                }
                .disabled(sessionManager.isProcessing)
                .padding(.top, 16)

                // MARK: - Tab switcher
                if sessionManager.isRecording || !sessionManager.transcriptText.isEmpty {
                    tabSwitcher
                        .padding(.horizontal, 16)
                        .padding(.top, 20)

                    // MARK: - Content area
                    Group {
                        if selectedTab == 0 {
                            transcriptContent
                        } else {
                            questionsContent
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 12)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                } else {
                    Spacer()
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle("MeetingMind")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: sessionManager.summaryReady) { _, ready in
                if ready {
                    showResults = true
                }
            }
            .navigationDestination(isPresented: $showResults) {
                if let session = sessionManager.currentSession {
                    SessionDetailView(session: session)
                }
            }
            .alert("Error", isPresented: .init(
                get: { sessionManager.error != nil },
                set: { if !$0 { sessionManager.error = nil } }
            )) {
                Button("OK") { sessionManager.error = nil }
            } message: {
                Text(sessionManager.error ?? "")
            }
        }
    }

    // MARK: - Tab Switcher

    private var tabSwitcher: some View {
        HStack(spacing: 4) {
            tabButton(title: "Transcript", emoji: "\u{1F4DD}", index: 0)
            tabButton(title: "Preguntas", emoji: "\u{1F4A1}", index: 1, badgeCount: sessionManager.liveQuestions.count)
        }
        .padding(4)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    private func tabButton(title: String, emoji: String, index: Int, badgeCount: Int = 0) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = index
            }
        } label: {
            HStack(spacing: 4) {
                Text(emoji)
                    .font(.caption)
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(selectedTab == index ? Color(.label) : Color(.secondaryLabel))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                selectedTab == index ? Color(.systemGray4) : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(alignment: .topTrailing) {
                if badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemRed))
                        .clipShape(Capsule())
                        .offset(x: 10, y: -10)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Transcript Content

    private var transcriptContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if sessionManager.transcriptText.isEmpty {
                    Color.clear
                } else {
                    coloredTranscript
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)

                    Color.clear
                        .frame(height: 1)
                        .id("transcript_bottom")
                }
            }
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            .onChange(of: sessionManager.transcriptText) {
                withAnimation {
                    proxy.scrollTo("transcript_bottom", anchor: .bottom)
                }
            }
        }
    }

    private var coloredTranscript: Text {
        let full = sessionManager.transcriptText
        let recentCharCount = 200

        if full.count <= recentCharCount {
            return Text(full).foregroundColor(Color(.label))
        }

        let splitIndex = full.index(full.endIndex, offsetBy: -recentCharCount)
        let older = String(full[full.startIndex..<splitIndex])
        let newer = String(full[splitIndex..<full.endIndex])

        return Text(older).foregroundColor(Color(.secondaryLabel))
            + Text(newer).foregroundColor(Color(.label))
    }

    // MARK: - Questions Content

    private var questionsContent: some View {
        ScrollView {
            if sessionManager.liveQuestions.isEmpty {
                Color.clear
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(Array(sessionManager.liveQuestions.enumerated()), id: \.offset) { _, question in
                        questionCard(question)
                    }
                }
                .padding(12)
            }
        }
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func questionCard(_ text: String) -> some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(.systemOrange))
                .frame(width: 3)

            Text(text)
                .font(.callout)
                .foregroundStyle(Color(.label))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
        }
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
