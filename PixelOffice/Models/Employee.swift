import Foundation
import SwiftUI

struct Employee: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var aiType: AIType
    var status: EmployeeStatus
    var currentTaskId: UUID?
    var conversationHistory: [Message]
    var createdAt: Date
    var totalTasksCompleted: Int
    var characterAppearance: CharacterAppearance
    
    init(
        id: UUID = UUID(),
        name: String,
        aiType: AIType = .claude,
        status: EmployeeStatus = .idle,
        currentTaskId: UUID? = nil,
        conversationHistory: [Message] = [],
        createdAt: Date = Date(),
        totalTasksCompleted: Int = 0,
        characterAppearance: CharacterAppearance = CharacterAppearance()
    ) {
        self.id = id
        self.name = name
        self.aiType = aiType
        self.status = status
        self.currentTaskId = currentTaskId
        self.conversationHistory = conversationHistory
        self.createdAt = createdAt
        self.totalTasksCompleted = totalTasksCompleted
        self.characterAppearance = characterAppearance
    }
    
    static func == (lhs: Employee, rhs: Employee) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    var isWorking: Bool {
        status == .working || status == .thinking
    }
    
    mutating func startWorking(on taskId: UUID) {
        status = .working
        currentTaskId = taskId
    }
    
    mutating func stopWorking() {
        status = .idle
        currentTaskId = nil
        totalTasksCompleted += 1
    }
    
    mutating func addMessage(_ message: Message) {
        conversationHistory.append(message)
    }
    
    mutating func clearConversation() {
        conversationHistory.removeAll()
    }
}

enum AIType: String, Codable, CaseIterable {
    case claude = "Claude"
    case gpt = "GPT"
    case gemini = "Gemini"
    case local = "Local LLM"
    
    var icon: String {
        switch self {
        case .claude: return "brain.head.profile"
        case .gpt: return "sparkles"
        case .gemini: return "star.fill"
        case .local: return "desktopcomputer"
        }
    }
    
    var color: Color {
        switch self {
        case .claude: return Color(red: 0.85, green: 0.55, blue: 0.35)
        case .gpt: return Color(red: 0.0, green: 0.65, blue: 0.55)
        case .gemini: return Color(red: 0.25, green: 0.45, blue: 0.95)
        case .local: return Color.gray
        }
    }
    
    var modelName: String {
        switch self {
        case .claude: return "claude-sonnet-4-20250514"
        case .gpt: return "gpt-4o"
        case .gemini: return "gemini-1.5-pro"
        case .local: return "local"
        }
    }
}

enum EmployeeStatus: String, Codable {
    case idle = "휴식 중"
    case working = "작업 중"
    case thinking = "생각 중"
    case offline = "오프라인"
    case error = "오류"

    var color: Color {
        switch self {
        case .idle: return .green
        case .working: return .blue
        case .thinking: return .orange
        case .offline: return .gray
        case .error: return .red
        }
    }

    var icon: String {
        switch self {
        case .idle: return "cup.and.saucer.fill"
        case .working: return "keyboard.fill"
        case .thinking: return "brain.head.profile"
        case .offline: return "moon.zzz.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
}

struct CharacterAppearance: Codable, Hashable {
    var skinTone: Int  // 0-3
    var hairStyle: Int  // 0-4
    var hairColor: Int  // 0-5
    var shirtColor: Int  // 0-7
    var accessory: Int  // 0-3 (none, glasses, hat, headphones)
    
    init(
        skinTone: Int = 0,
        hairStyle: Int = 0,
        hairColor: Int = 0,
        shirtColor: Int = 0,
        accessory: Int = 0
    ) {
        self.skinTone = skinTone
        self.hairStyle = hairStyle
        self.hairColor = hairColor
        self.shirtColor = shirtColor
        self.accessory = accessory
    }
    
    static func random() -> CharacterAppearance {
        CharacterAppearance(
            skinTone: Int.random(in: 0...3),
            hairStyle: Int.random(in: 0...4),
            hairColor: Int.random(in: 0...5),
            shirtColor: Int.random(in: 0...7),
            accessory: Int.random(in: 0...3)
        )
    }
}
