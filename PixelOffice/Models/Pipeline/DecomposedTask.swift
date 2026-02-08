import Foundation
import SwiftUI

/// 분해된 태스크 상태
enum DecomposedTaskStatus: String, Codable, CaseIterable {
    case pending = "대기"
    case running = "실행중"
    case completed = "완료"
    case failed = "실패"
    case skipped = "건너뜀"

    var icon: String {
        switch self {
        case .pending: return "circle"
        case .running: return "circle.lefthalf.filled"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .skipped: return "arrow.right.circle"
        }
    }

    var color: Color {
        switch self {
        case .pending: return .secondary
        case .running: return .blue
        case .completed: return .green
        case .failed: return .red
        case .skipped: return .gray
        }
    }
}

/// AI에 의해 분해된 태스크
struct DecomposedTask: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var description: String
    var department: DepartmentType
    var priority: TaskPriority
    var dependencies: [UUID] = []
    var status: DecomposedTaskStatus = .pending
    var createdFiles: [String] = []
    var modifiedFiles: [String] = []
    var prompt: String = ""
    var response: String = ""
    var error: String?
    var startedAt: Date?
    var completedAt: Date?
    var assignedEmployeeId: UUID?
    var order: Int = 0

    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        department: DepartmentType,
        priority: TaskPriority = .medium,
        dependencies: [UUID] = [],
        order: Int = 0
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.department = department
        self.priority = priority
        self.dependencies = dependencies
        self.order = order
    }

    /// 실행 가능 여부 (의존성 해결됨)
    func canExecute(completedTaskIds: Set<UUID>) -> Bool {
        guard status == .pending else { return false }
        return dependencies.allSatisfy { completedTaskIds.contains($0) }
    }

    /// 소요 시간 (초)
    var duration: TimeInterval? {
        guard let start = startedAt else { return nil }
        let end = completedAt ?? Date()
        return end.timeIntervalSince(start)
    }

    static func == (lhs: DecomposedTask, rhs: DecomposedTask) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - JSON Parsing for Claude Response

/// Claude 응답에서 파싱할 태스크 구조
struct ClaudeTaskResponse: Codable {
    var tasks: [ClaudeTask]
    var summary: String?
    var warnings: [String]?
    var estimatedTime: String?

    struct ClaudeTask: Codable {
        var title: String
        var description: String
        var department: String
        var priority: String?
        var dependencies: [Int]?
        var order: Int?
    }
}

extension DecomposedTask {
    /// Claude 응답에서 변환
    static func from(claudeTask: ClaudeTaskResponse.ClaudeTask, index: Int, allTasks: [ClaudeTaskResponse.ClaudeTask]) -> DecomposedTask {
        let department = DepartmentType.from(string: claudeTask.department)
        let priority = TaskPriority.from(string: claudeTask.priority ?? "medium")

        var task = DecomposedTask(
            title: claudeTask.title,
            description: claudeTask.description,
            department: department,
            priority: priority,
            order: claudeTask.order ?? index
        )

        return task
    }
}

extension DepartmentType {
    static func from(string: String) -> DepartmentType {
        let lowercased = string.lowercased()
        switch lowercased {
        case "기획", "planning", "plan":
            return .planning
        case "디자인", "design":
            return .design
        case "개발", "development", "dev", "engineering":
            return .development
        case "qa", "테스트", "test", "quality":
            return .qa
        case "마케팅", "marketing":
            return .marketing
        default:
            return .development
        }
    }
}

extension TaskPriority {
    static func from(string: String) -> TaskPriority {
        let lowercased = string.lowercased()
        switch lowercased {
        case "low", "낮음":
            return .low
        case "medium", "보통", "normal":
            return .medium
        case "high", "높음":
            return .high
        case "critical", "긴급", "urgent":
            return .critical
        default:
            return .medium
        }
    }
}

// MARK: - DecomposedTask → ProjectTask 변환

extension DecomposedTask {
    /// DecomposedTask를 칸반용 ProjectTask로 변환
    func toProjectTask(pipelineRunId: UUID, sprintId: UUID? = nil) -> ProjectTask {
        // 상태 변환
        let taskStatus: TaskStatus = {
            switch status {
            case .pending: return .todo
            case .running: return .inProgress
            case .completed: return .done
            case .failed: return .needsReview
            case .skipped: return .backlog
            }
        }()

        return ProjectTask(
            title: title,
            description: description,
            status: taskStatus,
            priority: priority,
            assigneeId: assignedEmployeeId,
            departmentType: department,
            prompt: prompt,
            sprintId: sprintId,
            pipelineRunId: pipelineRunId,
            decomposedTaskId: id
        )
    }
}
