import Foundation
import SwiftUI
import Combine

@MainActor
class CompanyStore: ObservableObject {
    @Published var company: Company
    @Published var isLoading = false
    @Published var errorMessage: String?

    /// 중앙 집중식 직원 상태 관리 (직원 ID → 상태)
    @Published var employeeStatuses: [UUID: EmployeeStatus] = [:]

    private let dataManager = DataManager()
    private var autoSaveTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
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

        setupAutoSave()
        loadEmployeeStatuses()
        print("👥 Employee statuses loaded: \(employeeStatuses.count) entries")

        // _projects 폴더에서 자동 복구
        ProjectRecoveryService.shared.recoverProjectsIfNeeded(company: &company)

        ensureProjectDirectoriesExist()
        ensureEmployeeProfilesExist()
        syncWikiDocumentsToFiles()

        print("✅ CompanyStore init completed")
        print("👥 Final employee count: \(company.allEmployees.count)")
    }

    /// 기존 프로젝트들의 디렉토리 구조 생성 (README 포함)
    private func ensureProjectDirectoriesExist() {
        for project in company.projects {
            DataPathService.shared.createProjectDirectories(projectName: project.name)
        }
    }

    /// 기존 직원들의 프로필 파일 생성 및 대화 기록 동기화
    private func ensureEmployeeProfilesExist() {
        let fileManager = FileManager.default

        // 일반 직원
        for dept in company.departments {
            for emp in dept.employees {
                let filePath = EmployeeWorkLogService.shared.getWorkLogFilePath(for: emp.id, employeeName: emp.name)
                if !fileManager.fileExists(atPath: filePath) {
                    EmployeeWorkLogService.shared.createEmployeeProfile(employee: emp, departmentType: dept.type)
                }
                // 대화 기록이 있으면 동기화
                if !emp.conversationHistory.isEmpty {
                    EmployeeWorkLogService.shared.syncEmployeeConversations(employee: emp, departmentType: dept.type)
                }
            }
        }

        // 프로젝트 직원
        for project in company.projects {
            for dept in project.departments {
                for emp in dept.employees {
                    let filePath = EmployeeWorkLogService.shared.getProjectWorkLogFilePath(
                        projectName: project.name,
                        department: dept.type,
                        employeeName: emp.name
                    )
                    if !fileManager.fileExists(atPath: filePath) {
                        EmployeeWorkLogService.shared.createProjectEmployeeProfile(employee: emp, projectName: project.name)
                    }
                    // 대화 기록이 있으면 동기화
                    if !emp.conversationHistory.isEmpty {
                        EmployeeWorkLogService.shared.syncProjectEmployeeConversations(employee: emp, projectName: project.name)
                    }
                }
            }
        }
    }

    /// 기존 직원들의 상태를 중앙 저장소에 로드
    private func loadEmployeeStatuses() {
        // 일반 직원
        for dept in company.departments {
            for emp in dept.employees {
                employeeStatuses[emp.id] = emp.status
            }
        }
        // 프로젝트 직원
        for project in company.projects {
            for dept in project.departments {
                for emp in dept.employees {
                    employeeStatuses[emp.id] = emp.status
                }
            }
        }
    }

    /// 직원 상태 조회 (중앙 저장소 우선)
    func getEmployeeStatus(_ employeeId: UUID) -> EmployeeStatus {
        return employeeStatuses[employeeId] ?? .idle
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
        employeeStatuses[employee.id] = employee.status  // 중앙 저장소에 등록
        saveCompany()  // 즉시 저장

        // 직원 프로필 파일 생성
        if let dept = getDepartment(byId: departmentId) {
            EmployeeWorkLogService.shared.createEmployeeProfile(employee: employee, departmentType: dept.type)
        }
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
        let previousStatus = employeeStatuses[employeeId]

        // 상태가 변경된 경우에만 처리
        guard previousStatus != status else { return }

        // 중앙 저장소 업데이트
        employeeStatuses[employeeId] = status

        // 데이터 모델도 동기화
        company.updateEmployeeStatus(employeeId, status: status)

        // company를 다시 할당하여 @Published 트리거 (UI 전체 업데이트)
        let updatedCompany = company
        company = updatedCompany

        // 직원 이름 찾기
        let employeeName = findEmployeeName(byId: employeeId)

        // 토스트 알림
        let toastType: ToastType = status == .thinking ? .info : (status == .idle ? .success : .info)
        ToastManager.shared.show(
            title: "\(employeeName) 상태 변경",
            message: "\(previousStatus?.rawValue ?? "알 수 없음") → \(status.rawValue)",
            type: toastType
        )

        // 시스템 알림 (앱이 백그라운드일 때 유용)
        ToastManager.shared.sendNotification(
            title: "\(employeeName) 상태 변경",
            body: "\(status.rawValue)"
        )
    }

    /// 직원 이름 찾기 (일반 직원 + 프로젝트 직원)
    private func findEmployeeName(byId employeeId: UUID) -> String {
        // 일반 직원에서 찾기
        for dept in company.departments {
            if let emp = dept.employees.first(where: { $0.id == employeeId }) {
                return emp.name
            }
        }
        // 프로젝트 직원에서 찾기
        for project in company.projects {
            for dept in project.departments {
                if let emp = dept.employees.first(where: { $0.id == employeeId }) {
                    return emp.name
                }
            }
        }
        return "직원"
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
        // 프로젝트 디렉토리 구조 생성
        DataPathService.shared.createProjectDirectories(projectName: project.name)
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

    // MARK: - Department Skills Operations

    /// 부서 스킬 조회
    func getDepartmentSkills(for department: DepartmentType) -> DepartmentSkillSet {
        return company.settings.departmentSkills.getSkills(for: department)
    }

    /// 부서 스킬 업데이트
    func updateDepartmentSkills(for department: DepartmentType, skills: DepartmentSkillSet) {
        company.settings.departmentSkills.updateSkills(for: department, skills: skills)
        saveCompany()
    }

    /// 부서 스킬 초기화
    func resetDepartmentSkills(for department: DepartmentType) {
        let defaultSkills = DepartmentSkillSet.defaultSkills(for: department)
        company.settings.departmentSkills.updateSkills(for: department, skills: defaultSkills)
        saveCompany()
    }

    /// 부서 스킬로부터 시스템 프롬프트 생성
    func getSystemPrompt(for department: DepartmentType) -> String {
        return getDepartmentSkills(for: department).fullPrompt
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

    /// 위키 문서를 부서별 documents 폴더에 동기화
    func syncWikiDocumentsToFiles() {
        for document in company.wikiDocuments {
            // 부서 타입 추출 (tags에서)
            var departmentType: DepartmentType = .general
            for tag in document.tags {
                if let deptType = DepartmentType(rawValue: tag) {
                    departmentType = deptType
                    break
                }
            }

            // 프로젝트명 추출 (tags에서 - 직원명과 부서명이 아닌 태그)
            let knownTags = Set(DepartmentType.allCases.map { $0.rawValue })
            let projectName = document.tags.first { tag in
                !knownTags.contains(tag) && tag != document.createdBy
            }

            // 저장 경로 결정
            let documentsPath: String
            if let projName = projectName {
                // 프로젝트별 부서 문서 폴더
                documentsPath = DataPathService.shared.documentsPath(projName, department: departmentType)
            } else {
                // 전사 공용 부서 문서 폴더
                let basePath = DataPathService.shared.basePath
                documentsPath = "\(basePath)/_shared/\(departmentType.directoryName)/documents"
                DataPathService.shared.createDirectoryIfNeeded(at: documentsPath)
            }

            // 파일 저장
            let filePath = (documentsPath as NSString).appendingPathComponent(document.fileName)
            try? document.content.write(toFile: filePath, atomically: true, encoding: .utf8)
        }
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
            employeeStatuses[employee.id] = employee.status  // 중앙 저장소에 등록
            saveCompany()

            // 프로젝트 직원 프로필 파일 생성
            let projectName = company.projects[index].name
            EmployeeWorkLogService.shared.createProjectEmployeeProfile(employee: employee, projectName: projectName)
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
        let previousStatus = employeeStatuses[employeeId]

        // 상태가 변경된 경우에만 처리
        guard previousStatus != status else { return }

        // 중앙 저장소 업데이트
        employeeStatuses[employeeId] = status

        // 데이터 모델도 동기화
        guard let projectIndex = company.projects.firstIndex(where: { $0.id == projectId }) else { return }
        for deptIndex in company.projects[projectIndex].departments.indices {
            if let empIndex = company.projects[projectIndex].departments[deptIndex].employees.firstIndex(where: { $0.id == employeeId }) {
                company.projects[projectIndex].departments[deptIndex].employees[empIndex].status = status
                break
            }
        }

        // company를 다시 할당하여 @Published 트리거 (UI 전체 업데이트)
        let updatedCompany = company
        company = updatedCompany

        // 직원 이름 찾기
        let employeeName = findEmployeeName(byId: employeeId)

        // 토스트 알림
        let toastType: ToastType = status == .thinking ? .info : (status == .idle ? .success : .info)
        ToastManager.shared.show(
            title: "\(employeeName) 상태 변경",
            message: "\(previousStatus?.rawValue ?? "알 수 없음") → \(status.rawValue)",
            type: toastType
        )

        // 시스템 알림 (앱이 백그라운드일 때 유용)
        ToastManager.shared.sendNotification(
            title: "\(employeeName) 상태 변경",
            body: "\(status.rawValue)"
        )
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

    // MARK: - Collaboration Records

    /// 협업 기록 추가
    func addCollaborationRecord(_ record: CollaborationRecord) {
        company.collaborationRecords.append(record)
        saveCompany()
    }

    /// 협업 기록 조회 (최신순)
    var collaborationRecords: [CollaborationRecord] {
        company.collaborationRecords.sorted { $0.timestamp > $1.timestamp }
    }

    /// 특정 부서의 협업 기록
    func getCollaborationRecords(forDepartment department: String) -> [CollaborationRecord] {
        collaborationRecords.filter {
            $0.requesterDepartment == department || $0.responderDepartment == department
        }
    }

    /// 특정 프로젝트의 협업 기록
    func getCollaborationRecords(forProject projectId: UUID) -> [CollaborationRecord] {
        collaborationRecords.filter { $0.projectId == projectId }
    }

    /// 협업 기록 삭제
    func removeCollaborationRecord(_ recordId: UUID) {
        company.collaborationRecords.removeAll { $0.id == recordId }
        saveCompany()
    }

    /// 모든 협업 기록 삭제
    func clearAllCollaborationRecords() {
        company.collaborationRecords.removeAll()
        saveCompany()
    }

    // MARK: - Employee Thinking

    /// 새 사고 과정 시작
    func startThinking(employeeId: UUID, employeeName: String, departmentType: DepartmentType, topic: String) -> EmployeeThinking {
        let thinking = EmployeeThinking(
            employeeId: employeeId,
            employeeName: employeeName,
            departmentType: departmentType,
            topic: topic,
            topicCreatedAt: Date(),
            reasoning: ThinkingReasoning()
        )
        company.employeeThinkings.append(thinking)
        saveCompany()
        return thinking
    }

    /// 사고 과정에 정보 추가
    func addThinkingInput(thinkingId: UUID, content: String, source: String) {
        guard let index = company.employeeThinkings.firstIndex(where: { $0.id == thinkingId }) else { return }
        let input = ThinkingInput(content: content, source: source)
        company.employeeThinkings[index].inputs.append(input)
        saveCompany()
    }

    /// 사고 과정 갱신
    func updateThinkingReasoning(thinkingId: UUID, reasoning: ThinkingReasoning) {
        guard let index = company.employeeThinkings.firstIndex(where: { $0.id == thinkingId }) else { return }
        company.employeeThinkings[index].reasoning = reasoning
        company.employeeThinkings[index].reasoning.lastUpdated = Date()
        saveCompany()
    }

    /// 결론 설정
    func setThinkingConclusion(thinkingId: UUID, conclusion: ThinkingConclusion) {
        guard let index = company.employeeThinkings.firstIndex(where: { $0.id == thinkingId }) else { return }
        company.employeeThinkings[index].conclusion = conclusion
        company.employeeThinkings[index].status = .concluded
        saveCompany()
    }

    /// 직원의 활성 사고 과정 조회
    func getActiveThinking(employeeId: UUID) -> EmployeeThinking? {
        company.employeeThinkings.first {
            $0.employeeId == employeeId && $0.status == .thinking
        }
    }

    /// 모든 사고 과정 조회
    var employeeThinkings: [EmployeeThinking] {
        company.employeeThinkings.sorted { $0.topicCreatedAt > $1.topicCreatedAt }
    }

    // MARK: - Community Posts

    /// 게시글 작성
    func addCommunityPost(_ post: CommunityPost) {
        company.communityPosts.append(post)

        // 연결된 사고 과정이 있으면 상태 업데이트
        if let thinkingId = post.thinkingId,
           let index = company.employeeThinkings.firstIndex(where: { $0.id == thinkingId }) {
            company.employeeThinkings[index].status = .posted
        }

        saveCompany()
    }

    /// 사고 과정에서 게시글 생성
    func createPostFromThinking(_ thinking: EmployeeThinking) -> CommunityPost? {
        guard let conclusion = thinking.conclusion else { return nil }

        let post = CommunityPost(
            employeeId: thinking.employeeId,
            employeeName: thinking.employeeName,
            departmentType: thinking.departmentType,
            thinkingId: thinking.id,
            title: thinking.topic,
            content: """
            ## 결론

            \(conclusion.summary)

            ## 근거

            \(conclusion.reasoning)

            ## 실행 계획

            \(conclusion.actionPlan.map { "- \($0)" }.joined(separator: "\n"))

            ## 리스크

            \(conclusion.risks.map { "- \($0)" }.joined(separator: "\n"))
            """,
            summary: conclusion.summary,
            tags: [thinking.departmentType.rawValue]
        )

        addCommunityPost(post)
        return post
    }

    /// 게시글 조회 (최신순)
    var communityPosts: [CommunityPost] {
        company.communityPosts.sorted { $0.createdAt > $1.createdAt }
    }

    /// 특정 직원의 게시글
    func getCommunityPosts(employeeId: UUID) -> [CommunityPost] {
        communityPosts.filter { $0.employeeId == employeeId }
    }

    /// 좋아요 추가
    func likeCommunityPost(_ postId: UUID) {
        guard let index = company.communityPosts.firstIndex(where: { $0.id == postId }) else { return }
        company.communityPosts[index].likes += 1
        saveCompany()
    }

    /// 댓글 추가
    func addCommentToPost(_ postId: UUID, comment: PostComment) {
        guard let index = company.communityPosts.firstIndex(where: { $0.id == postId }) else { return }
        company.communityPosts[index].comments.append(comment)
        saveCompany()
    }

    /// 게시글 삭제
    func removeCommunityPost(_ postId: UUID) {
        company.communityPosts.removeAll { $0.id == postId }
        saveCompany()
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
