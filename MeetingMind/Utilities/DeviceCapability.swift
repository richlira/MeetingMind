//
//  DeviceCapability.swift
//  MeetingMind
//

import Darwin
import Foundation
import FoundationModels
import Speech

enum DeviceCapability {

    // MARK: - Hardware Detection

    /// Returns the device model identifier (e.g. "iPhone17,2" for iPhone 16 Pro Max).
    /// In the Simulator, reads `SIMULATOR_MODEL_IDENTIFIER` to get the simulated device.
    static var deviceModelIdentifier: String {
        #if targetEnvironment(simulator)
        return ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? "Simulator"
        #else
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "Unknown"
            }
        }
        #endif
    }

    /// A17 Pro (iPhone 15 Pro) or newer — required for Apple Intelligence and SpeechAnalyzer.
    /// iPhone16,x = iPhone 15 Pro/Pro Max (A17 Pro) — first supported generation.
    /// iPhone17,x = iPhone 16 series, iPhone18,x = iPhone 17 series, etc.
    static var supportsA17ProOrNewer: Bool {
        let model = deviceModelIdentifier
        guard model.starts(with: "iPhone") else { return false }

        let numericPart = model.replacingOccurrences(of: "iPhone", with: "")
        let parts = numericPart.split(separator: ",")
        guard let major = Int(parts.first ?? "") else { return false }

        return major >= 16
    }

    // MARK: - Capability Checks

    /// Whether on-device SpeechAnalyzer transcription is available.
    static var canUseSpeechAnalyzer: Bool {
        guard supportsA17ProOrNewer else { return false }
        guard let recognizer = SFSpeechRecognizer() else { return false }
        return recognizer.supportsOnDeviceRecognition
    }

    /// Whether on-device Foundation Models (Apple Intelligence) are available.
    static var canUseFoundationModels: Bool {
        guard supportsA17ProOrNewer else { return false }
        return SystemLanguageModel.default.availability == .available
    }

    /// Whether BOTH transcription and AI can run entirely on-device.
    static var canUseFullyOnDevice: Bool {
        canUseSpeechAnalyzer && canUseFoundationModels
    }

    /// Whether at least one provider axis has an on-device option.
    static var hasAnyOnDeviceOption: Bool {
        canUseSpeechAnalyzer || canUseFoundationModels
    }

    // MARK: - Logging

    /// Logs current device capability status. Call once during app launch.
    static func logCapabilities() {
        print("[DeviceCapability] Model: \(deviceModelIdentifier), A17Pro+: \(supportsA17ProOrNewer)")
        print("[DeviceCapability] SpeechAnalyzer: \(canUseSpeechAnalyzer), FoundationModels: \(canUseFoundationModels), FullyOnDevice: \(canUseFullyOnDevice)")
    }
}
