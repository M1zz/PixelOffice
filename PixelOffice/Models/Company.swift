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

    // 협업 기록
    var collaborationRecords: [CollaborationRecord]

    // 직원 사고 과정 & 커뮤니티 게시글
    var employeeThinkings: [EmployeeThinking]
    var communityPosts: [CommunityPost]

    // 권한 요청 시스템
    var permissionRequests: [PermissionRequest]
    var autoApprovalRules: [AutoApprovalRule]

    enum CodingKeys: String, CodingKey {
        case id, name, departments, projects, settings, createdAt, updatedAt
        case wikiDocuments, employeeOnboardings, collaborationRecords
        case employeeThinkings, communityPosts
        case permissionRequests, autoApprovalRules
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
        employeeOnboardings: [EmployeeOnboarding] = [],
        collaborationRecords: [CollaborationRecord] = [],
        employeeThinkings: [EmployeeThinking] = [],
        communityPosts: [CommunityPost] = [],
        permissionRequests: [PermissionRequest] = [],
        autoApprovalRules: [AutoApprovalRule] = []
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
        self.collaborationRecords = collaborationRecords
        self.employeeThinkings = employeeThinkings
        self.communityPosts = communityPosts
        self.permissionRequests = permissionRequests
        self.autoApprovalRules = autoApprovalRules
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
        collaborationRecords = try container.decodeIfPresent([CollaborationRecord].self, forKey: .collaborationRecords) ?? []
        employeeThinkings = try container.decodeIfPresent([EmployeeThinking].self, forKey: .employeeThinkings) ?? []
        communityPosts = try container.decodeIfPresent([CommunityPost].self, forKey: .communityPosts) ?? []
        permissionRequests = try container.decodeIfPresent([PermissionRequest].self, forKey: .permissionRequests) ?? []
        autoApprovalRules = try container.decodeIfPresent([AutoApprovalRule].self, forKey: .autoApprovalRules) ?? []
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
        // 🔒 중복 체크: ID 또는 이름으로 이미 존재하는 직원인지 확인
        let alreadyExistsById = allEmployees.contains { $0.id == employee.id }
        let alreadyExistsByName = allEmployees.contains { $0.name == employee.name }
        
        if alreadyExistsById || alreadyExistsByName {
            print("⚠️ [Company] 직원 중복 방지: \(employee.name) 이미 존재함")
            return
        }
        
        if let index = departments.firstIndex(where: { $0.id == departmentId }) {
            departments[index].employees.append(employee)
            updatedAt = Date()
            print("✅ [Company] 직원 추가됨: \(employee.name)")
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
    var departmentSkills: DepartmentSkills
    /// AI 도구 사용 자동 승인 (--dangerously-skip-permissions)
    var autoApproveAI: Bool

    enum CodingKeys: String, CodingKey {
        case apiConfigurations, autoSaveEnabled, cloudSyncEnabled, notificationsEnabled, wikiSettings, departmentSkills, autoApproveAI
    }

    init(
        apiConfigurations: [APIConfiguration] = [],
        autoSaveEnabled: Bool = true,
        cloudSyncEnabled: Bool = false,
        notificationsEnabled: Bool = true,
        wikiSettings: WikiSettings? = WikiSettings(),
        departmentSkills: DepartmentSkills = DepartmentSkills(),
        autoApproveAI: Bool = false
    ) {
        self.apiConfigurations = apiConfigurations
        self.autoSaveEnabled = autoSaveEnabled
        self.cloudSyncEnabled = cloudSyncEnabled
        self.notificationsEnabled = notificationsEnabled
        self.wikiSettings = wikiSettings
        self.departmentSkills = departmentSkills
        self.autoApproveAI = autoApproveAI
    }

    // 기존 저장 파일 호환성
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        apiConfigurations = try container.decodeIfPresent([APIConfiguration].self, forKey: .apiConfigurations) ?? []
        autoSaveEnabled = try container.decodeIfPresent(Bool.self, forKey: .autoSaveEnabled) ?? true
        cloudSyncEnabled = try container.decodeIfPresent(Bool.self, forKey: .cloudSyncEnabled) ?? false
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled) ?? true
        wikiSettings = try container.decodeIfPresent(WikiSettings.self, forKey: .wikiSettings)
        departmentSkills = try container.decodeIfPresent(DepartmentSkills.self, forKey: .departmentSkills) ?? DepartmentSkills()
        autoApproveAI = try container.decodeIfPresent(Bool.self, forKey: .autoApproveAI) ?? false
    }
}
