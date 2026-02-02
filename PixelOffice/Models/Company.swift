import Foundation

struct Company: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var departments: [Department]
    var projects: [Project]
    var settings: CompanySettings
    var createdAt: Date
    var updatedAt: Date

    // 위키 및 온보딩
    var wikiDocuments: [WikiDocument]
    var employeeOnboardings: [EmployeeOnboarding]

    enum CodingKeys: String, CodingKey {
        case id, name, departments, projects, settings, createdAt, updatedAt
        case wikiDocuments, employeeOnboardings
    }

    init(
        id: UUID = UUID(),
        name: String = "My Pixel Office",
        departments: [Department] = Department.defaultDepartments,
        projects: [Project] = [],
        settings: CompanySettings = CompanySettings(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        wikiDocuments: [WikiDocument] = [],
        employeeOnboardings: [EmployeeOnboarding] = []
    ) {
        self.id = id
        self.name = name
        self.departments = departments
        self.projects = projects
        self.settings = settings
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.wikiDocuments = wikiDocuments
        self.employeeOnboardings = employeeOnboardings
    }

    // 기존 저장 파일 호환성을 위한 커스텀 디코더
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        departments = try container.decode([Department].self, forKey: .departments)
        projects = try container.decode([Project].self, forKey: .projects)
        settings = try container.decode(CompanySettings.self, forKey: .settings)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        // 새 필드는 없으면 빈 배열로
        wikiDocuments = try container.decodeIfPresent([WikiDocument].self, forKey: .wikiDocuments) ?? []
        employeeOnboardings = try container.decodeIfPresent([EmployeeOnboarding].self, forKey: .employeeOnboardings) ?? []
    }
    
    var allEmployees: [Employee] {
        departments.flatMap { $0.employees }
    }
    
    var workingEmployees: [Employee] {
        allEmployees.filter { $0.status == .working }
    }
    
    var idleEmployees: [Employee] {
        allEmployees.filter { $0.status == .idle }
    }
    
    mutating func addEmployee(_ employee: Employee, toDepartment departmentId: UUID) {
        if let index = departments.firstIndex(where: { $0.id == departmentId }) {
            departments[index].employees.append(employee)
            updatedAt = Date()
        }
    }
    
    mutating func removeEmployee(_ employeeId: UUID) {
        for i in departments.indices {
            departments[i].employees.removeAll { $0.id == employeeId }
        }
        updatedAt = Date()
    }
    
    mutating func updateEmployeeStatus(_ employeeId: UUID, status: EmployeeStatus) {
        for i in departments.indices {
            if let j = departments[i].employees.firstIndex(where: { $0.id == employeeId }) {
                departments[i].employees[j].status = status
                updatedAt = Date()
                return
            }
        }
    }
    
    mutating func addProject(_ project: Project) {
        projects.append(project)
        updatedAt = Date()
    }
    
    mutating func removeProject(_ projectId: UUID) {
        projects.removeAll { $0.id == projectId }
        updatedAt = Date()
    }
    
    func getEmployee(byId id: UUID) -> Employee? {
        allEmployees.first { $0.id == id }
    }
    
    func getDepartment(forEmployee employeeId: UUID) -> Department? {
        departments.first { dept in
            dept.employees.contains { $0.id == employeeId }
        }
    }
}

struct CompanySettings: Codable {
    var apiConfigurations: [APIConfiguration]
    var autoSaveEnabled: Bool
    var cloudSyncEnabled: Bool
    var notificationsEnabled: Bool
    var wikiSettings: WikiSettings?

    enum CodingKeys: String, CodingKey {
        case apiConfigurations, autoSaveEnabled, cloudSyncEnabled, notificationsEnabled, wikiSettings
    }

    init(
        apiConfigurations: [APIConfiguration] = [],
        autoSaveEnabled: Bool = true,
        cloudSyncEnabled: Bool = false,
        notificationsEnabled: Bool = true,
        wikiSettings: WikiSettings? = WikiSettings()
    ) {
        self.apiConfigurations = apiConfigurations
        self.autoSaveEnabled = autoSaveEnabled
        self.cloudSyncEnabled = cloudSyncEnabled
        self.notificationsEnabled = notificationsEnabled
        self.wikiSettings = wikiSettings
    }

    // 기존 저장 파일 호환성
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        apiConfigurations = try container.decodeIfPresent([APIConfiguration].self, forKey: .apiConfigurations) ?? []
        autoSaveEnabled = try container.decodeIfPresent(Bool.self, forKey: .autoSaveEnabled) ?? true
        cloudSyncEnabled = try container.decodeIfPresent(Bool.self, forKey: .cloudSyncEnabled) ?? false
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? true
        wikiSettings = try container.decodeIfPresent(WikiSettings.self, forKey: .wikiSettings)
    }
}
