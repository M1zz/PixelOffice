import Foundation

struct Message: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var role: MessageRole
    var content: String
    var timestamp: Date
    var tokenCount: Int?
    
    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        tokenCount: Int? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.tokenCount = tokenCount
    }
    
    static func userMessage(_ content: String) -> Message {
        Message(role: .user, content: content)
    }
    
    static func assistantMessage(_ content: String) -> Message {
        Message(role: .assistant, content: content)
    }
    
    static func systemMessage(_ content: String) -> Message {
        Message(role: .system, content: content)
    }
}

enum MessageRole: String, Codable {
    case user = "user"
    case assistant = "assistant"
    case system = "system"
}
