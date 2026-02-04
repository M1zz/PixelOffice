import Foundation
import SwiftUI

struct Employee: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var employeeNumber: String  // 사원번호 (예: EMP-0001)
    var name: String
    var aiType: AIType
    var jobRole: JobRole  // 직군
    var status: EmployeeStatus
    var currentTaskId: UUID?
    var conversationHistory: [Message]
    var createdAt: Date
    var totalTasksCompleted: Int
    var characterAppearance: CharacterAppearance

    // 직원 특성 정보
    var personality: String  // 성격: 꼼꼼함, 창의적, 분석적 등
    var strengths: [String]  // 강점 리스트
    var workStyle: String    // 업무 스타일

    init(
        id: UUID = UUID(),
        employeeNumber: String? = nil,
        name: String,
        aiType: AIType = .claude,
        jobRole: JobRole = .general,
        status: EmployeeStatus = .idle,
        currentTaskId: UUID? = nil,
        conversationHistory: [Message] = [],
        createdAt: Date = Date(),
        totalTasksCompleted: Int = 0,
        characterAppearance: CharacterAppearance = CharacterAppearance(),
        personality: String? = nil,
        strengths: [String]? = nil,
        workStyle: String? = nil
    ) {
        self.id = id
        self.employeeNumber = employeeNumber ?? Self.generateEmployeeNumber(from: id)
        self.name = name
        self.aiType = aiType
        self.jobRole = jobRole
        self.status = status
        self.currentTaskId = currentTaskId
        self.conversationHistory = conversationHistory
        self.createdAt = createdAt
        self.totalTasksCompleted = totalTasksCompleted
        self.characterAppearance = characterAppearance
        self.personality = personality ?? Self.generatePersonality(from: id, jobRole: jobRole)
        self.strengths = strengths ?? Self.generateStrengths(from: id, jobRole: jobRole)
        self.workStyle = workStyle ?? Self.generateWorkStyle(from: id, jobRole: jobRole)
    }

    /// UUID 기반 사원번호 생성
    static func generateEmployeeNumber(from id: UUID) -> String {
        let hash = abs(id.hashValue)
        let number = hash % 10000
        return String(format: "EMP-%04d", number)
    }

    /// ID와 직군 기반 성격 자동 생성
    static func generatePersonality(from id: UUID, jobRole: JobRole) -> String {
        let personalities: [String] = [
            "꼼꼼하고 세밀한", "창의적이고 혁신적인", "분석적이고 논리적인",
            "열정적이고 추진력 있는", "차분하고 신중한", "유연하고 적응력 있는",
            "체계적이고 계획적인", "직관적이고 통찰력 있는"
        ]
        let index = abs(id.hashValue) % personalities.count
        return personalities[index]
    }

    /// ID와 직군 기반 강점 자동 생성
    static func generateStrengths(from id: UUID, jobRole: JobRole) -> [String] {
        let allStrengths: [[String]] = [
            ["빠른 학습 능력", "문제 해결 능력", "커뮤니케이션"],
            ["창의적 사고", "디테일 집중력", "협업 능력"],
            ["데이터 분석", "논리적 사고", "멀티태스킹"],
            ["리더십", "전략적 사고", "프로젝트 관리"],
            ["기술 전문성", "효율성", "자기 주도적 학습"]
        ]
        let index = abs(id.hashValue) % allStrengths.count
        return allStrengths[index]
    }

    /// ID와 직군 기반 업무 스타일 자동 생성
    static func generateWorkStyle(from id: UUID, jobRole: JobRole) -> String {
        let workStyles: [String] = [
            "체계적으로 계획하고 단계별로 실행", "빠르게 프로토타입을 만들고 개선",
            "깊이 있게 분석한 후 실행", "팀과 긴밀히 협업하며 진행",
            "독립적으로 집중해서 완성", "유연하게 상황에 맞춰 대응"
        ]
        let index = abs(id.hashValue) % workStyles.count
        return workStyles[index]
    }

    // MARK: - Codable (기존 데이터 호환)
    enum CodingKeys: String, CodingKey {
        case id, employeeNumber, name, aiType, jobRole, status, currentTaskId
        case conversationHistory, createdAt, totalTasksCompleted, characterAppearance
        case personality, strengths, workStyle
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        aiType = try container.decode(AIType.self, forKey: .aiType)
        jobRole = try container.decodeIfPresent(JobRole.self, forKey: .jobRole) ?? .general
        status = try container.decode(EmployeeStatus.self, forKey: .status)
        currentTaskId = try container.decodeIfPresent(UUID.self, forKey: .currentTaskId)
        conversationHistory = try container.decode([Message].self, forKey: .conversationHistory)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        totalTasksCompleted = try container.decode(Int.self, forKey: .totalTasksCompleted)
        characterAppearance = try container.decode(CharacterAppearance.self, forKey: .characterAppearance)
        // 기존 데이터에 employeeNumber가 없으면 자동 생성
        employeeNumber = try container.decodeIfPresent(String.self, forKey: .employeeNumber) ?? Self.generateEmployeeNumber(from: id)
        // 기존 데이터에 특성 정보가 없으면 자동 생성
        personality = try container.decodeIfPresent(String.self, forKey: .personality) ?? Self.generatePersonality(from: id, jobRole: jobRole)
        strengths = try container.decodeIfPresent([String].self, forKey: .strengths) ?? Self.generateStrengths(from: id, jobRole: jobRole)
        workStyle = try container.decodeIfPresent(String.self, forKey: .workStyle) ?? Self.generateWorkStyle(from: id, jobRole: jobRole)
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
    var hairStyle: Int  // 0-11 (확장: 5개 → 12개)
    var hairColor: Int  // 0-8 (확장: 6개 → 9개)
    var shirtColor: Int  // 0-11 (확장: 8개 → 12개)
    var accessory: Int  // 0-9 (확장: 4개 → 10개)
    var expression: Int  // 0-4 (신규: 기본, 웃음, 진지, 피곤, 놀람)

    init(
        skinTone: Int = 0,
        hairStyle: Int = 0,
        hairColor: Int = 0,
        shirtColor: Int = 0,
        accessory: Int = 0,
        expression: Int = 0
    ) {
        self.skinTone = skinTone
        self.hairStyle = hairStyle
        self.hairColor = hairColor
        self.shirtColor = shirtColor
        self.accessory = accessory
        self.expression = expression
    }

    static func random() -> CharacterAppearance {
        CharacterAppearance(
            skinTone: Int.random(in: 0...3),
            hairStyle: Int.random(in: 0...11),
            hairColor: Int.random(in: 0...8),
            shirtColor: Int.random(in: 0...11),
            accessory: Int.random(in: 0...9),
            expression: Int.random(in: 0...4)
        )
    }

    // MARK: - 옵션 이름
    static func hairStyleName(_ style: Int) -> String {
        switch style {
        case 0: return "숏컷"
        case 1: return "미디엄"
        case 2: return "롱헤어"
        case 3: return "스파이키"
        case 4: return "민머리"
        case 5: return "포니테일"
        case 6: return "보브컷"
        case 7: return "모히칸"
        case 8: return "곱슬"
        case 9: return "투블럭"
        case 10: return "울프컷"
        case 11: return "언더컷"
        default: return "숏컷"
        }
    }

    static func hairColorName(_ color: Int) -> String {
        switch color {
        case 0: return "검은색"
        case 1: return "갈색"
        case 2: return "밝은 갈색"
        case 3: return "금발"
        case 4: return "빨간색"
        case 5: return "회색"
        case 6: return "은색"
        case 7: return "청록색"
        case 8: return "보라색"
        default: return "검은색"
        }
    }

    static func shirtColorName(_ color: Int) -> String {
        switch color {
        case 0: return "흰색"
        case 1: return "파란색"
        case 2: return "빨간색"
        case 3: return "초록색"
        case 4: return "보라색"
        case 5: return "주황색"
        case 6: return "분홍색"
        case 7: return "어두운 회색"
        case 8: return "하늘색"
        case 9: return "노란색"
        case 10: return "네이비"
        case 11: return "민트"
        default: return "흰색"
        }
    }

    static func accessoryName(_ accessory: Int) -> String {
        switch accessory {
        case 0: return "없음"
        case 1: return "안경"
        case 2: return "모자"
        case 3: return "헤드폰"
        case 4: return "선글라스"
        case 5: return "목걸이"
        case 6: return "마스크"
        case 7: return "귀걸이"
        case 8: return "헤어밴드"
        case 9: return "리본"
        default: return "없음"
        }
    }

    static func expressionName(_ expression: Int) -> String {
        switch expression {
        case 0: return "기본"
        case 1: return "웃음"
        case 2: return "진지"
        case 3: return "피곤"
        case 4: return "놀람"
        default: return "기본"
        }
    }

    // MARK: - Codable (backward compatibility)
    enum CodingKeys: String, CodingKey {
        case skinTone, hairStyle, hairColor, shirtColor, accessory, expression
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        skinTone = try container.decode(Int.self, forKey: .skinTone)
        hairStyle = try container.decode(Int.self, forKey: .hairStyle)
        hairColor = try container.decode(Int.self, forKey: .hairColor)
        shirtColor = try container.decode(Int.self, forKey: .shirtColor)
        accessory = try container.decode(Int.self, forKey: .accessory)
        // 기존 데이터에 expression이 없으면 기본값 0 사용
        expression = try container.decodeIfPresent(Int.self, forKey: .expression) ?? 0
    }
}
