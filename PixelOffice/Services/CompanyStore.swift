import Foundation
import SwiftUI
import Combine

/// 🏢 CompanyStore — Facade / Coordinator
///
/// 기존 View들과의 하위 호환성을 유지하면서 내부적으로 도메인 Store에 위임
/// 모든 기존 메서드 시그니처를 그대로 유지하되, 실제 비즈니스 로직은 각 도메인 Store에 위치
///
/// - EmployeeStore: 직원 CRUD, 상태 관리, 온보딩
/// - ProjectStore: 프로젝트 CRUD, 태스크, 프로젝트 직원, 워크플로우
/// - CommunityStore: 커뮤니티 게시글, 사고 과정
/// - WikiStore: 위키 문서 관리
/// - SettingsStore: API 설정, 부서 스킬
/// - CollaborationStore: 협업 기록
/// - PermissionStore: 권한 요청, 자동 승인 규칙
@MainActor
class CompanyStore: ObservableObject, StoreCoordinator {
    @Published var company: Company
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// 중앙 집중식 직원 상태 관리 (직원 ID → 상태)
    @Published var employeeStatuses: [UUID: EmployeeStatus] = [:]

    private let dataManager = DataManager()
    private var autoSaveTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - 도메인 Stores

    private(set) var employeeStore: EmployeeStore!
    private(set) var projectStore: ProjectStore!
    private(set) var communityStore: CommunityStore!
    private(set) var wikiStore: WikiStore!
    private(set) var settingsStore: SettingsStore!
    private(set) var collaborationStore: CollaborationStore!
    private(set) var permissionStore: PermissionStore!
    private(set) var pipelineCoordinator: PipelineCoordinator!

    // MARK: - Init

    init() {
        print("🏢 CompanyStore init started")
        let loadedCompany = dataManager.loadCompany()
        if let loaded = loadedCompany {
            self.company = loaded
            print("✅ Loaded existing company with \(loaded.allEmployees.count) employees")
        } else {
            self.company = Company()
            print("⚠️ No saved company found, created new empty company")
        }

        // 도메인 Store 초기화
        setupDomainStores()

        setupAutoSave()
        employeeStore.loadEmployeeStatuses()
        print("👥 Employee statuses loaded: \(employeeStatuses.count) entries")

        // _projects 폴더에서 자동 복구
        ProjectRecoveryService.shared.recoverProjectsIfNeeded(company: &company)

        projectStore.ensureProjectDirectoriesExist()
        employeeStore.ensureEmployeeProfilesExist()
        wikiStore.syncWikiDocumentsToFiles()

        print("✅ CompanyStore init completed")
        print("👥 Final employee count: \(company.allEmployees.count)")
    }

    // MARK: - Coordinator 구현

    /// 도메인 Store 초기화
    private func setupDomainStores() {
        employeeStore = EmployeeStore(coordinator: self)
        projectStore = ProjectStore(coordinator: self)
        communityStore = CommunityStore(coordinator: self)
        wikiStore = WikiStore(coordinator: self)
        settingsStore = SettingsStore(coordinator: self)
        collaborationStore = CollaborationStore(coordinator: self)
        permissionStore = PermissionStore(coordinator: self)
        pipelineCoordinator = PipelineCoordinator(companyStore: self)
    }

    private func setupAutoSave() {
        $company
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [weak self] company in
                self?.saveCompany()
            }
            .store(in: &cancellables)
    }

    func saveCompany() {
        print("💾 Saving company... (\(company.allEmployees.count) employees)")
        dataManager.saveCompany(company)
    }

    func triggerObjectUpdate() {
        objectWillChange.send()
    }

    // MARK: - Department Operations (CompanyStore 직접 관리)

    func addDepartment(_ department: Department) {
        company.departments.append(department)
    }

    func removeDepartment(_ departmentId: UUID) {
        company.departments.removeAll { $0.id == departmentId }
    }

    func getDepartment(byId id: UUID) -> Department? {
        company.departments.first { $0.id == id }
    }

    func getDepartment(byType type: DepartmentType) -> Department? {
        company.departments.first { $0.type == type }
    }

    // MARK: - Employee Operations (→ EmployeeStore 위임)

    func addEmployee(_ employee: Employee, toDepartment departmentId: UUID) {
        employeeStore.addEmployee(employee, toDepartment: departmentId)
    }

    func removeEmployee(_ employeeId: UUID) {
        employeeStore.removeEmployee(employeeId)
    }

    func findEmployee(byId employeeId: UUID) -> Employee? {
        employeeStore.findEmployee(byId: employeeId)
    }

    func updateEmployeeStatus(_ employeeId: UUID, status: EmployeeStatus) {
        employeeStore.updateEmployeeStatus(employeeId, status: status)
    }

    func getEmployeeStatus(_ employeeId: UUID) -> EmployeeStatus {
        employeeStore.getEmployeeStatus(employeeId)
    }

    func getEmployeeStatistics(_ employeeId: UUID) -> EmployeeStatistics? {
        // 먼저 회사 직원에서 찾기
        if let employee = getEmployee(byId: employeeId) {
            return employee.statistics
        }
        // 프로젝트 직원에서 찾기
        for project in company.projects {
            for dept in project.departments {
                if let employee = dept.employees.first(where: { $0.id == employeeId }) {
                    return employee.statistics
                }
            }
        }
        return nil
    }

    func updateEmployeeTokenUsage(
        _ employeeId: UUID,
        inputTokens: Int,
        outputTokens: Int,
        cacheRead: Int = 0,
        cacheCreation: Int = 0,
        costUSD: Double = 0,
        model: String = "unknown"
    ) {
        employeeStore.updateEmployeeTokenUsage(
            employeeId,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheRead: cacheRead,
            cacheCreation: cacheCreation,
            costUSD: costUSD,
            model: model
        )
    }

    func getEmployee(byId id: UUID) -> Employee? {
        employeeStore.getEmployee(byId: id)
    }

    // MARK: - Onboarding Operations (→ EmployeeStore 위임)

    func addOnboarding(_ onboarding: EmployeeOnboarding) {
        employeeStore.addOnboarding(onboarding)
    }

    func updateOnboarding(_ onboarding: EmployeeOnboarding) {
        employeeStore.updateOnboarding(onboarding)
    }

    func getOnboarding(for employeeId: UUID) -> EmployeeOnboarding? {
        employeeStore.getOnboarding(for: employeeId)
    }

    func completeOnboarding(employeeId: UUID, questions: [OnboardingQuestion]) {
        employeeStore.completeOnboarding(employeeId: employeeId, questions: questions)
    }

    // MARK: - Project Operations (→ ProjectStore 위임)

    func addProject(_ project: Project) {
        projectStore.addProject(project)
    }

    func removeProject(_ projectId: UUID) {
        projectStore.removeProject(projectId)
    }

    func getProject(byId id: UUID) -> Project? {
        projectStore.getProject(byId: id)
    }

    func updateProject(_ project: Project) {
        projectStore.updateProject(project)
    }

    // MARK: - Task Operations (→ ProjectStore 위임)

    func addTask(_ task: ProjectTask, toProject projectId: UUID) {
        projectStore.addTask(task, toProject: projectId)
    }

    func removeTask(_ taskId: UUID, fromProject projectId: UUID) {
        projectStore.removeTask(taskId, fromProject: projectId)
    }

    func updateTask(_ task: ProjectTask, inProject projectId: UUID) {
        projectStore.updateTask(task, inProject: projectId)
    }

    func addMessageToTask(message: Message, taskId: UUID, projectId: UUID) {
        projectStore.addMessageToTask(message: message, taskId: taskId, projectId: projectId)
    }

    func addOutputToTask(output: TaskOutput, taskId: UUID, projectId: UUID) {
        projectStore.addOutputToTask(output: output, taskId: taskId, projectId: projectId)
    }

    func assignTaskToEmployee(taskId: UUID, employeeId: UUID, projectId: UUID) {
        projectStore.assignTaskToEmployee(taskId: taskId, employeeId: employeeId, projectId: projectId)
    }

    /// 파이프라인 태스크들을 칸반에 추가
    func addTasksFromPipeline(_ run: PipelineRun, toProject projectId: UUID, sprintId: UUID? = nil) -> Int {
        var addedCount = 0
        for decomposedTask in run.decomposedTasks {
            let projectTask = decomposedTask.toProjectTask(pipelineRunId: run.id, sprintId: sprintId)
            addTask(projectTask, toProject: projectId)
            addedCount += 1
        }
        return addedCount
    }

    func startTask(taskId: UUID, projectId: UUID) {
        projectStore.startTask(taskId: taskId, projectId: projectId)
    }

    func completeTask(taskId: UUID, projectId: UUID) {
        projectStore.completeTask(taskId: taskId, projectId: projectId)
    }

    // MARK: - Workflow Operations (→ ProjectStore 위임)

    func moveTaskToDepartment(taskId: UUID, projectId: UUID, toDepartment: DepartmentType, note: String = "") {
        projectStore.moveTaskToDepartment(taskId: taskId, projectId: projectId, toDepartment: toDepartment, note: note)
    }

    func getPendingTasks(for departmentType: DepartmentType) -> [(task: ProjectTask, projectId: UUID)] {
        projectStore.getPendingTasks(for: departmentType)
    }

    var departmentsByWorkflowOrder: [Department] {
        projectStore.departmentsByWorkflowOrder
    }

    // MARK: - Project Employee Operations (→ ProjectStore 위임)

    func addProjectEmployee(_ employee: ProjectEmployee, toProject projectId: UUID, department: DepartmentType) {
        projectStore.addProjectEmployee(employee, toProject: projectId, department: department)
    }

    func removeProjectEmployee(_ employeeId: UUID, fromProject projectId: UUID) {
        projectStore.removeProjectEmployee(employeeId, fromProject: projectId)
    }

    func getProjectEmployee(byId employeeId: UUID, inProject projectId: UUID) -> ProjectEmployee? {
        projectStore.getProjectEmployee(byId: employeeId, inProject: projectId)
    }

    func updateProjectEmployeeStatus(_ employeeId: UUID, inProject projectId: UUID, status: EmployeeStatus) {
        projectStore.updateProjectEmployeeStatus(employeeId, inProject: projectId, status: status)
    }

    func updateProjectEmployeeConversation(projectId: UUID, employeeId: UUID, messages: [Message]) {
        projectStore.updateProjectEmployeeConversation(projectId: projectId, employeeId: employeeId, messages: messages)
    }

    func getProjectEmployeeCount(_ projectId: UUID) -> Int {
        projectStore.getProjectEmployeeCount(projectId)
    }

    func getProjectWorkingEmployeesCount(_ projectId: UUID) -> Int {
        projectStore.getProjectWorkingEmployeesCount(projectId)
    }

    // MARK: - Settings Operations (→ SettingsStore 위임)

    func updateSettings(_ settings: CompanySettings) {
        settingsStore.updateSettings(settings)
    }

    func addAPIConfiguration(_ config: APIConfiguration) {
        settingsStore.addAPIConfiguration(config)
    }

    func removeAPIConfiguration(_ configId: UUID) {
        settingsStore.removeAPIConfiguration(configId)
    }

    func updateAPIConfiguration(_ config: APIConfiguration) {
        settingsStore.updateAPIConfiguration(config)
    }

    func getAPIConfiguration(for aiType: AIType) -> APIConfiguration? {
        settingsStore.getAPIConfiguration(for: aiType)
    }

    // MARK: - Department Skills Operations (→ SettingsStore 위임)

    func getDepartmentSkills(for department: DepartmentType) -> DepartmentSkillSet {
        settingsStore.getDepartmentSkills(for: department)
    }

    func updateDepartmentSkills(for department: DepartmentType, skills: DepartmentSkillSet) {
        settingsStore.updateDepartmentSkills(for: department, skills: skills)
    }

    func resetDepartmentSkills(for department: DepartmentType) {
        settingsStore.resetDepartmentSkills(for: department)
    }

    func getSystemPrompt(for department: DepartmentType) -> String {
        settingsStore.getSystemPrompt(for: department)
    }

    // MARK: - Wiki Operations (→ WikiStore 위임)

    func addWikiDocument(_ document: WikiDocument) {
        wikiStore.addWikiDocument(document)
    }

    func removeWikiDocument(_ documentId: UUID) {
        wikiStore.removeWikiDocument(documentId)
    }

    func clearAllWikiDocuments() {
        wikiStore.clearAllWikiDocuments()
    }

    func updateWikiDocument(_ document: WikiDocument) {
        wikiStore.updateWikiDocument(document)
    }

    func updateWikiPath(_ path: String) {
        wikiStore.updateWikiPath(path)
    }

    func syncWikiDocumentsToFiles() {
        wikiStore.syncWikiDocumentsToFiles()
    }

    // MARK: - Collaboration Records (→ CollaborationStore 위임)

    func addCollaborationRecord(_ record: CollaborationRecord) {
        collaborationStore.addCollaborationRecord(record)
    }

    var collaborationRecords: [CollaborationRecord] {
        collaborationStore.collaborationRecords
    }

    func getCollaborationRecords(forDepartment department: String) -> [CollaborationRecord] {
        collaborationStore.getCollaborationRecords(forDepartment: department)
    }

    func getCollaborationRecords(forProject projectId: UUID) -> [CollaborationRecord] {
        collaborationStore.getCollaborationRecords(forProject: projectId)
    }

    func removeCollaborationRecord(_ recordId: UUID) {
        collaborationStore.removeCollaborationRecord(recordId)
    }

    func clearAllCollaborationRecords() {
        collaborationStore.clearAllCollaborationRecords()
    }

    // MARK: - Employee Thinking (→ CommunityStore 위임)

    func startThinking(employeeId: UUID, employeeName: String, departmentType: DepartmentType, topic: String) -> EmployeeThinking {
        communityStore.startThinking(employeeId: employeeId, employeeName: employeeName, departmentType: departmentType, topic: topic)
    }

    func addThinkingInput(thinkingId: UUID, content: String, source: String) {
        communityStore.addThinkingInput(thinkingId: thinkingId, content: content, source: source)
    }

    func updateThinkingReasoning(thinkingId: UUID, reasoning: ThinkingReasoning) {
        communityStore.updateThinkingReasoning(thinkingId: thinkingId, reasoning: reasoning)
    }

    func setThinkingConclusion(thinkingId: UUID, conclusion: ThinkingConclusion) {
        communityStore.setThinkingConclusion(thinkingId: thinkingId, conclusion: conclusion)
    }

    func getActiveThinking(employeeId: UUID) -> EmployeeThinking? {
        communityStore.getActiveThinking(employeeId: employeeId)
    }

    var employeeThinkings: [EmployeeThinking] {
        communityStore.employeeThinkings
    }

    // MARK: - Community Posts (→ CommunityStore 위임)

    func addCommunityPost(_ post: CommunityPost, autoComment: Bool = true) {
        communityStore.addCommunityPost(post, autoComment: autoComment)
    }

    func createPostFromThinking(_ thinking: EmployeeThinking) -> CommunityPost? {
        communityStore.createPostFromThinking(thinking)
    }

    var communityPosts: [CommunityPost] {
        communityStore.communityPosts
    }

    func getCommunityPosts(employeeId: UUID) -> [CommunityPost] {
        communityStore.getCommunityPosts(employeeId: employeeId)
    }

    func likeCommunityPost(_ postId: UUID) {
        communityStore.likeCommunityPost(postId)
    }

    func addCommentToPost(_ postId: UUID, comment: PostComment) {
        communityStore.addCommentToPost(postId, comment: comment)
    }

    func removeCommunityPost(_ postId: UUID) {
        communityStore.removeCommunityPost(postId)
    }

    // MARK: - Permission Requests (→ PermissionStore 위임)

    func addPermissionRequest(_ request: PermissionRequest) {
        permissionStore.addPermissionRequest(request)
    }

    func approvePermissionRequest(_ requestId: UUID, reason: String? = nil) {
        permissionStore.approvePermissionRequest(requestId, reason: reason)
    }

    func denyPermissionRequest(_ requestId: UUID, reason: String? = nil) {
        permissionStore.denyPermissionRequest(requestId, reason: reason)
    }

    var pendingPermissionRequests: [PermissionRequest] {
        permissionStore.pendingPermissionRequests
    }

    func getPermissionRequests(employeeId: UUID) -> [PermissionRequest] {
        permissionStore.getPermissionRequests(employeeId: employeeId)
    }

    func removePermissionRequest(_ requestId: UUID) {
        permissionStore.removePermissionRequest(requestId)
    }

    // MARK: - Auto Approval Rules (→ PermissionStore 위임)

    func addAutoApprovalRule(_ rule: AutoApprovalRule) {
        permissionStore.addAutoApprovalRule(rule)
    }

    func updateAutoApprovalRule(_ ruleId: UUID, update: (inout AutoApprovalRule) -> Void) {
        permissionStore.updateAutoApprovalRule(ruleId, update: update)
    }

    func removeAutoApprovalRule(_ ruleId: UUID) {
        permissionStore.removeAutoApprovalRule(ruleId)
    }

    var autoApprovalRules: [AutoApprovalRule] {
        permissionStore.autoApprovalRules
    }

    // MARK: - Statistics (CompanyStore 직접 관리)

    var totalEmployees: Int {
        company.allEmployees.count
    }

    var workingEmployeesCount: Int {
        company.workingEmployees.count
    }

    var totalProjects: Int {
        company.projects.count
    }

    var activeProjects: Int {
        company.projects.filter { $0.status == .inProgress }.count
    }

    var completedTasks: Int {
        company.projects.flatMap { $0.tasks }.filter { $0.status == .done }.count
    }

    var pendingTasks: Int {
        company.projects.flatMap { $0.tasks }.filter { $0.status == .todo }.count
    }

    // MARK: - Sprint Management

    func addSprint(_ sprint: Sprint, toProject projectId: UUID) {
        guard let projectIndex = company.projects.firstIndex(where: { $0.id == projectId }) else { return }
        company.projects[projectIndex].sprints.append(sprint)
        saveCompany()
    }

    func updateSprint(_ sprint: Sprint, inProject projectId: UUID) {
        guard let projectIndex = company.projects.firstIndex(where: { $0.id == projectId }),
              let sprintIndex = company.projects[projectIndex].sprints.firstIndex(where: { $0.id == sprint.id }) else { return }
        company.projects[projectIndex].sprints[sprintIndex] = sprint
        saveCompany()
    }

    func removeSprint(_ sprintId: UUID, fromProject projectId: UUID) {
        guard let projectIndex = company.projects.firstIndex(where: { $0.id == projectId }) else { return }
        company.projects[projectIndex].sprints.removeAll { $0.id == sprintId }
        // 해당 스프린트에 배정된 태스크들의 sprintId를 nil로
        for taskIndex in company.projects[projectIndex].tasks.indices {
            if company.projects[projectIndex].tasks[taskIndex].sprintId == sprintId {
                company.projects[projectIndex].tasks[taskIndex].sprintId = nil
            }
        }
        saveCompany()
    }

    func activateSprint(_ sprintId: UUID, inProject projectId: UUID) {
        guard let projectIndex = company.projects.firstIndex(where: { $0.id == projectId }) else { return }
        // 모든 스프린트 비활성화 후 해당 스프린트만 활성화
        for i in company.projects[projectIndex].sprints.indices {
            company.projects[projectIndex].sprints[i].isActive = (company.projects[projectIndex].sprints[i].id == sprintId)
        }
        saveCompany()
    }

    func assignTaskToSprint(taskId: UUID, sprintId: UUID?, projectId: UUID) {
        guard let projectIndex = company.projects.firstIndex(where: { $0.id == projectId }),
              let taskIndex = company.projects[projectIndex].tasks.firstIndex(where: { $0.id == taskId }) else { return }
        company.projects[projectIndex].tasks[taskIndex].sprintId = sprintId
        saveCompany()
    }

    func getSprints(forProject projectId: UUID) -> [Sprint] {
        company.projects.first { $0.id == projectId }?.sprints ?? []
    }

    func getActiveSprint(forProject projectId: UUID) -> Sprint? {
        company.projects.first { $0.id == projectId }?.activeSprint
    }
}
