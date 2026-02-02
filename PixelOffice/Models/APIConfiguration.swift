import Foundation

struct APIConfiguration: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var type: AIType
    var apiKey: String
    var baseURL: String?
    var model: String
    var maxTokens: Int
    var temperature: Double
    var isEnabled: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        type: AIType,
        apiKey: String = "",
        baseURL: String? = nil,
        model: String? = nil,
        maxTokens: Int = 4096,
        temperature: Double = 0.7,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.model = model ?? type.modelName
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.isEnabled = isEnabled
    }
    
    var effectiveBaseURL: String {
        if let baseURL = baseURL, !baseURL.isEmpty {
            return baseURL
        }
        switch type {
        case .claude:
            return "https://api.anthropic.com/v1"
        case .gpt:
            return "https://api.openai.com/v1"
        case .gemini:
            return "https://generativelanguage.googleapis.com/v1beta"
        case .local:
            return "http://localhost:11434/api"
        }
    }
    
    var isConfigured: Bool {
        !apiKey.isEmpty || type == .local
    }
    
    static var claudeDefault: APIConfiguration {
        APIConfiguration(
            name: "Claude API",
            type: .claude,
            model: "claude-sonnet-4-20250514"
        )
    }
    
    static var gptDefault: APIConfiguration {
        APIConfiguration(
            name: "OpenAI API",
            type: .gpt,
            model: "gpt-4o"
        )
    }
}
