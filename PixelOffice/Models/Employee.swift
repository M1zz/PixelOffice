import Foundation
import SwiftUI

struct Employee: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var employeeNumber: String  // 사원번호 (예: EMP-0001)
    var name: String
    var aiType: AIType
    var jobRoles: [JobRole]  // 직군 (멀티 선택 가능)
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

    // 활동 통계
    var statistics: EmployeeStatistics

    init(
        id: UUID = UUID(),
        employeeNumber: String? = nil,
        name: String,
        aiType: AIType = .claude,
        jobRoles: [JobRole] = [.general],
        status: EmployeeStatus = .idle,
        currentTaskId: UUID? = nil,
        conversationHistory: [Message] = [],
        createdAt: Date = Date(),
        totalTasksCompleted: Int = 0,
        characterAppearance: CharacterAppearance = CharacterAppearance(),
        personality: String? = nil,
        strengths: [String]? = nil,
        workStyle: String? = nil,
        statistics: EmployeeStatistics? = nil
    ) {
        self.id = id
        self.employeeNumber = employeeNumber ?? Self.generateEmployeeNumber(from: id)
        self.name = name
        self.aiType = aiType
        self.jobRoles = jobRoles.isEmpty ? [.general] : jobRoles
        self.status = status
        self.currentTaskId = currentTaskId
        self.conversationHistory = conversationHistory
        self.createdAt = createdAt
        self.totalTasksCompleted = totalTasksCompleted
        self.characterAppearance = characterAppearance
        let primaryRole = jobRoles.first ?? .general
        self.personality = personality ?? Self.generatePersonality(from: id, jobRole: primaryRole)
        self.strengths = strengths ?? Self.generateStrengths(from: id, jobRole: primaryRole)
        self.workStyle = workStyle ?? Self.generateWorkStyle(from: id, jobRole: primaryRole)
        self.statistics = statistics ?? EmployeeStatistics()
    }

    /// UUID 기반 사원번호 생성
    static func generateEmployeeNumber(from id: UUID) -> String {
        let hash = abs(id.hashValue)
        let number = hash % 10000
        return String(format: "EMP-%04d", number)
    }

    /// ID와 직군 기반 성격 자동 생성
    static func generatePersonality(from id: UUID, jobRole: JobRole) -> String {
        // 부서별 성격 풀 (부서 단위로 그룹화)
        let personalitiesByDepartment: [DepartmentType: [String]] = [
            .planning: [
                "체계적이고 리더십 있는", "전략적이고 추진력 있는", "커뮤니케이션이 뛰어난",
                "분석적이고 의사결정이 빠른", "비전이 명확하고 실행력 있는"
            ],
            .design: [
                "창의적이고 감각적인", "디테일에 집중하는", "미적 감각이 뛰어난",
                "트렌디하고 혁신적인", "사용자 중심적이고 공감력 있는"
            ],
            .development: [
                "논리적이고 체계적인", "꼼꼼하고 세밀한", "최신 기술에 열정적인",
                "문제 해결력이 뛰어난", "효율성을 추구하는"
            ],
            .qa: [
                "꼼꼼하고 철저한", "분석적이고 체계적인", "품질에 집착하는",
                "논리적이고 비판적인", "예리하고 세심한"
            ],
            .marketing: [
                "창의적이고 소통에 능한", "트렌드에 민감한", "데이터 기반 사고를 하는",
                "열정적이고 설득력 있는", "고객 관점에서 생각하는"
            ],
            .general: [
                "다재다능하고 적응력 있는", "협업을 중시하는", "성실하고 책임감 있는",
                "유연하고 긍정적인", "배움에 열린"
            ]
        ]

        let department = jobRole.department
        let personalities = personalitiesByDepartment[department] ?? personalitiesByDepartment[.general]!
        let index = abs(id.hashValue) % personalities.count
        return personalities[index]
    }

    /// ID와 직군 기반 강점 자동 생성
    static func generateStrengths(from id: UUID, jobRole: JobRole) -> [String] {
        // 부서별 강점 풀 (각각 5개 세트)
        let strengthsByDepartment: [DepartmentType: [[String]]] = [
            .planning: [
                ["리더십", "프로젝트 관리", "의사소통"],
                ["전략 수립", "일정 관리", "리스크 관리"],
                ["요구사항 정의", "기획서 작성", "데이터 분석"],
                ["우선순위 결정", "자원 배분", "문제 해결"],
                ["문서화", "보고 능력", "협상력"]
            ],
            .design: [
                ["UI/UX 디자인", "비주얼 디자인", "프로토타이핑"],
                ["사용자 조사", "와이어프레임", "컬러 감각"],
                ["타이포그래피", "레이아웃 구성", "인터랙션 디자인"],
                ["디자인 시스템", "브랜딩", "일러스트"],
                ["사용자 테스트", "피그마/스케치", "디테일 감각"]
            ],
            .development: [
                ["코딩", "아키텍처 설계", "문제 해결"],
                ["알고리즘", "데이터베이스", "API 설계"],
                ["성능 최적화", "버그 수정", "코드 리뷰"],
                ["테스트 작성", "배포 자동화", "기술 문서화"],
                ["새로운 기술 학습", "협업 능력", "디버깅"]
            ],
            .qa: [
                ["테스트 계획", "버그 리포팅", "자동화 테스트"],
                ["회귀 테스트", "성능 테스트", "보안 테스트"],
                ["테스트 케이스 작성", "API 테스트", "UI 테스트"],
                ["테스트 자동화 프레임워크", "버그 추적", "품질 메트릭"],
                ["통합 테스트", "부하 테스트", "테스트 전략 수립"]
            ],
            .marketing: [
                ["콘텐츠 마케팅", "SNS 운영", "캠페인 기획"],
                ["SEO/SEM", "데이터 분석", "퍼포먼스 마케팅"],
                ["브랜딩", "카피라이팅", "타겟팅"],
                ["그로스 해킹", "A/B 테스팅", "전환율 최적화"],
                ["커뮤니티 관리", "인플루언서 마케팅", "이메일 마케팅"]
            ],
            .general: [
                ["빠른 학습", "문서 작성", "협업"],
                ["커뮤니케이션", "문제 해결", "시간 관리"],
                ["적응력", "책임감", "성실함"],
                ["멀티태스킹", "자기주도 학습", "긍정적 태도"],
                ["팀워크", "유연성", "꼼꼼함"]
            ]
        ]

        let department = jobRole.department
        let strengths = strengthsByDepartment[department] ?? strengthsByDepartment[.general]!
        let index = abs(id.hashValue) % strengths.count
        return strengths[index]
    }

    /// ID와 직군 기반 업무 스타일 자동 생성
    static func generateWorkStyle(from id: UUID, jobRole: JobRole) -> String {
        // 부서별 업무 스타일
        let workStylesByDepartment: [DepartmentType: [String]] = [
            .planning: [
                "체계적으로 계획하고 팀을 이끌며 진행",
                "명확한 목표 설정 후 단계별 마일스톤 관리",
                "이해관계자들과 긴밀히 소통하며 조율",
                "데이터 기반으로 의사결정하고 실행",
                "리스크를 미리 파악하고 대응 방안 준비"
            ],
            .design: [
                "사용자 조사를 바탕으로 디자인 방향 설정",
                "빠르게 프로토타입을 만들고 피드백 반영",
                "레퍼런스를 수집하고 트렌드를 분석",
                "디테일에 집중하며 완성도 높은 결과물 추구",
                "팀과 협업하며 디자인 시스템 일관성 유지"
            ],
            .development: [
                "기능을 모듈화하고 재사용성을 고려하며 개발",
                "빠르게 구현하고 리팩토링으로 개선",
                "테스트 코드를 작성하며 안정성 확보",
                "성능을 모니터링하고 병목을 최적화",
                "문서화를 통해 팀과 지식 공유"
            ],
            .qa: [
                "체계적인 테스트 계획을 수립하고 실행",
                "꼼꼼하게 엣지 케이스까지 검증",
                "버그를 발견하면 재현 과정을 명확히 문서화",
                "자동화 테스트를 구축하며 회귀 테스트 강화",
                "품질 메트릭을 추적하고 개선점 제안"
            ],
            .marketing: [
                "타겟 고객을 분석하고 맞춤형 전략 수립",
                "빠르게 캠페인을 실행하고 데이터로 개선",
                "트렌드를 파악하고 창의적인 아이디어 제안",
                "A/B 테스트로 최적의 메시지 찾기",
                "팀과 협업하며 통합 마케팅 전략 실행"
            ],
            .general: [
                "체계적으로 계획하고 단계별로 실행",
                "팀과 긴밀히 협업하며 진행",
                "독립적으로 집중해서 완성",
                "유연하게 상황에 맞춰 대응",
                "배우며 성장하는 자세로 임함"
            ]
        ]

        let department = jobRole.department
        let workStyles = workStylesByDepartment[department] ?? workStylesByDepartment[.general]!
        let index = abs(id.hashValue) % workStyles.count
        return workStyles[index]
    }

    // MARK: - Codable (기존 데이터 호환)
    enum CodingKeys: String, CodingKey {
        case id, employeeNumber, name, aiType, jobRole, jobRoles, status, currentTaskId
        case conversationHistory, createdAt, totalTasksCompleted, characterAppearance
        case personality, strengths, workStyle, statistics
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        aiType = try container.decode(AIType.self, forKey: .aiType)

        // 기존 데이터 호환: jobRole (단일) → jobRoles (배열)
        if let roles = try? container.decode([JobRole].self, forKey: .jobRoles) {
            jobRoles = roles.isEmpty ? [.general] : roles
        } else if let role = try? container.decode(JobRole.self, forKey: .jobRole) {
            jobRoles = [role]
        } else {
            jobRoles = [.general]
        }

        status = try container.decode(EmployeeStatus.self, forKey: .status)
        currentTaskId = try container.decodeIfPresent(UUID.self, forKey: .currentTaskId)
        conversationHistory = try container.decode([Message].self, forKey: .conversationHistory)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        totalTasksCompleted = try container.decode(Int.self, forKey: .totalTasksCompleted)
        characterAppearance = try container.decode(CharacterAppearance.self, forKey: .characterAppearance)
        // 기존 데이터에 employeeNumber가 없으면 자동 생성
        employeeNumber = try container.decodeIfPresent(String.self, forKey: .employeeNumber) ?? Self.generateEmployeeNumber(from: id)
        // 기존 데이터에 특성 정보가 없으면 자동 생성
        let primaryRole = jobRoles.first ?? .general
        personality = try container.decodeIfPresent(String.self, forKey: .personality) ?? Self.generatePersonality(from: id, jobRole: primaryRole)
        strengths = try container.decodeIfPresent([String].self, forKey: .strengths) ?? Self.generateStrengths(from: id, jobRole: primaryRole)
        workStyle = try container.decodeIfPresent(String.self, forKey: .workStyle) ?? Self.generateWorkStyle(from: id, jobRole: primaryRole)
        // 기존 데이터에 통계 정보가 없으면 초기화
        statistics = try container.decodeIfPresent(EmployeeStatistics.self, forKey: .statistics) ?? EmployeeStatistics()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(employeeNumber, forKey: .employeeNumber)
        try container.encode(name, forKey: .name)
        try container.encode(aiType, forKey: .aiType)
        try container.encode(jobRoles, forKey: .jobRoles)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(currentTaskId, forKey: .currentTaskId)
        try container.encode(conversationHistory, forKey: .conversationHistory)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(totalTasksCompleted, forKey: .totalTasksCompleted)
        try container.encode(characterAppearance, forKey: .characterAppearance)
        try container.encode(personality, forKey: .personality)
        try container.encode(strengths, forKey: .strengths)
        try container.encode(workStyle, forKey: .workStyle)
        try container.encode(statistics, forKey: .statistics)
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

    /// 주 직군 (첫 번째 직군)
    var primaryJobRole: JobRole {
        jobRoles.first ?? .general
    }

    /// 부서 (주 직군 기준)
    var department: DepartmentType {
        primaryJobRole.department
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
    static func skinToneName(_ tone: Int) -> String {
        switch tone {
        case 0: return "밝은 톤"
        case 1: return "중간 톤"
        case 2: return "황갈색 톤"
        case 3: return "어두운 톤"
        default: return "밝은 톤"
        }
    }

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

// MARK: - 직원 활동 통계
struct EmployeeStatistics: Codable, Hashable {
    // 토큰 사용량
    var totalTokensUsed: Int  // 총 사용한 토큰
    var inputTokens: Int      // 입력 토큰
    var outputTokens: Int     // 출력 토큰

    // 토큰 사용 기록 (시간별)
    var tokenUsageHistory: [TokenUsageRecord]

    // 생산성
    var documentsCreated: Int    // 작성한 문서 수
    var tasksCompleted: Int      // 완료한 태스크 수
    var conversationCount: Int   // 대화 횟수
    var collaborationCount: Int  // 협업 횟수

    // 시간 추적
    var totalActiveTime: TimeInterval  // 총 활동 시간 (초)
    var lastActiveDate: Date?          // 마지막 활동 시간

    init(
        totalTokensUsed: Int = 0,
        inputTokens: Int = 0,
        outputTokens: Int = 0,
        tokenUsageHistory: [TokenUsageRecord] = [],
        documentsCreated: Int = 0,
        tasksCompleted: Int = 0,
        conversationCount: Int = 0,
        collaborationCount: Int = 0,
        totalActiveTime: TimeInterval = 0,
        lastActiveDate: Date? = nil
    ) {
        self.totalTokensUsed = totalTokensUsed
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.tokenUsageHistory = tokenUsageHistory
        self.documentsCreated = documentsCreated
        self.tasksCompleted = tasksCompleted
        self.conversationCount = conversationCount
        self.collaborationCount = collaborationCount
        self.totalActiveTime = totalActiveTime
        self.lastActiveDate = lastActiveDate
    }

    /// 평균 토큰 소비 속도 (토큰/시간)
    var tokensPerHour: Double {
        guard totalActiveTime > 0 else { return 0 }
        let hours = totalActiveTime / 3600.0
        return Double(totalTokensUsed) / hours
    }

    /// 최근 24시간 토큰 사용량
    var tokensLast24Hours: Int {
        let oneDayAgo = Date().addingTimeInterval(-24 * 3600)
        return tokenUsageHistory
            .filter { $0.timestamp > oneDayAgo }
            .reduce(0) { $0 + $1.tokens }
    }

    /// 토큰 사용량 기록 추가
    mutating func addTokenUsage(input: Int, output: Int) {
        let total = input + output
        totalTokensUsed += total
        inputTokens += input
        outputTokens += output

        let record = TokenUsageRecord(
            timestamp: Date(),
            tokens: total,
            inputTokens: input,
            outputTokens: output
        )
        tokenUsageHistory.append(record)

        // 최대 1000개 기록만 유지 (메모리 관리)
        if tokenUsageHistory.count > 1000 {
            tokenUsageHistory.removeFirst(tokenUsageHistory.count - 1000)
        }
    }

    /// 문서 작성 카운트 증가
    mutating func incrementDocuments() {
        documentsCreated += 1
    }

    /// 태스크 완료 카운트 증가
    mutating func incrementTasks() {
        tasksCompleted += 1
    }

    /// 대화 카운트 증가
    mutating func incrementConversations() {
        conversationCount += 1
    }

    /// 협업 카운트 증가
    mutating func incrementCollaborations() {
        collaborationCount += 1
    }

    /// 활동 시간 업데이트
    mutating func updateActiveTime(duration: TimeInterval) {
        totalActiveTime += duration
        lastActiveDate = Date()
    }
}

/// 토큰 사용 기록
struct TokenUsageRecord: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var timestamp: Date
    var tokens: Int
    var inputTokens: Int
    var outputTokens: Int

    init(
        id: UUID = UUID(),
        timestamp: Date,
        tokens: Int,
        inputTokens: Int,
        outputTokens: Int
    ) {
        self.id = id
        self.timestamp = timestamp
        self.tokens = tokens
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }
}
