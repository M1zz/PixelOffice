import Foundation
import SwiftUI

struct ProjectTask: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var description: String
    var status: TaskStatus
    var assigneeId: UUID?
    var departmentType: DepartmentType
    var conversation: [Message]
    var outputs: [TaskOutput]
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
    var estimatedHours: Double?
    var actualHours: Double?
    var prompt: String
    var sprintId: UUID?  // 스프린트 할당

    // 워크플로우 관련
    var workflowHistory: [WorkflowTransition]
    var parentTaskId: UUID?

    enum CodingKeys: String, CodingKey {
        case id, title, description, status, assigneeId, departmentType
        case conversation, outputs, createdAt, updatedAt, completedAt
        case estimatedHours, actualHours, prompt, workflowHistory, parentTaskId, sprintId
    }

    init(
        id: UUID = UUID(),
        title: String,
        description: String = "",
        status: TaskStatus = .todo,
        assigneeId: UUID? = nil,
        departmentType: DepartmentType = .general,
        conversation: [Message] = [],
        outputs: [TaskOutput] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        completedAt: Date? = nil,
        estimatedHours: Double? = nil,
        actualHours: Double? = nil,
        prompt: String = "",
        workflowHistory: [WorkflowTransition] = [],
        parentTaskId: UUID? = nil,
        sprintId: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.status = status
        self.assigneeId = assigneeId
        self.departmentType = departmentType
        self.conversation = conversation
        self.outputs = outputs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
        self.estimatedHours = estimatedHours
        self.actualHours = actualHours
        self.prompt = prompt
        self.workflowHistory = workflowHistory
        self.parentTaskId = parentTaskId
        self.sprintId = sprintId
    }

    // 기존 저장 파일 호환성
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        status = try container.decode(TaskStatus.self, forKey: .status)
        assigneeId = try container.decodeIfPresent(UUID.self, forKey: .assigneeId)
        departmentType = try container.decode(DepartmentType.self, forKey: .departmentType)
        conversation = try container.decode([Message].self, forKey: .conversation)
        outputs = try container.decode([TaskOutput].self, forKey: .outputs)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        estimatedHours = try container.decodeIfPresent(Double.self, forKey: .estimatedHours)
        actualHours = try container.decodeIfPresent(Double.self, forKey: .actualHours)
        prompt = try container.decodeIfPresent(String.self, forKey: .prompt) ?? ""
        // 새 필드는 없으면 기본값
        workflowHistory = try container.decodeIfPresent([WorkflowTransition].self, forKey: .workflowHistory) ?? []
        parentTaskId = try container.decodeIfPresent(UUID.self, forKey: .parentTaskId)
        sprintId = try container.decodeIfPresent(UUID.self, forKey: .sprintId)
    }
    
    static func == (lhs: ProjectTask, rhs: ProjectTask) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    var isAssigned: Bool {
        assigneeId != nil
    }
    
    var isInProgress: Bool {
        status == .inProgress
    }
    
    var isCompleted: Bool {
        status == .done
    }
    
    mutating func assign(to employeeId: UUID) {
        assigneeId = employeeId
        updatedAt = Date()
    }
    
    mutating func unassign() {
        assigneeId = nil
        updatedAt = Date()
    }
    
    mutating func start() {
        status = .inProgress
        updatedAt = Date()
    }
    
    mutating func complete() {
        status = .done
        completedAt = Date()
        updatedAt = Date()
    }
    
    mutating func addMessage(_ message: Message) {
        conversation.append(message)
        updatedAt = Date()
    }
    
    mutating func addOutput(_ output: TaskOutput) {
        outputs.append(output)
        updatedAt = Date()
    }

    /// 다음 부서로 태스크 이동
    mutating func moveToDepartment(_ newDepartment: DepartmentType, note: String = "") {
        let transition = WorkflowTransition(
            fromDepartment: departmentType,
            toDepartment: newDepartment,
            note: note
        )
        workflowHistory.append(transition)
        departmentType = newDepartment
        assigneeId = nil  // 새 부서에서 다시 할당 필요
        status = .todo
        updatedAt = Date()
    }

    /// 다음 단계로 이동 가능한지 확인
    var canMoveToNextStage: Bool {
        status == .done && !departmentType.nextDepartments.isEmpty
    }

    /// 현재 워크플로우 단계
    var currentWorkflowStage: String {
        departmentType.workflowStageName
    }
}

/// 워크플로우 이동 기록
struct WorkflowTransition: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var fromDepartment: DepartmentType
    var toDepartment: DepartmentType
    var transitionDate: Date
    var note: String

    init(
        id: UUID = UUID(),
        fromDepartment: DepartmentType,
        toDepartment: DepartmentType,
        transitionDate: Date = Date(),
        note: String = ""
    ) {
        self.id = id
        self.fromDepartment = fromDepartment
        self.toDepartment = toDepartment
        self.transitionDate = transitionDate
        self.note = note
    }
}

enum TaskStatus: String, Codable, CaseIterable {
    case backlog = "백로그"
    case todo = "할일"
    case inProgress = "진행중"
    case done = "완료"
    case needsReview = "검토필요"
    case rejected = "반려됨"

    var color: Color {
        switch self {
        case .backlog: return .secondary
        case .todo: return .gray
        case .inProgress: return .blue
        case .done: return .green
        case .needsReview: return .orange
        case .rejected: return .red
        }
    }

    var icon: String {
        switch self {
        case .backlog: return "tray"
        case .todo: return "circle"
        case .inProgress: return "circle.lefthalf.filled"
        case .done: return "checkmark.circle.fill"
        case .needsReview: return "eye.circle"
        case .rejected: return "xmark.circle"
        }
    }
}

struct TaskOutput: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var type: OutputType
    var content: String
    var fileName: String?
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        type: OutputType,
        content: String,
        fileName: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.fileName = fileName
        self.createdAt = createdAt
    }
}

enum OutputType: String, Codable {
    case text = "텍스트"
    case code = "코드"
    case image = "이미지"
    case file = "파일"
    case document = "문서"
    
    var icon: String {
        switch self {
        case .text: return "doc.text"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .image: return "photo"
        case .file: return "doc"
        case .document: return "doc.richtext"
        }
    }
}
