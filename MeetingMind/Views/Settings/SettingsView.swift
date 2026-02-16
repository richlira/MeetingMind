//
//  SettingsView.swift
//  MeetingMind
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [Session]

    @State private var openAIKey = ""
    @State private var anthropicKey = ""
    @State private var showOpenAIKey = false
    @State private var showAnthropicKey = false
    @State private var savedMessage: String?
    @State private var transcriptionType: TranscriptionProviderType = .whisper
    @State private var aiType: AIProviderType = .claude
    @State private var canUseSpeechAnalyzer = false
    @State private var canUseFoundation = false
    @State private var showDeleteOpenAIAlert = false
    @State private var showDeleteAnthropicAlert = false
    @State private var showDeleteAllAlert = false
    @State private var openAIKeySaved = false
    @State private var anthropicKeySaved = false

    var body: some View {
        NavigationStack {
            Form {
                providersSection
                transcriptionSection
                aiSection
                saveSection
                securitySection
                aboutSection
                dangerZoneSection

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
                openAIKeySaved = KeychainManager.read(key: .openAIAPIKey) != nil
                anthropicKeySaved = KeychainManager.read(key: .anthropicAPIKey) != nil
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
            .alert("Delete OpenAI API Key?", isPresented: $showDeleteOpenAIAlert) {
                Button("Delete", role: .destructive) { deleteOpenAIKey() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove your OpenAI API key from the Keychain.")
            }
            .alert("Delete Anthropic API Key?", isPresented: $showDeleteAnthropicAlert) {
                Button("Delete", role: .destructive) { deleteAnthropicKey() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove your Anthropic API key from the Keychain.")
            }
            .alert("Delete All Data?", isPresented: $showDeleteAllAlert) {
                Button("Delete Everything", role: .destructive) { deleteAllData() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will delete all API keys and recording history. This cannot be undone.")
            }
        }
    }

    // MARK: - Providers

    private var providersSection: some View {
        Section {
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
    }

    // MARK: - Transcription Key

    private var transcriptionSection: some View {
        Group {
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

                        if openAIKeySaved {
                            Label("Key saved", systemImage: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }

                        Text("Model: whisper-1 \u{00B7} OpenAI")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if openAIKeySaved {
                            Button("Delete API Key", role: .destructive) {
                                showDeleteOpenAIAlert = true
                            }
                            .font(.caption)
                        }
                    }
                } header: {
                    Text("Whisper (Transcription)")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Used for real-time speech-to-text via OpenAI Whisper API.")
                        Link("Get your OpenAI API key \u{2192}", destination: URL(string: "https://platform.openai.com/api-keys")!)
                    }
                }
            } else {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Runs entirely on-device. No API key needed.", systemImage: "lock.shield")
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        Text("Model: On-device Speech Recognition \u{00B7} Apple")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("SpeechAnalyzer (Transcription)")
                } footer: {
                    Text("Private, offline speech recognition powered by the Neural Engine.")
                }
            }
        }
    }

    // MARK: - AI Key

    private var aiSection: some View {
        Group {
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

                        if anthropicKeySaved {
                            Label("Key saved", systemImage: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }

                        Text("Model: claude-sonnet-4-5-20250929 \u{00B7} Anthropic")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if anthropicKeySaved {
                            Button("Delete API Key", role: .destructive) {
                                showDeleteAnthropicAlert = true
                            }
                            .font(.caption)
                        }
                    }
                } header: {
                    Text("Claude (AI)")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Used for question suggestions, summaries, and post-meeting chat.")
                        Link("Get your Anthropic API key \u{2192}", destination: URL(string: "https://console.anthropic.com/settings/keys")!)
                    }
                }
            } else {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Runs entirely on-device. No API key needed.", systemImage: "lock.shield")
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        Text("Model: On-device LLM (~3B params) \u{00B7} Apple Intelligence")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Apple Intelligence (AI)")
                } footer: {
                    Text("Private, on-device language model. Requires Apple Intelligence enabled in Settings.")
                }
            }
        }
    }

    // MARK: - Save

    private var saveSection: some View {
        Group {
            if transcriptionType == .whisper || aiType == .claude {
                Section {
                    Button("Save API Keys") {
                        saveKeys()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Security & Privacy

    private var securitySection: some View {
        Section {
            securityRow(icon: "lock.fill", text: "API keys stored in your device's Secure Keychain, encrypted by iOS")
            securityRow(icon: "iphone", text: "Keys never leave your device and are never sent to third-party servers")
            securityRow(icon: "arrow.left.arrow.right", text: "API calls go directly from your iPhone to OpenAI/Anthropic")
            securityRow(icon: "eye.slash.fill", text: "No backend, no analytics, no tracking")
            securityRow(icon: "airplane", text: "On-device mode works 100% offline \u{2014} zero data leaves your phone")
        } header: {
            Label("Security & Privacy", systemImage: "lock.shield.fill")
        }
    }

    private func securityRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.green)
                .frame(width: 16)
            Text(text)
                .font(.caption)
                .foregroundStyle(Color(.secondaryLabel))
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Meeting Mind AI")
                    .font(.headline)
                Spacer()
                Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Built by Rich")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Link(destination: URL(string: "https://richlira.dev")!) {
                HStack {
                    Image(systemName: "safari")
                        .foregroundStyle(.blue)
                    Text("richlira.dev")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Link(destination: URL(string: "https://github.com/richlira/MeetingMind")!) {
                HStack {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .foregroundStyle(.blue)
                    Text("Open Source \u{00B7} MIT License")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Made in Mexico City \u{1F1F2}\u{1F1FD}")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("About")
        }
    }

    // MARK: - Danger Zone

    private var dangerZoneSection: some View {
        Section {
            Button("Delete All Data", role: .destructive) {
                showDeleteAllAlert = true
            }
            .frame(maxWidth: .infinity)
        } footer: {
            Text("Removes all API keys and recording history from this device.")
                .font(.caption2)
        }
    }

    // MARK: - Actions

    private func saveKeys() {
        do {
            if !openAIKey.isEmpty {
                try KeychainManager.save(key: .openAIAPIKey, value: openAIKey)
                openAIKeySaved = true
            }
            if !anthropicKey.isEmpty {
                try KeychainManager.save(key: .anthropicAPIKey, value: anthropicKey)
                anthropicKeySaved = true
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

    private func deleteOpenAIKey() {
        KeychainManager.delete(key: .openAIAPIKey)
        openAIKey = ""
        openAIKeySaved = false
    }

    private func deleteAnthropicKey() {
        KeychainManager.delete(key: .anthropicAPIKey)
        anthropicKey = ""
        anthropicKeySaved = false
    }

    private func deleteAllData() {
        KeychainManager.delete(key: .openAIAPIKey)
        KeychainManager.delete(key: .anthropicAPIKey)
        openAIKey = ""
        anthropicKey = ""
        openAIKeySaved = false
        anthropicKeySaved = false

        for session in sessions {
            modelContext.delete(session)
        }
        try? modelContext.save()

        savedMessage = "All data deleted."
        Task {
            try? await Task.sleep(for: .seconds(3))
            savedMessage = nil
        }
    }
}
