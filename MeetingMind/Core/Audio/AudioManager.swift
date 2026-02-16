//
//  AudioManager.swift
//  MeetingMind
//

import AVFoundation
import Foundation

@Observable
final class AudioManager {
    private let audioEngine = AVAudioEngine()
    private let bufferLock = NSLock()

    private var fullRecordingFile: AVAudioFile?
    private var currentChunkFile: AVAudioFile?
    private var currentChunkURL: URL?
    private var recordingFormat: AVAudioFormat?
    private var fileSettings: [String: Any] = [:]

    private(set) var fullRecordingURL: URL?
    private(set) var isRecording = false
    private(set) var recordingStartTime: Date?

    var elapsedTime: TimeInterval {
        guard let start = recordingStartTime, isRecording else { return 0 }
        return Date().timeIntervalSince(start)
    }

    // MARK: - Permissions

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    // MARK: - Recording

    func startRecording() async throws {
        // Activate audio session off main thread (takes 1-3s on real device)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let session = AVAudioSession.sharedInstance()
                    try session.setCategory(.record, mode: .default)
                    try session.setActive(true)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        recordingFormat = format

        // WAV-compatible settings: 16-bit PCM at native sample rate
        fileSettings = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        // Create full recording file
        let fullURL = Self.newFileURL(prefix: "recording")
        fullRecordingFile = try AVAudioFile(forWriting: fullURL, settings: fileSettings)
        fullRecordingURL = fullURL

        // Create first chunk file
        let chunkURL = Self.newFileURL(prefix: "chunk")
        currentChunkFile = try AVAudioFile(forWriting: chunkURL, settings: fileSettings)
        currentChunkURL = chunkURL

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            self?.handleBuffer(buffer)
        }

        // Prepare and start engine off main thread
        let engine = audioEngine
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    engine.prepare()
                    try engine.start()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        isRecording = true
        recordingStartTime = Date()
    }

    /// Get the current audio chunk data and start a new chunk.
    /// Returns the WAV data of the completed chunk, or nil if no audio was captured.
    func getNextChunkData() -> Data? {
        bufferLock.lock()

        let oldChunkURL = currentChunkURL
        // Close current chunk by releasing the file
        currentChunkFile = nil

        // Start new chunk
        if let settings = recordingFormat.map({ _ in fileSettings }) {
            let newURL = Self.newFileURL(prefix: "chunk")
            currentChunkFile = try? AVAudioFile(forWriting: newURL, settings: settings)
            currentChunkURL = newURL
        }

        bufferLock.unlock()

        // Read completed chunk data (outside lock to avoid blocking audio thread)
        guard let url = oldChunkURL else { return nil }
        defer { try? FileManager.default.removeItem(at: url) }

        guard let data = try? Data(contentsOf: url), data.count > 44 else {
            // WAV header is 44 bytes, so anything <= 44 is empty
            return nil
        }
        return data
    }

    /// Stop recording and return the last chunk data.
    func stopRecording() -> Data? {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        audioEngine.reset()

        bufferLock.lock()
        fullRecordingFile = nil
        let lastChunkURL = currentChunkURL
        currentChunkFile = nil
        currentChunkURL = nil
        recordingFormat = nil
        fileSettings = [:]
        bufferLock.unlock()

        isRecording = false

        // Deactivate audio session on background thread
        DispatchQueue.global(qos: .utility).async {
            try? AVAudioSession.sharedInstance().setActive(false)
        }

        // Return last chunk data
        guard let url = lastChunkURL else { return nil }
        defer { try? FileManager.default.removeItem(at: url) }
        guard let data = try? Data(contentsOf: url), data.count > 44 else { return nil }
        return data
    }

    // MARK: - Private

    private func handleBuffer(_ buffer: AVAudioPCMBuffer) {
        bufferLock.lock()
        defer { bufferLock.unlock() }
        try? fullRecordingFile?.write(from: buffer)
        try? currentChunkFile?.write(from: buffer)
    }

    private static func newFileURL(prefix: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)_\(UUID().uuidString).wav")
    }
}
