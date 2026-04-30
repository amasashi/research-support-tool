import Foundation

enum APIError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case network(Error)
    case invalidResponse
    case httpStatus(Int, String)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API Key を Settings に入力してください。"
        case .invalidURL:
            return "URL が正しくありません。"
        case .network(let error):
            return "通信に失敗しました: \(error.localizedDescription)"
        case .invalidResponse:
            return "サーバーから不正な応答が返りました。"
        case .httpStatus(let status, let message):
            return "HTTP \(status): \(message)"
        case .decoding(let error):
            return "レスポンスの解析に失敗しました: \(error.localizedDescription)"
        }
    }
}
