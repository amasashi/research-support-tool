import Foundation

final class OpenAIClient {
    private let apiKey: String
    private let model: String
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(apiKey: String, model: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.model = model
        self.session = session
        encoder = JSONEncoder()
        decoder = JSONDecoder()
    }

    func complete(system: String, user: String) async throws -> String {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw APIError.missingAPIKey
        }
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try encoder.encode(
            OpenAIChatRequest(
                model: model,
                messages: [
                    OpenAIChatMessage(role: "system", content: system),
                    OpenAIChatMessage(role: "user", content: user)
                ],
                temperature: 0.2
            )
        )

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.network(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode)
            throw APIError.httpStatus(httpResponse.statusCode, message)
        }

        do {
            let response = try decoder.decode(OpenAIChatResponse.self, from: data)
            return response.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        } catch {
            throw APIError.decoding(error)
        }
    }
}

private struct OpenAIChatRequest: Encodable {
    let model: String
    let messages: [OpenAIChatMessage]
    let temperature: Double
}

private struct OpenAIChatMessage: Codable {
    let role: String
    let content: String
}

private struct OpenAIChatResponse: Decodable {
    let choices: [OpenAIChoice]
}

private struct OpenAIChoice: Decodable {
    let message: OpenAIChatMessage
}
