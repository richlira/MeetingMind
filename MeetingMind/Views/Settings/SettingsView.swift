//
//  SettingsView.swift
//  MeetingMind
//

import SwiftUI

struct SettingsView: View {
    @State private var openAIKey = ""
    @State private var anthropicKey = ""
    @State private var showOpenAIKey = false
    @State private var showAnthropicKey = false
    @State private var savedMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("OpenAI API Key")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack {
                            Group {
                                if showOpenAIKey {
                                    TextField("sk-...", text: $openAIKey)
                                } else {
                                    SecureField("sk-...", text: $openAIKey)
                                }
                            }
                            .textContentType(.password)
                            .autocorrectionDisabled()

                            Button {
                                showOpenAIKey.toggle()
                            } label: {
                                Image(systemName: showOpenAIKey ? "eye.slash" : "eye")
                            }
                        }

                        if KeychainManager.read(key: .openAIAPIKey) != nil {
                            Label("Key saved", systemImage: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                    }
                } header: {
                    Text("Whisper (Transcription)")
                } footer: {
                    Text("Used for real-time speech-to-text via OpenAI Whisper API.")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Anthropic API Key")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack {
                            Group {
                                if showAnthropicKey {
                                    TextField("sk-ant-...", text: $anthropicKey)
                                } else {
                                    SecureField("sk-ant-...", text: $anthropicKey)
                                }
                            }
                            .textContentType(.password)
                            .autocorrectionDisabled()

                            Button {
                                showAnthropicKey.toggle()
                            } label: {
                                Image(systemName: showAnthropicKey ? "eye.slash" : "eye")
                            }
                        }

                        if KeychainManager.read(key: .anthropicAPIKey) != nil {
                            Label("Key saved", systemImage: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                    }
                } header: {
                    Text("Claude (AI)")
                } footer: {
                    Text("Used for question suggestions, minutes generation, and post-meeting chat.")
                }

                Section {
                    Button("Save API Keys") {
                        saveKeys()
                    }
                    .frame(maxWidth: .infinity)
                }

                if let message = savedMessage {
                    Section {
                        Text(message)
                            .foregroundStyle(.green)
                            .font(.callout)
                    }
                }

                Section {
                    Text("Phase 1: Cloud Pipeline")
                        .font(.caption)
                    Text("Transcription: OpenAI Whisper API")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("AI: Anthropic Claude API")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Provider Info")
                } footer: {
                    Text("Future phases will add on-device processing via SpeechAnalyzer and Foundation Models.")
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                // Load existing keys (show masked)
                openAIKey = KeychainManager.read(key: .openAIAPIKey) ?? ""
                anthropicKey = KeychainManager.read(key: .anthropicAPIKey) ?? ""
            }
        }
    }

    private func saveKeys() {
        do {
            if !openAIKey.isEmpty {
                try KeychainManager.save(key: .openAIAPIKey, value: openAIKey)
            }
            if !anthropicKey.isEmpty {
                try KeychainManager.save(key: .anthropicAPIKey, value: anthropicKey)
            }
            savedMessage = "API keys saved securely."

            // Clear message after 3 seconds
            Task {
                try? await Task.sleep(for: .seconds(3))
                savedMessage = nil
            }
        } catch {
            savedMessage = "Error saving keys: \(error.localizedDescription)"
        }
    }
}
