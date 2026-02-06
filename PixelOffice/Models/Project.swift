import Foundation
import SwiftUI

struct Project: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var description: String
    var status: ProjectStatus
    var tasks: [ProjectTask]
    var createdAt: Date
    var updatedAt: Date
    var deadline: Date?
    var tags: [String]
    var priority: ProjectPriority
    var departments: [ProjectDepartment]  // 프로젝트별 부서 및 직원
    var sprints: [Sprint]  // 스프린트 목록
    var projectContext: String  // 프로젝트 주요 정보 및 컨텍스트

    /// 현재 활성 스프린트
    var activeSprint: Sprint? {
        sprints.first { $0.isActive }
    }

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        status: ProjectStatus = .planning,
        tasks: [ProjectTask] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deadline: Date? = nil,
        tags: [String] = [],
        priority: ProjectPriority = .medium,
        departments: [ProjectDepartment] = ProjectDepartment.defaultProjectDepartments,
        sprints: [Sprint] = [],
        projectContext: String = ""
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.status = status
        self.tasks = tasks
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deadline = deadline
        self.tags = tags
        self.priority = priority
        self.departments = departments
        self.sprints = sprints
        self.projectContext = projectContext
    }

    // MARK: - Codable (하위 호환성)

    enum CodingKeys: String, CodingKey {
        case id, name, description, status, tasks, createdAt, updatedAt, deadline, tags, priority, departments, sprints, projectContext
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        status = try container.decode(ProjectStatus.self, forKey: .status)
        tasks = try container.decode([ProjectTask].self, forKey: .tasks)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        deadline = try container.decodeIfPresent(Date.self, forKey: .deadline)
        tags = try container.decode([String].self, forKey: .tags)
        priority = try container.decode(ProjectPriority.self, forKey: .priority)
        // 기존 데이터 호환: departments가 없으면 기본값 사용
        departments = try container.decodeIfPresent([ProjectDepartment].self, forKey: .departments)
            ?? ProjectDepartment.defaultProjectDepartments
        // 기존 데이터 호환: sprints가 없으면 빈 배열 사용
        sprints = try container.decodeIfPresent([Sprint].self, forKey: .sprints) ?? []
        // 기존 데이터 호환: projectContext가 없으면 빈 문자열 사용
        projectContext = try container.decodeIfPresent(String.self, forKey: .projectContext) ?? ""
    }
    
    static func == (lhs: Project, rhs: Project) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    var progress: Double {
        guard !tasks.isEmpty else { return 0 }
        let completed = tasks.filter { $0.status == .done }.count
        return Double(completed) / Double(tasks.count)
    }
    
    var completedTasksCount: Int {
        tasks.filter { $0.status == .done }.count
    }
    
    var pendingTasksCount: Int {
        tasks.filter { $0.status == .todo }.count
    }
    
    var inProgressTasksCount: Int {
        tasks.filter { $0.status == .inProgress }.count
    }
    
    mutating func addTask(_ task: ProjectTask) {
        tasks.append(task)
        updatedAt = Date()
    }
    
    mutating func removeTask(_ taskId: UUID) {
        tasks.removeAll { $0.id == taskId }
        updatedAt = Date()
    }
    
    mutating func updateTask(_ task: ProjectTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
            updatedAt = Date()
        }
    }
    
    func getTask(byId id: UUID) -> ProjectTask? {
        tasks.first { $0.id == id }
    }

    // MARK: - Project Employee Operations

    /// 프로젝트의 모든 직원
    var allEmployees: [ProjectEmployee] {
        departments.flatMap { $0.employees }
    }

    /// 작업 중인 직원
    var workingEmployees: [ProjectEmployee] {
        allEmployees.filter { $0.isWorking }
    }

    /// 직원 추가
    mutating func addEmployee(_ employee: ProjectEmployee, toDepartment departmentType: DepartmentType) {
        if let index = departments.firstIndex(where: { $0.type == departmentType }) {
            departments[index].employees.append(employee)
            updatedAt = Date()
        }
    }

    /// 직원 제거
    mutating func removeEmployee(_ employeeId: UUID) {
        for i in departments.indices {
            departments[i].employees.removeAll { $0.id == employeeId }
        }
        updatedAt = Date()
    }

    /// ID로 직원 찾기
    func getEmployee(byId id: UUID) -> ProjectEmployee? {
        allEmployees.first { $0.id == id }
    }

    /// 직원이 속한 부서 찾기
    func getDepartment(forEmployee employeeId: UUID) -> ProjectDepartment? {
        departments.first { dept in
            dept.employees.contains { $0.id == employeeId }
        }
    }

    /// 부서 타입으로 부서 찾기
    func getDepartment(byType type: DepartmentType) -> ProjectDepartment? {
        departments.first { $0.type == type }
    }
}

enum ProjectStatus: String, Codable, CaseIterable {
    case planning = "기획 중"
    case inProgress = "진행 중"
    case review = "검토 중"
    case completed = "완료"
    case onHold = "보류"
    case cancelled = "취소"
    
    var color: Color {
        switch self {
        case .planning: return .yellow
        case .inProgress: return .blue
        case .review: return .purple
        case .completed: return .green
        case .onHold: return .orange
        case .cancelled: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .planning: return "doc.text.magnifyingglass"
        case .inProgress: return "play.circle.fill"
        case .review: return "eye.fill"
        case .completed: return "checkmark.circle.fill"
        case .onHold: return "pause.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }
}

enum ProjectPriority: String, Codable, CaseIterable {
    case low = "낮음"
    case medium = "보통"
    case high = "높음"
    case urgent = "긴급"
    
    var color: Color {
        switch self {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .urgent: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .low: return "arrow.down"
        case .medium: return "minus"
        case .high: return "arrow.up"
        case .urgent: return "exclamationmark.2"
        }
    }
}
