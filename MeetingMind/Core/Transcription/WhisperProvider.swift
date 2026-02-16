//
//  WhisperProvider.swift
//  MeetingMind
//

import Foundation

struct WhisperProvider: TranscriptionProvider {
    let apiKey: String

    func transcribe(audioData: Data, prompt: String? = nil) async throws -> String {
        guard !apiKey.isEmpty else {
            throw WhisperError.missingAPIKey
        }

        let url = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // File field
        body.appendMultipart(boundary: boundary, name: "file", filename: "audio.wav", mimeType: "audio/wav", data: audioData)

        // Model field
        body.appendMultipart(boundary: boundary, name: "model", value: "whisper-1")

        // Optional prompt for context continuity
        if let prompt, !prompt.isEmpty {
            let trimmed = String(prompt.suffix(500))
            body.appendMultipart(boundary: boundary, name: "prompt", value: trimmed)
        }

        // Response format
        body.appendMultipart(boundary: boundary, name: "response_format", value: "json")

        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WhisperError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw WhisperError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }

        let result = try JSONDecoder().decode(WhisperResponse.self, from: data)
        return result.text
    }
}

// MARK: - Response Model

private struct WhisperResponse: Codable {
    let text: String
}

// MARK: - Errors

enum WhisperError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API key is not set. Add it in Settings."
        case .invalidResponse:
            return "Invalid response from Whisper API."
        case .apiError(let code, let message):
            return "Whisper API error (\(code)): \(message)"
        }
    }
}

// MARK: - Data Multipart Helper

extension Data {
    mutating func appendMultipart(boundary: String, name: String, filename: String, mimeType: String, data: Data) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        append(data)
        append("\r\n".data(using: .utf8)!)
    }

    mutating func appendMultipart(boundary: String, name: String, value: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append("\(value)\r\n".data(using: .utf8)!)
    }
}
