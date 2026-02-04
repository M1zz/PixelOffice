import Foundation
import SwiftUI

/// 프로젝트에 배정된 직원 (프로젝트별로 독립적인 대화 히스토리 가짐)
struct ProjectEmployee: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var employeeNumber: String  // 사원번호 (예: PRJ-0001)
    var sourceEmployeeId: UUID?  // 회사 직원에서 복제한 경우 원본 참조
    var name: String
    var aiType: AIType
    var status: EmployeeStatus
    var currentTaskId: UUID?
    var conversationHistory: [Message]  // 프로젝트별 독립 대화 히스토리
    var createdAt: Date
    var totalTasksCompleted: Int
    var characterAppearance: CharacterAppearance
    var departmentType: DepartmentType

    init(
        id: UUID = UUID(),
        employeeNumber: String? = nil,
        sourceEmployeeId: UUID? = nil,
        name: String,
        aiType: AIType = .claude,
        status: EmployeeStatus = .idle,
        currentTaskId: UUID? = nil,
        conversationHistory: [Message] = [],
        createdAt: Date = Date(),
        totalTasksCompleted: Int = 0,
        characterAppearance: CharacterAppearance = CharacterAppearance(),
        departmentType: DepartmentType = .general
    ) {
        self.id = id
        self.employeeNumber = employeeNumber ?? Self.generateEmployeeNumber(from: id)
        self.sourceEmployeeId = sourceEmployeeId
        self.name = name
        self.aiType = aiType
        self.status = status
        self.currentTaskId = currentTaskId
        self.conversationHistory = conversationHistory
        self.createdAt = createdAt
        self.totalTasksCompleted = totalTasksCompleted
        self.characterAppearance = characterAppearance
        self.departmentType = departmentType
    }

    /// UUID 기반 사원번호 생성
    static func generateEmployeeNumber(from id: UUID) -> String {
        let hash = abs(id.hashValue)
        let number = hash % 10000
        return String(format: "PRJ-%04d", number)
    }

    // MARK: - Codable (기존 데이터 호환)
    enum CodingKeys: String, CodingKey {
        case id, employeeNumber, sourceEmployeeId, name, aiType, status, currentTaskId
        case conversationHistory, createdAt, totalTasksCompleted, characterAppearance, departmentType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        sourceEmployeeId = try container.decodeIfPresent(UUID.self, forKey: .sourceEmployeeId)
        name = try container.decode(String.self, forKey: .name)
        aiType = try container.decode(AIType.self, forKey: .aiType)
        status = try container.decode(EmployeeStatus.self, forKey: .status)
        currentTaskId = try container.decodeIfPresent(UUID.self, forKey: .currentTaskId)
        conversationHistory = try container.decode([Message].self, forKey: .conversationHistory)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        totalTasksCompleted = try container.decode(Int.self, forKey: .totalTasksCompleted)
        characterAppearance = try container.decode(CharacterAppearance.self, forKey: .characterAppearance)
        departmentType = try container.decode(DepartmentType.self, forKey: .departmentType)
        // 기존 데이터에 employeeNumber가 없으면 자동 생성
        employeeNumber = try container.decodeIfPresent(String.self, forKey: .employeeNumber) ?? Self.generateEmployeeNumber(from: id)
    }

    /// 회사 직원으로부터 프로젝트 직원 생성 (대화 히스토리는 초기화)
    static func from(employee: Employee, departmentType: DepartmentType) -> ProjectEmployee {
        ProjectEmployee(
            sourceEmployeeId: employee.id,
            name: employee.name,
            aiType: employee.aiType,
            status: .idle,
            conversationHistory: [],  // 대화 히스토리 초기화
            createdAt: Date(),
            totalTasksCompleted: 0,
            characterAppearance: employee.characterAppearance,
            departmentType: departmentType
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
