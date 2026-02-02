import Foundation
import SwiftUI

/// 프로젝트에 배정된 직원 (프로젝트별로 독립적인 대화 히스토리 가짐)
struct ProjectEmployee: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
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
