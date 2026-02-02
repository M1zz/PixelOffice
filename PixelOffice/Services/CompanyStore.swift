import Foundation
import SwiftUI
import Combine

@MainActor
class CompanyStore: ObservableObject {
    @Published var company: Company
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let dataManager = DataManager()
    private var autoSaveTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        self.company = dataManager.loadCompany() ?? Company()
        setupAutoSave()
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
        dataManager.saveCompany(company)
    }
    
    // MARK: - Department Operations
    
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
    
    // MARK: - Employee Operations
    
    func addEmployee(_ employee: Employee, toDepartment departmentId: UUID) {
        company.addEmployee(employee, toDepartment: departmentId)
        saveCompany()  // 즉시 저장
    }

    func removeEmployee(_ employeeId: UUID) {
        company.removeEmployee(employeeId)
        saveCompany()  // 즉시 저장
    }

    func findEmployee(byId employeeId: UUID) -> Employee? {
        for dept in company.departments {
            if let employee = dept.employees.first(where: { $0.id == employeeId }) {
                return employee
            }
        }
        return nil
    }
    
    func updateEmployeeStatus(_ employeeId: UUID, status: EmployeeStatus) {
        company.updateEmployeeStatus(employeeId, status: status)
    }
    
    func getEmployee(byId id: UUID) -> Employee? {
        company.getEmployee(byId: id)
    }
    
    func assignTaskToEmployee(taskId: UUID, employeeId: UUID, projectId: UUID) {
        guard var project = company.projects.first(where: { $0.id == projectId }),
              var task = project.tasks.first(where: { $0.id == taskId }) else { return }
        
        task.assign(to: employeeId)
        project.updateTask(task)
        
        if let index = company.projects.firstIndex(where: { $0.id == projectId }) {
            company.projects[index] = project
        }
    }
    
    func startTask(taskId: UUID, projectId: UUID) {
        guard var project = company.projects.first(where: { $0.id == projectId }),
              var task = project.tasks.first(where: { $0.id == taskId }) else { return }
        
        task.start()
        project.updateTask(task)
        
        if let index = company.projects.firstIndex(where: { $0.id == projectId }) {
            company.projects[index] = project
        }
        
        // Update employee status
        if let employeeId = task.assigneeId {
            updateEmployeeStatus(employeeId, status: .working)
            
            // Update employee's current task
            for i in company.departments.indices {
                if let j = company.departments[i].employees.firstIndex(where: { $0.id == employeeId }) {
                    company.departments[i].employees[j].currentTaskId = taskId
                }
            }
        }
    }
    
    func completeTask(taskId: UUID, projectId: UUID) {
        guard var project = company.projects.first(where: { $0.id == projectId }),
              var task = project.tasks.first(where: { $0.id == taskId }) else { return }
        
        let employeeId = task.assigneeId
        
        task.complete()
        project.updateTask(task)
        
        if let index = company.projects.firstIndex(where: { $0.id == projectId }) {
            company.projects[index] = project
        }
        
        // Update employee status
        if let employeeId = employeeId {
            updateEmployeeStatus(employeeId, status: .idle)
            
            // Clear employee's current task and increment completed count
            for i in company.departments.indices {
                if let j = company.departments[i].employees.firstIndex(where: { $0.id == employeeId }) {
                    company.departments[i].employees[j].currentTaskId = nil
                    company.departments[i].employees[j].totalTasksCompleted += 1
                }
            }
        }
    }
    
    // MARK: - Project Operations
    
    func addProject(_ project: Project) {
        company.addProject(project)
    }
    
    func removeProject(_ projectId: UUID) {
        company.removeProject(projectId)
    }
    
    func getProject(byId id: UUID) -> Project? {
        company.projects.first { $0.id == id }
    }
    
    func updateProject(_ project: Project) {
        if let index = company.projects.firstIndex(where: { $0.id == project.id }) {
            company.projects[index] = project
        }
    }
    
    // MARK: - Task Operations
    
    func addTask(_ task: ProjectTask, toProject projectId: UUID) {
        if let index = company.projects.firstIndex(where: { $0.id == projectId }) {
            company.projects[index].addTask(task)
        }
    }
    
    func removeTask(_ taskId: UUID, fromProject projectId: UUID) {
        if let index = company.projects.firstIndex(where: { $0.id == projectId }) {
            company.projects[index].removeTask(taskId)
        }
    }
    
    func updateTask(_ task: ProjectTask, inProject projectId: UUID) {
        if let index = company.projects.firstIndex(where: { $0.id == projectId }) {
            company.projects[index].updateTask(task)
        }
    }
    
    func addMessageToTask(message: Message, taskId: UUID, projectId: UUID) {
        if let projectIndex = company.projects.firstIndex(where: { $0.id == projectId }),
           let taskIndex = company.projects[projectIndex].tasks.firstIndex(where: { $0.id == taskId }) {
            company.projects[projectIndex].tasks[taskIndex].addMessage(message)
        }
    }
    
    func addOutputToTask(output: TaskOutput, taskId: UUID, projectId: UUID) {
        if let projectIndex = company.projects.firstIndex(where: { $0.id == projectId }),
           let taskIndex = company.projects[projectIndex].tasks.firstIndex(where: { $0.id == taskId }) {
            company.projects[projectIndex].tasks[taskIndex].addOutput(output)
        }
    }

    // MARK: - Workflow Operations

    /// 태스크를 다음 부서로 이동
    func moveTaskToDepartment(taskId: UUID, projectId: UUID, toDepartment: DepartmentType, note: String = "") {
        if let projectIndex = company.projects.firstIndex(where: { $0.id == projectId }),
           let taskIndex = company.projects[projectIndex].tasks.firstIndex(where: { $0.id == taskId }) {
            company.projects[projectIndex].tasks[taskIndex].moveToDepartment(toDepartment, note: note)
        }
    }

    /// 특정 부서의 대기 중인 태스크들 조회
    func getPendingTasks(for departmentType: DepartmentType) -> [(task: ProjectTask, projectId: UUID)] {
        var result: [(task: ProjectTask, projectId: UUID)] = []
        for project in company.projects {
            let tasks = project.tasks.filter { $0.departmentType == departmentType && $0.status == .todo }
            result.append(contentsOf: tasks.map { (task: $0, projectId: project.id) })
        }
        return result
    }

    /// 워크플로우 순서대로 정렬된 부서들
    var departmentsByWorkflowOrder: [Department] {
        company.departments.sorted { $0.type.workflowOrder < $1.type.workflowOrder }
    }

    // MARK: - Settings Operations
    
    func updateSettings(_ settings: CompanySettings) {
        company.settings = settings
    }
    
    func addAPIConfiguration(_ config: APIConfiguration) {
        company.settings.apiConfigurations.append(config)
    }
    
    func removeAPIConfiguration(_ configId: UUID) {
        company.settings.apiConfigurations.removeAll { $0.id == configId }
    }
    
    func updateAPIConfiguration(_ config: APIConfiguration) {
        if let index = company.settings.apiConfigurations.firstIndex(where: { $0.id == config.id }) {
            company.settings.apiConfigurations[index] = config
        }
    }
    
    func getAPIConfiguration(for aiType: AIType) -> APIConfiguration? {
        company.settings.apiConfigurations.first { $0.type == aiType && $0.isEnabled }
    }

    // MARK: - Wiki Operations

    func addWikiDocument(_ document: WikiDocument) {
        company.wikiDocuments.append(document)
    }

    func removeWikiDocument(_ documentId: UUID) {
        company.wikiDocuments.removeAll { $0.id == documentId }
    }

    func clearAllWikiDocuments() {
        company.wikiDocuments.removeAll()
        saveCompany()
    }

    func updateWikiDocument(_ document: WikiDocument) {
        if let index = company.wikiDocuments.firstIndex(where: { $0.id == document.id }) {
            company.wikiDocuments[index] = document
        }
    }

    func updateWikiPath(_ path: String) {
        if company.settings.wikiSettings == nil {
            company.settings.wikiSettings = WikiSettings()
        }
        company.settings.wikiSettings?.wikiPath = path
    }

    // MARK: - Onboarding Operations

    func addOnboarding(_ onboarding: EmployeeOnboarding) {
        company.employeeOnboardings.append(onboarding)
    }

    func updateOnboarding(_ onboarding: EmployeeOnboarding) {
        if let index = company.employeeOnboardings.firstIndex(where: { $0.id == onboarding.id }) {
            company.employeeOnboardings[index] = onboarding
        }
    }

    func getOnboarding(for employeeId: UUID) -> EmployeeOnboarding? {
        company.employeeOnboardings.first { $0.employeeId == employeeId }
    }

    func completeOnboarding(employeeId: UUID, questions: [OnboardingQuestion]) {
        if let index = company.employeeOnboardings.firstIndex(where: { $0.employeeId == employeeId }) {
            company.employeeOnboardings[index].questions = questions
            company.employeeOnboardings[index].isCompleted = true
            company.employeeOnboardings[index].completedAt = Date()
        }
    }

    // MARK: - Project Employee Operations

    /// 프로젝트에 직원 추가
    func addProjectEmployee(_ employee: ProjectEmployee, toProject projectId: UUID, department: DepartmentType) {
        if let index = company.projects.firstIndex(where: { $0.id == projectId }) {
            company.projects[index].addEmployee(employee, toDepartment: department)
            saveCompany()
        }
    }

    /// 프로젝트에서 직원 제거
    func removeProjectEmployee(_ employeeId: UUID, fromProject projectId: UUID) {
        if let index = company.projects.firstIndex(where: { $0.id == projectId }) {
            company.projects[index].removeEmployee(employeeId)
            saveCompany()
        }
    }

    /// 프로젝트 내 직원 찾기
    func getProjectEmployee(byId employeeId: UUID, inProject projectId: UUID) -> ProjectEmployee? {
        guard let project = company.projects.first(where: { $0.id == projectId }) else { return nil }
        return project.getEmployee(byId: employeeId)
    }

    /// 프로젝트 직원 상태 업데이트
    func updateProjectEmployeeStatus(_ employeeId: UUID, inProject projectId: UUID, status: EmployeeStatus) {
        guard let projectIndex = company.projects.firstIndex(where: { $0.id == projectId }) else { return }
        for deptIndex in company.projects[projectIndex].departments.indices {
            if let empIndex = company.projects[projectIndex].departments[deptIndex].employees.firstIndex(where: { $0.id == employeeId }) {
                company.projects[projectIndex].departments[deptIndex].employees[empIndex].status = status
                break
            }
        }
    }

    /// 프로젝트 직원 대화 기록 업데이트
    func updateProjectEmployeeConversation(projectId: UUID, employeeId: UUID, messages: [Message]) {
        guard let projectIndex = company.projects.firstIndex(where: { $0.id == projectId }) else { return }
        for deptIndex in company.projects[projectIndex].departments.indices {
            if let empIndex = company.projects[projectIndex].departments[deptIndex].employees.firstIndex(where: { $0.id == employeeId }) {
                company.projects[projectIndex].departments[deptIndex].employees[empIndex].conversationHistory = messages
                saveCompany()
                break
            }
        }
    }

    /// 프로젝트 직원 수
    func getProjectEmployeeCount(_ projectId: UUID) -> Int {
        guard let project = company.projects.first(where: { $0.id == projectId }) else { return 0 }
        return project.allEmployees.count
    }

    /// 프로젝트 내 작업 중인 직원 수
    func getProjectWorkingEmployeesCount(_ projectId: UUID) -> Int {
        guard let project = company.projects.first(where: { $0.id == projectId }) else { return 0 }
        return project.workingEmployees.count
    }

    // MARK: - Statistics

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
}
