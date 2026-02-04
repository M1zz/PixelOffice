import Foundation
import SwiftUI

/// 프로젝트에 배정된 직원 (프로젝트별로 독립적인 대화 히스토리 가짐)
struct ProjectEmployee: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var employeeNumber: String  // 사원번호 (예: PRJ-0001)
    var sourceEmployeeId: UUID?  // 회사 직원에서 복제한 경우 원본 참조
    var name: String
    var aiType: AIType
    var jobRoles: [JobRole]  // 직군 (멀티 선택 가능)
    var status: EmployeeStatus
    var currentTaskId: UUID?
    var conversationHistory: [Message]  // 프로젝트별 독립 대화 히스토리
    var createdAt: Date
    var totalTasksCompleted: Int
    var characterAppearance: CharacterAppearance
    var departmentType: DepartmentType

    // 직원 특성 정보
    var personality: String  // 성격: 꼼꼼함, 창의적, 분석적 등
    var strengths: [String]  // 강점 리스트
    var workStyle: String    // 업무 스타일

    // 활동 통계
    var statistics: EmployeeStatistics

    init(
        id: UUID = UUID(),
        employeeNumber: String? = nil,
        sourceEmployeeId: UUID? = nil,
        name: String,
        aiType: AIType = .claude,
        jobRoles: [JobRole] = [.general],
        status: EmployeeStatus = .idle,
        currentTaskId: UUID? = nil,
        conversationHistory: [Message] = [],
        createdAt: Date = Date(),
        totalTasksCompleted: Int = 0,
        characterAppearance: CharacterAppearance = CharacterAppearance(),
        departmentType: DepartmentType = .general,
        personality: String? = nil,
        strengths: [String]? = nil,
        workStyle: String? = nil,
        statistics: EmployeeStatistics? = nil
    ) {
        self.id = id
        self.employeeNumber = employeeNumber ?? Self.generateEmployeeNumber(from: id)
        self.sourceEmployeeId = sourceEmployeeId
        self.name = name
        self.aiType = aiType
        self.jobRoles = jobRoles.isEmpty ? [.general] : jobRoles
        self.status = status
        self.currentTaskId = currentTaskId
        self.conversationHistory = conversationHistory
        self.createdAt = createdAt
        self.totalTasksCompleted = totalTasksCompleted
        self.characterAppearance = characterAppearance
        self.departmentType = departmentType
        let primaryRole = jobRoles.first ?? .general
        self.personality = personality ?? Employee.generatePersonality(from: id, jobRole: primaryRole)
        self.strengths = strengths ?? Employee.generateStrengths(from: id, jobRole: primaryRole)
        self.workStyle = workStyle ?? Employee.generateWorkStyle(from: id, jobRole: primaryRole)
        self.statistics = statistics ?? EmployeeStatistics()
    }

    /// UUID 기반 사원번호 생성
    static func generateEmployeeNumber(from id: UUID) -> String {
        let hash = abs(id.hashValue)
        let number = hash % 10000
        return String(format: "PRJ-%04d", number)
    }

    // MARK: - Codable (기존 데이터 호환)
    enum CodingKeys: String, CodingKey {
        case id, employeeNumber, sourceEmployeeId, name, aiType, jobRole, jobRoles, status, currentTaskId
        case conversationHistory, createdAt, totalTasksCompleted, characterAppearance, departmentType
        case personality, strengths, workStyle, statistics
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        sourceEmployeeId = try container.decodeIfPresent(UUID.self, forKey: .sourceEmployeeId)
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
        departmentType = try container.decode(DepartmentType.self, forKey: .departmentType)
        // 기존 데이터에 employeeNumber가 없으면 자동 생성
        employeeNumber = try container.decodeIfPresent(String.self, forKey: .employeeNumber) ?? Self.generateEmployeeNumber(from: id)
        // 기존 데이터에 특성 정보가 없으면 자동 생성
        let primaryRole = jobRoles.first ?? .general
        personality = try container.decodeIfPresent(String.self, forKey: .personality) ?? Employee.generatePersonality(from: id, jobRole: primaryRole)
        strengths = try container.decodeIfPresent([String].self, forKey: .strengths) ?? Employee.generateStrengths(from: id, jobRole: primaryRole)
        workStyle = try container.decodeIfPresent(String.self, forKey: .workStyle) ?? Employee.generateWorkStyle(from: id, jobRole: primaryRole)
        // 기존 데이터에 통계 정보가 없으면 초기화
        statistics = try container.decodeIfPresent(EmployeeStatistics.self, forKey: .statistics) ?? EmployeeStatistics()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(employeeNumber, forKey: .employeeNumber)
        try container.encodeIfPresent(sourceEmployeeId, forKey: .sourceEmployeeId)
        try container.encode(name, forKey: .name)
        try container.encode(aiType, forKey: .aiType)
        try container.encode(jobRoles, forKey: .jobRoles)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(currentTaskId, forKey: .currentTaskId)
        try container.encode(conversationHistory, forKey: .conversationHistory)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(totalTasksCompleted, forKey: .totalTasksCompleted)
        try container.encode(characterAppearance, forKey: .characterAppearance)
        try container.encode(departmentType, forKey: .departmentType)
        try container.encode(personality, forKey: .personality)
        try container.encode(strengths, forKey: .strengths)
        try container.encode(workStyle, forKey: .workStyle)
        try container.encode(statistics, forKey: .statistics)
    }

    /// 회사 직원으로부터 프로젝트 직원 생성 (대화 히스토리는 초기화)
    static func from(employee: Employee, departmentType: DepartmentType) -> ProjectEmployee {
        ProjectEmployee(
            sourceEmployeeId: employee.id,
            name: employee.name,
            aiType: employee.aiType,
            jobRoles: employee.jobRoles,
            status: .idle,
            conversationHistory: [],  // 대화 히스토리 초기화
            createdAt: Date(),
            totalTasksCompleted: 0,
            characterAppearance: employee.characterAppearance,
            departmentType: departmentType,
            personality: employee.personality,
            strengths: employee.strengths,
            workStyle: employee.workStyle
        )
    }

    static func == (lhs: ProjectEmployee, rhs: ProjectEmployee) -> Bool {
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
