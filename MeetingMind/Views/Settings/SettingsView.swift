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
    @State private var transcriptionType: TranscriptionProviderType = .whisper
    @State private var aiType: AIProviderType = .claude
    @State private var canUseSpeechAnalyzer = false
    @State private var canUseFoundation = false

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Provider Configuration
                Section {
                    // Transcription picker
                    if canUseSpeechAnalyzer {
                        Picker("Transcription", selection: $transcriptionType) {
                            Text("Whisper (Cloud)").tag(TranscriptionProviderType.whisper)
                            Text("SpeechAnalyzer (On-Device)").tag(TranscriptionProviderType.speechAnalyzer)
                        }
                    } else {
                        HStack {
                            Text("Transcription")
                            Spacer()
                            Text("Whisper (Cloud)")
                                .foregroundStyle(.secondary)
                        }
                    }

                    // AI picker
                    if canUseFoundation {
                        Picker("AI", selection: $aiType) {
                            Text("Claude (Cloud)").tag(AIProviderType.claude)
                            Text("Apple Intelligence (On-Device)").tag(AIProviderType.foundation)
                        }
                    } else {
                        HStack {
                            Text("AI")
                            Spacer()
                            Text("Claude (Cloud)")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Providers")
                }

                // MARK: - Transcription API Key
                if transcriptionType == .whisper {
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
                } else {
                    Section {
                        Label("Runs entirely on-device. No API key needed.", systemImage: "lock.shield")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text("SpeechAnalyzer (Transcription)")
                    } footer: {
                        Text("Private, offline speech recognition powered by the Neural Engine.")
                    }
                }

                // MARK: - AI API Key
                if aiType == .claude {
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
                        Text("Used for question suggestions, summaries, and post-meeting chat.")
                    }
                } else {
                    Section {
                        Label("Runs entirely on-device. No API key needed.", systemImage: "lock.shield")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text("Apple Intelligence (AI)")
                    } footer: {
                        Text("Private, on-device language model. Requires Apple Intelligence enabled in Settings.")
                    }
                }

                // MARK: - Save
                if transcriptionType == .whisper || aiType == .claude {
                    Section {
                        Button("Save API Keys") {
                            saveKeys()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                if let message = savedMessage {
                    Section {
                        Text(message)
                            .foregroundStyle(.green)
                            .font(.callout)
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                openAIKey = KeychainManager.read(key: .openAIAPIKey) ?? ""
                anthropicKey = KeychainManager.read(key: .anthropicAPIKey) ?? ""
                transcriptionType = ProviderSelection.transcriptionProvider
                aiType = ProviderSelection.aiProvider
                canUseSpeechAnalyzer = DeviceCapability.canUseSpeechAnalyzer
                canUseFoundation = DeviceCapability.canUseFoundationModels
            }
            .onChange(of: transcriptionType) { _, newValue in
                ProviderSelection.transcriptionProvider = newValue
            }
            .onChange(of: aiType) { _, newValue in
                ProviderSelection.aiProvider = newValue
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

            Task {
                try? await Task.sleep(for: .seconds(3))
                savedMessage = nil
            }
        } catch {
            savedMessage = "Error saving keys: \(error.localizedDescription)"
        }
    }
}
