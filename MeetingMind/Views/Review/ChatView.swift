//
//  ChatView.swift
//  MeetingMind
//

import SwiftUI
import SwiftData

struct ChatView: View {
    let session: Session
    @Environment(\.modelContext) private var modelContext
    @State private var messageText = ""
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(sortedMessages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }

                        if isLoading {
                            HStack {
                                ProgressView()
                                    .padding(12)
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                                Spacer()
                            }
                            .padding(.horizontal)
                            .id("loading")
                        }
                    }
                    .padding(.vertical)
                }
                .onChange(of: session.chatMessages.count) {
                    withAnimation {
                        proxy.scrollTo(sortedMessages.last?.id, anchor: .bottom)
                    }
                }
            }

            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            // Input bar
            HStack(spacing: 12) {
                TextField("Ask about the meeting...", text: $messageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .padding(10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            }
            .padding()
        }
    }

    private var sortedMessages: [ChatMessage] {
        session.chatMessages.sorted { $0.timestamp < $1.timestamp }
    }

    private func sendMessage() {
        guard !isLoading else { return }
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messageText = ""
        error = nil

        // Add user message
        let userMessage = ChatMessage(content: text, isUser: true)
        userMessage.session = session
        modelContext.insert(userMessage)

        isLoading = true

        Task {
            do {
                let ai = ProviderConfig.makeAIProvider()

                // Build history from previous messages
                let history = sortedMessages.map { (role: $0.isUser ? "user" : "assistant", content: $0.content) }

                let response = try await ai.chat(
                    message: text,
                    transcript: session.transcriptText,
                    history: history
                )

                let aiMessage = ChatMessage(content: response, isUser: false)
                aiMessage.session = session
                modelContext.insert(aiMessage)
            } catch {
                self.error = error.localizedDescription
            }

            isLoading = false
        }
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 60) }

            Text(message.content)
                .padding(12)
                .background(
                    message.isUser ? Color.blue : Color(.systemGray5),
                    in: RoundedRectangle(cornerRadius: 16)
                )
                .foregroundStyle(message.isUser ? .white : .primary)

            if !message.isUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal)
    }
}
