import Foundation

enum VerbatimTranscriptionError: Error {
    case unavailable, demoExpired, subscriptionRequired
}

/// Uses Max's authenticated backend. Provider credentials and transcription
/// instructions stay on the server; the user's draft is never sent as a hint.
enum VerbatimTranscriber {
    static func transcribe(_ audio: Data, baseURL: String, token: String, transaction: String?, session: URLSession = .shared) async throws -> String {
        guard let base = URL(string: baseURL), base.scheme == "https", base.host != nil else { throw VerbatimTranscriptionError.unavailable }
        var request = URLRequest(url: base.appendingPathComponent("v1/transcriptions"))
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("audio/wav", forHTTPHeaderField: "Content-Type")
        if let transaction { request.setValue(transaction, forHTTPHeaderField: "X-Max-Transaction") }
        request.httpBody = audio
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse, data.count <= 100_000 else { throw VerbatimTranscriptionError.unavailable }
        if http.statusCode == 402 {
            struct APIError: Decodable { let code: String? }
            let code = try? JSONDecoder().decode(APIError.self, from: data).code
            if code == "demo_expired" { throw VerbatimTranscriptionError.demoExpired }
            if code == "subscription_required" { throw VerbatimTranscriptionError.subscriptionRequired }
        }
        guard http.statusCode == 200 else { throw VerbatimTranscriptionError.unavailable }
        struct Transcript: Decodable { let text: String }
        return try JSONDecoder().decode(Transcript.self, from: data).text
    }
}
