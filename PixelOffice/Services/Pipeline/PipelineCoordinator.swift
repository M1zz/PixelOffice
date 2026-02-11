import Foundation
import SwiftUI
import Combine

/// 파이프라인 전체 조율자
@MainActor
class PipelineCoordinator: ObservableObject {
    // MARK: - Published Properties

    @Published var currentRun: PipelineRun?
    @Published var isRunning: Bool = false
    @Published var progress: Double = 0.0
    @Published var currentPhaseDescription: String = ""
    @Published var lastReportPath: String?

    /// 실시간 상태 표시용
    @Published var currentTaskIndex: Int = 0
    @Published var currentTaskName: String = ""
    @Published var currentAction: String = ""  // Claude Code 스타일 현재 작업
    @Published var todoItems: [PipelineTodoItem] = []  // TODO 리스트

    /// 알림 메시지 (일시정지, 완료 등)
    @Published var notificationMessage: String?
    @Published var notificationType: NotificationType = .info

    /// 실시간 토큰 사용량
    @Published var totalInputTokens: Int = 0
    @Published var totalOutputTokens: Int = 0
    @Published var totalCostUSD: Double = 0

    var totalTokens: Int {
        totalInputTokens + totalOutputTokens
    }

    /// 히스토리 변경 감지용 (뷰 새로고침 트리거)
    @Published var historyUpdateId = UUID()

    enum NotificationType {
        case info, success, warning, error

        var color: Color {
            switch self {
            case .info: return .blue
            case .success: return .green
            case .warning: return .orange
            case .error: return .red
            }
        }

        var icon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            }
        }
    }

    // MARK: - Private Properties

    private weak var companyStore: CompanyStore?
    private let decomposer = RequirementDecomposer()
    private var executor: PipelineExecutor
    private let buildService = BuildService()
    private var cancellationFlag = false
    private var currentProjectName: String = ""

    /// 최대 동시 실행 태스크 수 (기본 3개)
    nonisolated static let defaultMaxConcurrentTasks = 3

    /// 현재 실행 모드
    @Published var executionMode: PipelineExecutionMode = .full  // 기본값을 full로 변경 (파일 생성 가능)

    // MARK: - Init

    init(companyStore: CompanyStore? = nil, maxConcurrentTasks: Int = defaultMaxConcurrentTasks, executionMode: PipelineExecutionMode = .full) {
        self.companyStore = companyStore
        self.executionMode = executionMode
        self.executor = PipelineExecutor(maxConcurrentTasks: maxConcurrentTasks, executionMode: executionMode)
    }

    /// 실행 모드 변경
    func setExecutionMode(_ mode: PipelineExecutionMode) {
        self.executionMode = mode
        self.executor = PipelineExecutor(
            maxConcurrentTasks: PipelineCoordinator.defaultMaxConcurrentTasks,
            executionMode: mode
        )
    }

    func setCompanyStore(_ store: CompanyStore) {
        self.companyStore = store
    }

    // MARK: - Pipeline Control

    /// 파이프라인 시작
    /// - Parameters:
    ///   - requirement: 요구사항 텍스트
    ///   - project: 대상 프로젝트
    ///   - sprint: 스프린트 (태스크가 할당될 스프린트)
    func startPipeline(requirement: String, project: Project, sprint: Sprint? = nil) async {
        guard !isRunning else {
            print("[PipelineCoordinator] Pipeline already running")
            return
        }

        // 🔍 사전 검증: 프로젝트 경로 확인
        let projectInfo = loadProjectInfo(for: project)
        if projectInfo == nil || projectInfo?.absolutePath.isEmpty == true {
            let errorMessage = buildProjectPathErrorMessage(project: project, projectInfo: projectInfo)
            showNotification(errorMessage, type: .error)
            print("[PipelineCoordinator] 파이프라인 시작 실패: \(errorMessage)")
            return
        }

        isRunning = true
        cancellationFlag = false
        progress = 0.0
        currentProjectName = project.name

        // 토큰 카운터 초기화
        totalInputTokens = 0
        totalOutputTokens = 0
        totalCostUSD = 0

        // TODO 리스트 초기화
        initializeTodoList()

        var run = PipelineRun(projectId: project.id, requirement: requirement)
        run.projectName = project.name
        run.sprintId = sprint?.id
        run.sprintName = sprint?.name
        run.startedAt = Date()
        run.state = .decomposing

        var logMessage = "파이프라인 시작"
        if let sprint = sprint {
            logMessage += " [스프린트: \(sprint.name)]"
        }
        run.addLog(logMessage, level: .info)

        // 프로젝트 경로 로그
        if let path = projectInfo?.absolutePath {
            run.addLog("📍 프로젝트 경로: \(path)", level: .info)
        }

        currentRun = run
        updateAction("파이프라인 초기화 중...")

        // 초기 상태 저장
        saveRunProgress(run)

        await executePipelinePhases(run: &run, project: project, startPhase: .decomposition)
    }

    /// 파이프라인 재개
    func resumePipeline(run: PipelineRun, project: Project) async {
        guard !isRunning else {
            print("[PipelineCoordinator] Pipeline already running")
            return
        }

        isRunning = true
        cancellationFlag = false
        currentProjectName = project.name

        // 토큰 카운터 초기화 (재개 시에도 새로 시작)
        totalInputTokens = 0
        totalOutputTokens = 0
        totalCostUSD = 0

        // TODO 리스트 초기화 (완료된 항목 반영)
        initializeTodoList()
        for phase in run.completedPhases {
            completeTodo(phase: phase)
        }

        var resumeRun = run
        resumeRun.state = .decomposing  // 임시, 실제 Phase에서 변경됨
        resumeRun.addLog("🔄 파이프라인 재개", level: .info)
        resumeRun.addLog("   재개 Phase: \(run.resumePhase.name)", level: .info)
        resumeRun.addLog("   완료된 Phase: \(run.completedPhases.map { $0.name }.joined(separator: ", "))", level: .debug)
        currentRun = resumeRun
        updateAction("파이프라인 재개 중...")

        // 진행률 복원
        progress = Double(run.completedPhases.count) * 0.25

        await executePipelinePhases(run: &resumeRun, project: project, startPhase: run.resumePhase)
    }

    /// 칸반에서 태스크를 가져와서 파이프라인 시작
    /// - Parameters:
    ///   - tasks: 칸반에서 선택한 태스크들
    ///   - project: 대상 프로젝트
    ///   - sprint: 스프린트
    func startPipelineWithKanbanTasks(tasks: [ProjectTask], project: Project, sprint: Sprint? = nil) async {
        guard !isRunning else {
            print("[PipelineCoordinator] Pipeline already running")
            return
        }

        guard !tasks.isEmpty else {
            showNotification("선택된 태스크가 없습니다.", type: .warning)
            return
        }

        // 🔍 이미 완료된 태스크 검증
        let (pendingTasks, completedTasks) = filterCompletedTasks(tasks, in: project)

        if !completedTasks.isEmpty {
            let completedNames = completedTasks.map { $0.title }.joined(separator: ", ")
            if pendingTasks.isEmpty {
                // 모든 태스크가 이미 완료됨
                showNotification("선택된 태스크가 이미 모두 완료되었습니다: \(completedNames)", type: .info)
                print("[PipelineCoordinator] 모든 태스크가 이미 완료됨: \(completedNames)")
                return
            } else {
                // 일부만 완료됨 - 미완료 태스크만 진행
                showNotification("이미 완료된 태스크 제외: \(completedTasks.count)개 (미완료 \(pendingTasks.count)개 진행)", type: .info)
                print("[PipelineCoordinator] 완료된 태스크 제외: \(completedNames)")
            }
        }

        // 실행할 태스크가 없으면 중단
        guard !pendingTasks.isEmpty else {
            showNotification("실행할 태스크가 없습니다.", type: .warning)
            return
        }

        isRunning = true
        cancellationFlag = false
        progress = 0.0
        currentProjectName = project.name

        // 토큰 카운터 초기화
        totalInputTokens = 0
        totalOutputTokens = 0
        totalCostUSD = 0

        // TODO 리스트 초기화 (분해 단계는 스킵)
        initializeTodoList()
        completeTodo(phase: .decomposition)  // 분해 완료로 표시

        // 요구사항은 선택된 태스크들의 제목을 연결 (미완료 태스크만)
        let requirement = pendingTasks.map { $0.title }.joined(separator: ", ")

        var run = PipelineRun(projectId: project.id, requirement: "칸반 태스크 처리: \(requirement)")
        run.projectName = project.name
        run.sprintId = sprint?.id
        run.sprintName = sprint?.name
        run.startedAt = Date()
        run.state = .executing

        // ProjectTask를 DecomposedTask로 변환 (pendingTasks만 사용)
        run.decomposedTasks = pendingTasks.enumerated().map { index, task in
            DecomposedTask(
                id: task.id,  // 원본 ID 유지
                title: task.title,
                description: task.description,
                department: task.departmentType,
                priority: task.priority,
                order: index
            )
        }

        run.addLog("칸반에서 \(pendingTasks.count)개 태스크를 가져왔습니다.", level: .info)
        if !completedTasks.isEmpty {
            run.addLog("⏭️ 이미 완료된 태스크 \(completedTasks.count)개 제외됨", level: .info)
        }
        if let sprint = sprint {
            run.addLog("스프린트: \(sprint.name)", level: .info)
        }

        currentRun = run
        updateAction("칸반 태스크 처리 준비 중...")

        // 초기 상태 저장
        saveRunProgress(run)

        // 분해 단계 완료로 표시하고 개발 단계부터 시작
        run.markPhaseCompleted(.decomposition)
        progress = 0.25

        await executePipelinePhases(run: &run, project: project, startPhase: .development)
    }

    /// 파이프라인 Phase 실행 (시작/재개 공통)
    private func executePipelinePhases(run: inout PipelineRun, project: Project, startPhase: PipelinePhase) async {
        do {
            var currentRun = run

            // Phase 1: 요구사항 분해 (재개 시 이미 완료되었으면 스킵)
            if startPhase.rawValue <= PipelinePhase.decomposition.rawValue && !currentRun.completedPhases.contains(.decomposition) {
                currentRun = try await executeDecompositionPhase(run: currentRun, project: project)
                if cancellationFlag { return cancelWithSave(&currentRun) }
                currentRun.markPhaseCompleted(.decomposition)
                saveRunProgress(currentRun)
            }

            // Phase 2: 개발 (코드 생성)
            if startPhase.rawValue <= PipelinePhase.development.rawValue && !currentRun.completedPhases.contains(.development) {
                currentRun = try await executeDevelopmentPhase(run: currentRun, project: project)
                if cancellationFlag { return cancelWithSave(&currentRun) }
                currentRun.markPhaseCompleted(.development)
                saveRunProgress(currentRun)
            }

            // Phase 3: 빌드
            if startPhase.rawValue <= PipelinePhase.build.rawValue && !currentRun.completedPhases.contains(.build) {
                currentRun = try await executeBuildPhase(run: currentRun, project: project)
                if cancellationFlag { return cancelWithSave(&currentRun) }
                currentRun.markPhaseCompleted(.build)
                saveRunProgress(currentRun)
            }

            // Phase 4: Self-Healing (빌드 실패 시)
            if !currentRun.isBuildSuccessful && currentRun.canHeal {
                currentRun = try await executeHealingPhase(run: currentRun, project: project)
                currentRun.markPhaseCompleted(.healing)
                saveRunProgress(currentRun)
            }

            // 완료
            currentRun.state = currentRun.isBuildSuccessful ? .completed : .failed
            currentRun.completedAt = Date()
            currentRun.addLog(currentRun.isBuildSuccessful ? "파이프라인 완료!" : "파이프라인 실패", level: currentRun.isBuildSuccessful ? .success : .error)
            self.currentRun = currentRun
            progress = 1.0
            updateAction(currentRun.isBuildSuccessful ? "✅ 완료!" : "❌ 실패")
            completeTodo(phase: .healing)

            // 리포트 생성
            generateReport(for: currentRun, projectName: project.name)

            // 파이프라인 저장
            savePipelineRun(currentRun)

            // 완료/실패 알림
            if currentRun.isBuildSuccessful {
                showNotification("파이프라인이 성공적으로 완료되었습니다!", type: .success)

                // 칸반 태스크 완료 처리
                syncCompletedTasksToKanban(run: currentRun, project: project)
            } else {
                showNotification("파이프라인이 실패했습니다. 로그를 확인하세요.", type: .error)
            }

        } catch {
            run.state = .failed
            run.completedAt = Date()
            run.addLog("오류: \(error.localizedDescription)", level: .error)
            currentRun = run
            updateAction("❌ 오류 발생")

            // 실패해도 리포트 생성
            generateReport(for: run, projectName: project.name)

            // 파이프라인 저장
            savePipelineRun(run)

            // 오류 알림
            showNotification("파이프라인 오류: \(error.localizedDescription)", type: .error)
        }

        isRunning = false
    }

    /// 진행 상태 저장 (각 Phase 완료 시)
    private func saveRunProgress(_ run: PipelineRun) {
        var runToSave = run
        runToSave.lastSavedAt = Date()
        savePipelineRun(runToSave)
        self.currentRun = runToSave
        print("[PipelineCoordinator] 진행 상태 저장됨: Phase \(run.currentPhase.name)")
    }

    /// 취소 시 저장
    private func cancelWithSave(_ run: inout PipelineRun) {
        run.state = .paused
        run.addLog("파이프라인 일시정지됨 (재개 가능)", level: .warning)
        currentRun = run
        savePipelineRun(run)
        isRunning = false
        updateAction("⏸️ 일시정지됨")
        showNotification("파이프라인이 일시정지되었습니다. 히스토리에서 재개할 수 있습니다.", type: .warning)

        // 모든 작업 중인 직원을 휴식 중으로 변경
        resetAllEmployeesToIdle(projectId: run.projectId)
    }

    /// 알림 표시
    func showNotification(_ message: String, type: NotificationType) {
        notificationMessage = message
        notificationType = type

        // 5초 후 자동으로 알림 숨김
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            if self?.notificationMessage == message {
                self?.notificationMessage = nil
            }
        }
    }

    /// 알림 닫기
    func dismissNotification() {
        notificationMessage = nil
    }

    /// 리포트 생성
    private func generateReport(for run: PipelineRun, projectName: String) {
        if let path = PipelineReportService.shared.generateAndSaveReport(for: run, projectName: projectName) {
            lastReportPath = path
            currentRun?.addLog("리포트 생성됨: \(path)", level: .info)
        }
    }

    /// 파이프라인 취소 (일시정지)
    func cancelPipeline() {
        cancellationFlag = true
    }

    /// 모든 실행 중인 프로세스 강제 중지
    func stopAllProcesses() {
        cancellationFlag = true
        ClaudeCodeService.processManager.stopAll()
        showNotification("모든 작업이 중지되었습니다.", type: .warning)
        updateAction("⏹️ 모든 작업 중지됨")

        // 현재 실행 상태도 업데이트
        if var run = currentRun {
            run.state = .cancelled
            run.completedAt = Date()
            run.addLog("모든 작업이 강제 중지됨", level: .warning)
            currentRun = run
            savePipelineRun(run)

            // 모든 작업 중인 직원을 휴식 중으로 변경
            resetAllEmployeesToIdle(projectId: run.projectId)
        }
        isRunning = false
    }

    /// 프로젝트의 모든 직원을 휴식 중으로 변경
    private func resetAllEmployeesToIdle(projectId: UUID) {
        guard let companyStore = companyStore,
              let project = companyStore.company.projects.first(where: { $0.id == projectId }) else {
            return
        }

        for department in project.departments {
            for employee in department.employees {
                if employee.status == .working {
                    companyStore.updateProjectEmployeeStatus(
                        employee.id,
                        inProject: projectId,
                        status: .idle
                    )
                    currentRun?.addLog("🔄 \(employee.name) 상태: 휴식 중 (중지됨)", level: .debug)
                }
            }
        }
    }

    /// 실행 중인 프로세스 수
    var runningProcessCount: Int {
        ClaudeCodeService.processManager.runningCount
    }

    private func cancel() {
        guard var run = currentRun else { return }
        run.state = .paused  // 취소 대신 일시정지 (재개 가능)
        run.addLog("파이프라인 일시정지됨 (재개 가능)", level: .warning)
        savePipelineRun(run)  // 저장
        currentRun = run
        isRunning = false
        updateAction("⏸️ 일시정지됨")
        showNotification("파이프라인이 일시정지되었습니다. 히스토리에서 재개할 수 있습니다.", type: .warning)

        // 모든 작업 중인 직원을 휴식 중으로 변경
        resetAllEmployeesToIdle(projectId: run.projectId)
    }

    // MARK: - Phase 1: Decomposition

    private func executeDecompositionPhase(run: PipelineRun, project: Project) async throws -> PipelineRun {
        var run = run
        run.currentPhase = .decomposition
        run.state = .decomposing
        currentPhaseDescription = "요구사항 분해 중..."
        run.addLog("Phase 1: 요구사항 분해 시작", level: .info)
        currentRun = run

        startTodo(phase: .decomposition)
        run.addLog("📂 프로젝트 정보 로드 중...", level: .info)
        updateAction("프로젝트 정보 로드 중...")

        // PROJECT.md에서 ProjectInfo 로드
        let projectInfo = loadProjectInfo(for: project)
        if let info = projectInfo {
            run.addLog("   - 언어: \(info.language)", level: .debug)
            run.addLog("   - 프레임워크: \(info.framework)", level: .debug)
            run.addLog("   - 경로: \(info.absolutePath)", level: .debug)
        }
        updateAction("PROJECT.md 분석 완료")
        run.addLog("✓ PROJECT.md 분석 완료", level: .info)

        // 프로젝트 컨텍스트 읽기
        var projectContext = project.projectContext
        if let projectMdPath = getProjectMdPath(project: project) {
            if let content = try? String(contentsOfFile: projectMdPath, encoding: .utf8) {
                projectContext = content
                run.addLog("📄 프로젝트 컨텍스트 로드: \(content.count)자", level: .debug)
            }
        }

        run.addLog("🤖 AI에게 요구사항 분해 요청 중...", level: .info)
        run.addLog("   요구사항: \(run.requirement.prefix(100))...", level: .debug)
        updateAction("AI에게 요구사항 분해 요청 중...")

        let autoApprove = companyStore?.company.settings.autoApproveAI ?? true
        let decomposeStartTime = Date()
        let result = try await decomposer.decompose(
            requirement: run.requirement,
            projectInfo: projectInfo,
            projectContext: projectContext,
            autoApprove: autoApprove
        )
        let decomposeElapsed = Date().timeIntervalSince(decomposeStartTime)

        run.decomposedTasks = result.tasks
        run.addLog("✅ 분해 완료: \(result.tasks.count)개 태스크 (소요시간: \(String(format: "%.1f", decomposeElapsed))초)", level: .success)

        // 분해된 태스크 목록 로그
        for (index, task) in result.tasks.enumerated() {
            run.addLog("   [\(index + 1)] \(task.title) (\(task.department.rawValue))", level: .debug)
        }

        updateAction("✓ 분해 완료: \(result.tasks.count)개 태스크 생성")

        if !result.warnings.isEmpty {
            for warning in result.warnings {
                run.addLog("경고: \(warning)", level: .warning)
            }
        }

        progress = 0.25
        currentRun = run
        completeTodo(phase: .decomposition)
        return run
    }

    // MARK: - Phase 2: Development

    private func executeDevelopmentPhase(run: PipelineRun, project: Project) async throws -> PipelineRun {
        var run = run
        run.currentPhase = .development
        run.state = .executing
        currentPhaseDescription = "코드 생성 중..."
        run.addLog("Phase 2: 코드 생성 시작", level: .info)
        currentRun = run

        startTodo(phase: .development)
        run.addLog("💻 개발 태스크 준비 중...", level: .info)
        updateAction("개발 태스크 준비 중...")

        let allEmployees = project.departments.flatMap { $0.employees }
        let projectInfo = loadProjectInfo(for: project)
        let totalTasks = run.decomposedTasks.count
        let autoApprove = companyStore?.company.settings.autoApproveAI ?? true

        // 직원 현황 로그
        run.addLog("👥 참여 직원: \(allEmployees.count)명", level: .debug)
        let deptCounts = Dictionary(grouping: allEmployees) { $0.departmentType }
            .mapValues { $0.count }
        for (dept, count) in deptCounts.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            run.addLog("   - \(dept.rawValue)팀: \(count)명", level: .debug)
        }

        run.addLog("📋 실행할 태스크: \(totalTasks)개", level: .info)

        // 프로젝트 컨텍스트 문서 로드 (한번만 읽어서 모든 태스크에 전달)
        updateAction("프로젝트 문서 컨텍스트 로드 중...")
        run.addLog("📚 프로젝트 컨텍스트 로드 시작...", level: .info)
        let projectContext = loadProjectContext(for: project)
        if !projectContext.isEmpty {
            run.addLog("📚 컨텍스트 로드 완료: \(projectContext.count)자", level: .info)
            run.addLog("   - PROJECT.md, 개발 문서, 디렉토리 구조 포함", level: .debug)
        } else {
            run.addLog("⚠️ 프로젝트 컨텍스트를 찾을 수 없습니다", level: .warning)
        }

        // 실행 모드 로그
        run.addLog("⚙️ 실행 모드: \(executionMode.rawValue) - \(executionMode.description)", level: .info)

        run.decomposedTasks = try await executor.executeTasks(
            run.decomposedTasks,
            project: project,
            projectInfo: projectInfo,
            employees: allEmployees,
            projectContext: projectContext.isEmpty ? nil : projectContext,
            autoApprove: autoApprove,
            onProgress: { [weak self] task, message in
                Task { @MainActor in
                    guard let self = self else { return }
                    // currentRun 변경 감지를 위해 명시적으로 업데이트
                    if var updatedRun = self.currentRun {
                        updatedRun.addLog(message, level: .info)
                        self.currentRun = updatedRun  // 재할당으로 @Published 트리거
                    }
                    if let index = run.decomposedTasks.firstIndex(where: { $0.id == task.id }) {
                        self.currentTaskIndex = index + 1
                        self.currentTaskName = task.title
                        self.updateAction("[\(index + 1)/\(totalTasks)] \(task.title)")
                    }
                }
            },
            onTokenUsage: { [weak self] inputTokens, outputTokens, costUSD in
                Task { @MainActor in
                    self?.addTokenUsage(input: inputTokens, output: outputTokens, cost: costUSD)
                }
            },
            onEmployeeStatus: { [weak self] employeeId, employeeName, isWorking in
                Task { @MainActor in
                    guard let self = self, let companyStore = self.companyStore else { return }

                    let status: EmployeeStatus = isWorking ? .working : .idle
                    companyStore.updateProjectEmployeeStatus(
                        employeeId,
                        inProject: project.id,
                        status: status
                    )

                    if isWorking {
                        self.currentRun?.addLog("   🔄 \(employeeName) 상태: 작업 중", level: .debug)
                    } else {
                        self.currentRun?.addLog("   🔄 \(employeeName) 상태: 휴식 중", level: .debug)
                    }
                }
            }
        )

        let completedCount = run.decomposedTasks.filter { $0.status == .completed }.count
        let failedCount = run.decomposedTasks.filter { $0.status == .failed }.count

        // 상세 결과 로그
        run.addLog("📊 코드 생성 결과 요약:", level: .info)
        run.addLog("   ✅ 성공: \(completedCount)개", level: completedCount > 0 ? .success : .info)
        if failedCount > 0 {
            run.addLog("   ❌ 실패: \(failedCount)개", level: .warning)
        }

        // 토큰 사용량 로그
        run.addLog("💰 총 토큰 사용량: \(totalTokens) (입력: \(totalInputTokens), 출력: \(totalOutputTokens))", level: .info)
        run.addLog("   비용: $\(String(format: "%.4f", totalCostUSD))", level: .info)

        run.addLog("✅ 코드 생성 완료", level: completedCount > 0 ? .success : .warning)
        updateAction("✓ 코드 생성 완료: 성공 \(completedCount), 실패 \(failedCount)")

        progress = 0.5
        currentRun = run
        completeTodo(phase: .development)
        return run
    }

    // MARK: - Phase 3: Build

    private func executeBuildPhase(run: PipelineRun, project: Project) async throws -> PipelineRun {
        var run = run
        run.currentPhase = .build
        run.state = .building
        currentPhaseDescription = "빌드 중..."
        run.addLog("🔨 Phase 3: 빌드 시작", level: .info)
        currentRun = run

        startTodo(phase: .build)
        run.addLog("📂 프로젝트 경로 확인 중...", level: .debug)
        updateAction("프로젝트 경로 확인 중...")

        let projectInfo = loadProjectInfo(for: project)
        guard let projectPath = projectInfo?.absolutePath, !projectPath.isEmpty else {
            let basePath = DataPathService.shared.basePath
            let projectMdPath = "\(basePath)/\(project.name)/PROJECT.md"

            run.addLog("❌ 프로젝트 경로가 설정되지 않음", level: .error)
            run.addLog("   PROJECT.md 위치: \(projectMdPath)", level: .error)
            run.addLog("   필요한 형식:", level: .error)
            run.addLog("   ## 프로젝트 경로", level: .error)
            run.addLog("   - **절대경로**: `/Users/.../YourProject`", level: .error)

            updateAction("✗ 프로젝트 경로가 설정되지 않음")
            showNotification("PROJECT.md에 프로젝트 절대경로를 설정해주세요.", type: .error)

            let attempt = BuildAttempt(
                success: false,
                exitCode: -1,
                output: "프로젝트 경로가 설정되지 않았습니다. PROJECT.md에 '## 프로젝트 경로' 섹션과 '- **절대경로**: /path' 형식으로 추가하세요.",
                errors: [BuildError(message: "프로젝트 경로 없음 - PROJECT.md 확인 필요", severity: .error)],
                startedAt: Date(),
                completedAt: Date()
            )
            run.buildAttempts.append(attempt)
            currentRun = run
            return run
        }

        run.addLog("📍 프로젝트 경로: \(projectPath)", level: .debug)
        run.addLog("🔧 xcodebuild 실행 중... (시간이 걸릴 수 있습니다)", level: .info)
        updateAction("xcodebuild 실행 중... (시간이 걸릴 수 있습니다)")

        let buildStartTime = Date()
        let attempt = try await buildService.build(projectPath: projectPath)
        let buildElapsed = Date().timeIntervalSince(buildStartTime)
        run.buildAttempts.append(attempt)

        run.addLog("⏱️ 빌드 소요시간: \(String(format: "%.1f", buildElapsed))초", level: .debug)

        if attempt.success {
            run.addLog("✅ 빌드 성공!", level: .success)
            updateAction("✓ 빌드 성공!")
        } else {
            run.addLog("❌ 빌드 실패: \(attempt.errors.count)개 에러", level: .error)
            updateAction("✗ 빌드 실패: \(attempt.errors.count)개 에러")
            for error in attempt.errors.prefix(10) {
                let location = error.location.isEmpty ? "" : " (\(error.location))"
                run.addLog("   ⚠️ \(error.message)\(location)", level: .error)
            }
            if attempt.errors.count > 10 {
                run.addLog("   ... 외 \(attempt.errors.count - 10)개 에러", level: .error)
            }
        }

        progress = 0.75
        currentRun = run
        completeTodo(phase: .build)
        return run
    }

    // MARK: - Phase 4: Self-Healing

    private func executeHealingPhase(run: PipelineRun, project: Project) async throws -> PipelineRun {
        var run = run
        run.currentPhase = .healing
        run.state = .healing
        run.healingAttempts += 1
        currentPhaseDescription = "Self-Healing 시도 \(run.healingAttempts)/\(run.maxHealingAttempts)..."
        run.addLog("🩹 Phase 4: Self-Healing 시작 (시도 \(run.healingAttempts)/\(run.maxHealingAttempts))", level: .info)
        currentRun = run

        startTodo(phase: .healing)
        run.addLog("🔍 빌드 에러 분석 중...", level: .info)
        updateAction("빌드 에러 분석 중...")

        guard let lastAttempt = run.lastBuildAttempt else {
            run.addLog("⚠️ 이전 빌드 시도를 찾을 수 없습니다", level: .warning)
            return run
        }

        run.addLog("   발견된 에러: \(lastAttempt.errors.count)개", level: .debug)
        for error in lastAttempt.errors.prefix(5) {
            run.addLog("   - \(error.message)", level: .debug)
        }

        let projectInfo = loadProjectInfo(for: project)

        // 에러 수정 프롬프트 생성
        run.addLog("📝 에러 수정 프롬프트 생성 중...", level: .debug)
        updateAction("에러 수정 프롬프트 생성 중...")
        let healingPrompt = await buildService.generateHealingPrompt(from: lastAttempt, projectInfo: projectInfo)

        // AI에게 수정 요청
        let claudeService = ClaudeCodeService()
        let systemPrompt = """
        당신은 시니어 개발자입니다. 빌드 에러를 분석하고 수정합니다.
        에러를 수정한 후 해당 파일을 직접 수정해주세요.
        """

        run.addLog("🤖 AI에게 에러 수정 요청 중...", level: .info)
        updateAction("AI에게 에러 수정 요청 중...")

        let healingStartTime = Date()
        let autoApprove = companyStore?.company.settings.autoApproveAI ?? true
        _ = try await claudeService.sendMessage(healingPrompt, systemPrompt: systemPrompt, autoApprove: autoApprove)
        let healingElapsed = Date().timeIntervalSince(healingStartTime)

        run.addLog("✓ AI 수정 완료 (소요시간: \(String(format: "%.1f", healingElapsed))초)", level: .info)
        run.addLog("🔨 재빌드 시작...", level: .info)
        updateAction("수정 완료, 재빌드 시작...")

        // 재빌드
        if let projectPath = projectInfo?.absolutePath {
            let rebuildStartTime = Date()
            var rebuildAttempt = try await buildService.build(projectPath: projectPath)
            let rebuildElapsed = Date().timeIntervalSince(rebuildStartTime)
            rebuildAttempt.isHealingAttempt = true
            run.buildAttempts.append(rebuildAttempt)

            run.addLog("⏱️ 재빌드 소요시간: \(String(format: "%.1f", rebuildElapsed))초", level: .debug)

            if rebuildAttempt.success {
                run.addLog("✅ Self-Healing 성공! 빌드 통과", level: .success)
                updateAction("✓ Self-Healing 성공!")
            } else {
                run.addLog("❌ Self-Healing 후에도 빌드 실패", level: .warning)
                run.addLog("   남은 에러: \(rebuildAttempt.errors.count)개", level: .debug)
                updateAction("✗ Self-Healing 실패")
            }
        }

        progress = 0.9
        currentRun = run
        return run
    }

    // MARK: - Helpers

    private func getProjectMdPath(project: Project) -> String? {
        let basePath = DataPathService.shared.basePath
        let projectPath = "\(basePath)/\(project.name)/PROJECT.md"
        if FileManager.default.fileExists(atPath: projectPath) {
            return projectPath
        }
        return nil
    }

    /// PIPELINE_CONTEXT.md 경로 가져오기
    private func getPipelineContextPath(project: Project) -> String? {
        let basePath = DataPathService.shared.basePath
        let contextPath = "\(basePath)/\(project.name)/PIPELINE_CONTEXT.md"
        if FileManager.default.fileExists(atPath: contextPath) {
            return contextPath
        }
        return nil
    }

    /// PIPELINE_CONTEXT.md 또는 PROJECT.md에서 ProjectInfo 로드
    private func loadProjectInfo(for project: Project) -> ProjectInfo? {
        let basePath = DataPathService.shared.basePath
        var info = ProjectInfo()

        // 0. Project.sourcePath가 설정되어 있으면 최우선 사용
        if let sourcePath = project.sourcePath, !sourcePath.isEmpty {
            info.absolutePath = sourcePath
            print("[PipelineCoordinator] Project.sourcePath 사용: \(sourcePath)")
        }

        // 1. 먼저 PIPELINE_CONTEXT.md 확인 (우선순위 높음)
        if let contextPath = getPipelineContextPath(project: project),
           let content = try? String(contentsOfFile: contextPath, encoding: .utf8) {
            print("[PipelineCoordinator] PIPELINE_CONTEXT.md 발견: \(contextPath)")

            // 코드 블록에서 경로 추출 (Project.sourcePath가 없을 때만)
            if info.absolutePath.isEmpty, let path = extractPathFromCodeBlock(content) {
                info.absolutePath = path
                print("[PipelineCoordinator] PIPELINE_CONTEXT.md에서 경로 추출: \(path)")
            }

            // 추가 정보 파싱
            info = parseContextFile(content, baseInfo: info)
        }

        // 2. PROJECT.md에서도 정보 보완
        if let projectMdPath = getProjectMdPath(project: project),
           let content = try? String(contentsOfFile: projectMdPath, encoding: .utf8) {
            let projectInfo = ProjectInfo.fromMarkdown(content)

            // 경로가 없으면 PROJECT.md에서 가져오기
            if info.absolutePath.isEmpty {
                info.absolutePath = projectInfo.absolutePath
            }

            // 기술 스택 정보 보완
            if info.language.isEmpty { info.language = projectInfo.language }
            if info.framework.isEmpty { info.framework = projectInfo.framework }
            if info.buildTool.isEmpty { info.buildTool = projectInfo.buildTool }
        }

        // 3. 여전히 경로가 없으면 대체 방법 시도
        if info.absolutePath.isEmpty {
            print("[PipelineCoordinator] 컨텍스트 파일에서 경로를 찾지 못함, 대체 경로 탐색 중...")

            // 3-1. "픽셀-오피스" 프로젝트는 현재 PixelOffice 자체를 가리킴
            let isPixelOfficeProject = project.name == "픽셀-오피스" ||
                                       project.name == "픽셀 오피스" ||
                                       project.name.lowercased().contains("pixeloffice")

            if isPixelOfficeProject, let projectRoot = findProjectRootPath() {
                info.absolutePath = projectRoot
                print("[PipelineCoordinator] PixelOffice 자체 프로젝트 감지: \(projectRoot)")
            }
            // 3-2. 다른 프로젝트는 Xcode 프로젝트 자동 탐색
            else if let foundXcodePath = findXcodeProjectPath(projectName: project.name) {
                info.absolutePath = foundXcodePath
                print("[PipelineCoordinator] Xcode 프로젝트 발견: \(foundXcodePath)")
            }
        }

        // 4. 경로가 여전히 없으면 프로젝트 루트 자체를 사용 (PixelOffice 내부 프로젝트)
        if info.absolutePath.isEmpty {
            print("[PipelineCoordinator] 컨텍스트 파일에서 경로를 찾지 못함, 프로젝트 루트 사용...")

            // PixelOffice 프로젝트 루트를 기본값으로 사용
            if let projectRoot = findProjectRootPath() {
                info.absolutePath = projectRoot
                print("[PipelineCoordinator] 프로젝트 루트 사용: \(projectRoot)")

                // PIPELINE_CONTEXT.md가 없으면 자동 생성 시도
                let contextPath = "\(basePath)/\(project.name)/PIPELINE_CONTEXT.md"
                if !FileManager.default.fileExists(atPath: contextPath) {
                    print("[PipelineCoordinator] 💡 PIPELINE_CONTEXT.md 자동 생성 중...")
                    DataPathService.shared.createProjectDirectories(projectName: project.name)
                }
            }
        }

        // 최종적으로 경로가 없으면 nil 반환
        if info.absolutePath.isEmpty {
            print("[PipelineCoordinator] ❌ 프로젝트 경로를 찾을 수 없음: \(project.name)")
            return nil
        }

        return info
    }

    /// 코드 블록에서 경로 추출 (```로 감싸진 경로)
    private func extractPathFromCodeBlock(_ content: String) -> String? {
        // "### 프로젝트 소스 경로" 섹션 찾기
        let lines = content.components(separatedBy: "\n")
        var inSourcePathSection = false
        var inCodeBlock = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // 섹션 시작
            if trimmed.contains("프로젝트 소스 경로") || trimmed.contains("프로젝트 경로") {
                inSourcePathSection = true
                continue
            }

            // 다른 섹션으로 이동
            if inSourcePathSection && trimmed.hasPrefix("###") {
                inSourcePathSection = false
                continue
            }

            // 코드 블록 시작/끝
            if trimmed.hasPrefix("```") {
                if inCodeBlock {
                    inCodeBlock = false
                } else {
                    inCodeBlock = true
                }
                continue
            }

            // 코드 블록 내 경로 추출 (절대경로 또는 상대경로)
            if inSourcePathSection && inCodeBlock && !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                let path = trimmed.trimmingCharacters(in: .whitespaces)

                // 절대경로
                if path.hasPrefix("/") {
                    if FileManager.default.fileExists(atPath: path) {
                        return path
                    }
                }
                // 상대경로 (../ 또는 ./)
                else if path.hasPrefix("..") || path.hasPrefix("./") {
                    // 프로젝트 루트 기준으로 해석
                    if let projectRoot = findProjectRootPath() {
                        let absolutePath = (projectRoot as NSString).appendingPathComponent(path)
                        let standardized = (absolutePath as NSString).standardizingPath
                        if FileManager.default.fileExists(atPath: standardized) {
                            return standardized
                        }
                    }
                }
            }

            // 인라인 경로 추출 (` ` 로 감싸진 경우)
            if inSourcePathSection && (trimmed.contains("`/") || trimmed.contains("`..")) {
                // 절대경로 또는 상대경로 패턴
                if let range = trimmed.range(of: "`([^`]+)`", options: .regularExpression) {
                    var path = String(trimmed[range])
                    path = path.trimmingCharacters(in: CharacterSet(charactersIn: "`"))

                    if path.hasPrefix("/") {
                        if FileManager.default.fileExists(atPath: path) {
                            return path
                        }
                    } else if path.hasPrefix("..") || path.hasPrefix("./") {
                        if let projectRoot = findProjectRootPath() {
                            let absolutePath = (projectRoot as NSString).appendingPathComponent(path)
                            let standardized = (absolutePath as NSString).standardizingPath
                            if FileManager.default.fileExists(atPath: standardized) {
                                return standardized
                            }
                        }
                    }
                }
            }
        }

        return nil
    }

    /// 프로젝트 루트 경로 찾기 (DataPathService와 동일 로직)
    private func findProjectRootPath() -> String? {
        // DataPathService의 프로젝트 루트 사용
        let basePath = DataPathService.shared.basePath
        // basePath는 ~/datas 이므로 상위 디렉토리가 프로젝트 루트
        return (basePath as NSString).deletingLastPathComponent
    }

    /// PIPELINE_CONTEXT.md 파싱
    private func parseContextFile(_ content: String, baseInfo: ProjectInfo) -> ProjectInfo {
        var info = baseInfo
        let lines = content.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // 섹션 헤더는 스킵
            if trimmed.hasPrefix("### ") || trimmed.hasPrefix("## ") {
                continue
            }

            // 키-값 파싱
            if trimmed.hasPrefix("- **") {
                if let colonRange = trimmed.range(of: "**: ") {
                    let key = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: 4)..<colonRange.lowerBound])
                    var value = String(trimmed[colonRange.upperBound...])

                    // 백틱 제거
                    if value.hasPrefix("`") && value.hasSuffix("`") {
                        value = String(value.dropFirst().dropLast())
                    }

                    // 값 적용
                    switch key {
                    case "언어": info.language = value
                    case "프레임워크": info.framework = value
                    case "빌드 시스템", "빌드 도구": info.buildTool = value
                    default: break
                    }
                }
            }
        }

        return info
    }

    /// Xcode 프로젝트 경로 자동 탐색
    private func findXcodeProjectPath(projectName: String) -> String? {
        let fileManager = FileManager.default
        let homeDir = fileManager.homeDirectoryForCurrentUser.path

        // 1. 먼저 DataPathService의 프로젝트 루트 확인 (현재 PixelOffice 자체)
        if let projectRoot = findProjectRootPath() {
            // 현재 프로젝트가 PixelOffice 자체인 경우
            if projectName == "픽셀-오피스" || projectName == "픽셀 오피스" || projectName.lowercased().contains("pixeloffice") {
                if let contents = try? fileManager.contentsOfDirectory(atPath: projectRoot),
                   contents.contains(where: { $0.hasSuffix(".xcodeproj") || $0.hasSuffix(".xcworkspace") }) {
                    return projectRoot
                }
            }
        }

        // 2. 일반적인 개발 경로 탐색
        let commonPaths = [
            "\(homeDir)/Documents/workspace/code/\(projectName)",
            "\(homeDir)/Documents/code/\(projectName)",
            "\(homeDir)/Developer/\(projectName)",
            "\(homeDir)/Projects/\(projectName)",
            "\(homeDir)/Code/\(projectName)",
            "\(homeDir)/Documents/\(projectName)"
        ]

        for basePath in commonPaths {
            // .xcodeproj 또는 .xcworkspace 찾기
            if let contents = try? fileManager.contentsOfDirectory(atPath: basePath) {
                if contents.contains(where: { $0.hasSuffix(".xcodeproj") || $0.hasSuffix(".xcworkspace") }) {
                    return basePath
                }
            }
        }

        // 3. 프로젝트명과 유사한 폴더 탐색 (케이스 무시)
        let searchPaths = [
            "\(homeDir)/Documents/workspace/code",
            "\(homeDir)/Documents/code",
            "\(homeDir)/Developer"
        ]

        let normalizedName = projectName.lowercased().replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "")

        for searchPath in searchPaths {
            if let folders = try? fileManager.contentsOfDirectory(atPath: searchPath) {
                for folder in folders {
                    let normalizedFolder = folder.lowercased().replacingOccurrences(of: "-", with: "").replacingOccurrences(of: " ", with: "")
                    if normalizedFolder.contains(normalizedName) || normalizedName.contains(normalizedFolder) {
                        let fullPath = "\(searchPath)/\(folder)"
                        if let contents = try? fileManager.contentsOfDirectory(atPath: fullPath),
                           contents.contains(where: { $0.hasSuffix(".xcodeproj") || $0.hasSuffix(".xcworkspace") }) {
                            return fullPath
                        }
                    }
                }
            }
        }

        return nil
    }

    /// 프로젝트 경로 오류 메시지 생성
    private func buildProjectPathErrorMessage(project: Project, projectInfo: ProjectInfo?) -> String {
        let basePath = DataPathService.shared.basePath
        let contextPath = "\(basePath)/\(project.name)/PIPELINE_CONTEXT.md"
        let templatePath = "\(basePath)/_shared/templates/PIPELINE_CONTEXT.md"

        return """
        프로젝트 소스 경로가 설정되지 않았습니다.

        📁 PIPELINE_CONTEXT.md 파일을 생성하세요:
           \(contextPath)

        📋 템플릿 위치:
           \(templatePath)

        필수 설정 형식:
        ```
        ### 프로젝트 소스 경로
        ```
        /Users/.../YourProject
        ```
        ```
        """
    }

    /// PROJECT.md에서 경로 패턴 추출 (다양한 형식 지원)
    private func extractPathFromMarkdown(_ content: String) -> String {
        let patterns = [
            // - **절대경로**: `/path`
            #"\*\*절대경로\*\*[:\s]+`?([^`\n]+)`?"#,
            // - **프로젝트 경로**: `/path`
            #"\*\*프로젝트 경로\*\*[:\s]+`?([^`\n]+)`?"#,
            // 경로: /path
            #"경로[:\s]+`?(/[^\s`\n]+)`?"#,
            // path: /path
            #"[Pp]ath[:\s]+`?(/[^\s`\n]+)`?"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: content) {
                let path = String(content[range]).trimmingCharacters(in: .whitespaces)
                if path.hasPrefix("/") && FileManager.default.fileExists(atPath: path) {
                    print("[PipelineCoordinator] 대체 패턴으로 경로 발견: \(path)")
                    return path
                }
            }
        }

        return ""
    }

    /// 프로젝트 컨텍스트 문서 로드 (PROJECT.md + 개발 문서)
    /// 이 컨텍스트를 모든 태스크에 전달하여 Claude가 파일을 반복해서 읽지 않도록 함
    private func loadProjectContext(for project: Project) -> String {
        var context = ""
        let basePath = DataPathService.shared.basePath
        let projectPath = "\(basePath)/\(project.name)"

        // 1. PROJECT.md 로드
        let projectMdPath = "\(projectPath)/PROJECT.md"
        if let projectMd = try? String(contentsOfFile: projectMdPath, encoding: .utf8) {
            context += "### PROJECT.md\n\n\(projectMd)\n\n"
        }

        // 2. 개발팀 문서 중 주요 문서 로드 (아키텍처, 코딩 컨벤션 등)
        let devDocsPath = "\(projectPath)/개발/documents"
        if let files = try? FileManager.default.contentsOfDirectory(atPath: devDocsPath) {
            let importantDocs = files.filter { name in
                let lowercased = name.lowercased()
                return lowercased.contains("architecture") ||
                       lowercased.contains("아키텍처") ||
                       lowercased.contains("convention") ||
                       lowercased.contains("컨벤션") ||
                       lowercased.contains("guide") ||
                       lowercased.contains("가이드") ||
                       lowercased.contains("readme")
            }.prefix(3)  // 최대 3개만

            for docName in importantDocs {
                let docPath = "\(devDocsPath)/\(docName)"
                if let content = try? String(contentsOfFile: docPath, encoding: .utf8) {
                    // 너무 긴 문서는 앞부분만
                    let truncated = content.count > 5000 ? String(content.prefix(5000)) + "\n...(생략)..." : content
                    context += "### \(docName)\n\n\(truncated)\n\n"
                }
            }
        }

        // 3. 프로젝트 구조 요약 (디렉토리 목록)
        if let projectInfo = loadProjectInfo(for: project),
           !projectInfo.absolutePath.isEmpty {
            let sourcePath = projectInfo.absolutePath
            context += "### 프로젝트 소스 디렉토리 구조\n\n"
            context += getDirectoryStructure(at: sourcePath, depth: 2)
            context += "\n\n"
        }

        // 컨텍스트가 너무 크면 제한
        if context.count > 30000 {
            context = String(context.prefix(30000)) + "\n\n...(컨텍스트 크기 제한으로 생략됨)..."
        }

        return context
    }

    /// 디렉토리 구조 문자열 생성 (depth 레벨까지)
    private func getDirectoryStructure(at path: String, depth: Int, currentDepth: Int = 0, indent: String = "") -> String {
        guard currentDepth < depth else { return "" }
        guard let items = try? FileManager.default.contentsOfDirectory(atPath: path) else { return "" }

        var result = ""
        let sortedItems = items.filter { !$0.hasPrefix(".") }.sorted()

        for item in sortedItems.prefix(20) {  // 각 레벨당 최대 20개
            let itemPath = (path as NSString).appendingPathComponent(item)
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: itemPath, isDirectory: &isDir)

            if isDir.boolValue {
                result += "\(indent)📁 \(item)/\n"
                result += getDirectoryStructure(at: itemPath, depth: depth, currentDepth: currentDepth + 1, indent: indent + "  ")
            } else if item.hasSuffix(".swift") || item.hasSuffix(".h") || item.hasSuffix(".m") {
                result += "\(indent)📄 \(item)\n"
            }
        }

        return result
    }

    // MARK: - Kanban Sync

    /// 파이프라인 완료 시 칸반 태스크 상태 동기화
    /// - Parameters:
    ///   - run: 완료된 파이프라인 실행
    ///   - project: 프로젝트
    private func syncCompletedTasksToKanban(run: PipelineRun, project: Project) {
        guard let companyStore = companyStore else {
            print("[PipelineCoordinator] CompanyStore가 없어 칸반 동기화 불가")
            return
        }

        var syncedCount = 0
        var updatedRun = run

        // 완료된 DecomposedTask에 대해 칸반 태스크 찾아서 업데이트
        for task in run.decomposedTasks where task.status == .completed {
            // 칸반에서 해당 decomposedTaskId를 가진 ProjectTask 찾기
            if let projectTask = findProjectTask(for: task.id, in: project) {
                var updatedTask = projectTask
                updatedTask.status = .done
                updatedTask.completedAt = Date()
                updatedTask.pipelineRunId = run.id
                companyStore.updateTask(updatedTask, inProject: project.id)
                syncedCount += 1
                updatedRun.addLog("✅ 칸반 태스크 완료 처리: \(updatedTask.title)", level: .debug)
            }
        }

        // 실패한 태스크는 needsReview로 변경
        for task in run.decomposedTasks where task.status == .failed {
            if let projectTask = findProjectTask(for: task.id, in: project) {
                var updatedTask = projectTask
                updatedTask.status = .needsReview
                updatedTask.pipelineRunId = run.id
                companyStore.updateTask(updatedTask, inProject: project.id)
                updatedRun.addLog("⚠️ 칸반 태스크 검토 필요: \(updatedTask.title)", level: .warning)
            }
        }

        if syncedCount > 0 {
            updatedRun.addLog("📋 칸반 동기화 완료: \(syncedCount)개 태스크 완료 처리됨", level: .success)
            currentRun = updatedRun
        }

        print("[PipelineCoordinator] 칸반 동기화 완료: \(syncedCount)개 태스크")
    }

    /// DecomposedTask ID로 ProjectTask 찾기
    private func findProjectTask(for decomposedTaskId: UUID, in project: Project) -> ProjectTask? {
        // 1. decomposedTaskId로 직접 매칭
        if let task = project.tasks.first(where: { $0.decomposedTaskId == decomposedTaskId }) {
            return task
        }

        // 2. decomposedTaskId가 없는 경우 task.id로 매칭 (칸반에서 직접 선택한 경우)
        // startPipelineWithKanbanTasks에서 task.id를 그대로 사용하므로
        if let task = project.tasks.first(where: { $0.id == decomposedTaskId }) {
            return task
        }

        return nil
    }

    /// 이미 완료된 태스크 필터링
    /// - Parameters:
    ///   - tasks: 선택된 태스크들
    ///   - project: 프로젝트
    /// - Returns: (실행할 태스크, 이미 완료된 태스크)
    func filterCompletedTasks(_ tasks: [ProjectTask], in project: Project) -> (pending: [ProjectTask], completed: [ProjectTask]) {
        let completed = tasks.filter { $0.status == .done }
        let pending = tasks.filter { $0.status != .done }
        return (pending, completed)
    }
}

// MARK: - TODO & Action Helpers

extension PipelineCoordinator {
    /// TODO 리스트 초기화
    func initializeTodoList() {
        todoItems = [
            PipelineTodoItem(phase: .decomposition, title: "요구사항 분해", description: "자연어 요구사항을 태스크로 분해"),
            PipelineTodoItem(phase: .development, title: "코드 생성", description: "AI가 각 태스크별로 코드 작성"),
            PipelineTodoItem(phase: .build, title: "빌드", description: "xcodebuild로 프로젝트 빌드"),
            PipelineTodoItem(phase: .healing, title: "Self-Healing", description: "빌드 에러 자동 수정")
        ]
    }

    /// 특정 Phase TODO 시작
    func startTodo(phase: PipelinePhase) {
        if let index = todoItems.firstIndex(where: { $0.phase == phase }) {
            todoItems[index].status = .inProgress
        }
    }

    /// 특정 Phase TODO 완료 (완료 후 1초 뒤 리스트에서 제거)
    func completeTodo(phase: PipelinePhase) {
        if let index = todoItems.firstIndex(where: { $0.phase == phase }) {
            todoItems[index].status = .completed
            
            // 1초 후 리스트에서 제거 (애니메이션 효과를 위해 딜레이)
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                withAnimation(.easeOut(duration: 0.3)) {
                    todoItems.removeAll { $0.phase == phase }
                }
            }
        }
    }

    /// 현재 작업 업데이트
    func updateAction(_ action: String) {
        currentAction = action
    }

    /// 토큰 사용량 추가
    func addTokenUsage(input: Int, output: Int, cost: Double) {
        totalInputTokens += input
        totalOutputTokens += output
        totalCostUSD += cost
    }
}

// MARK: - Pipeline History & Storage

extension PipelineCoordinator {
    /// 파이프라인 히스토리 저장 경로
    private var historyFilePath: String {
        let basePath = DataPathService.shared.basePath
        return "\(basePath)/_shared/pipeline_history.json"
    }

    /// 이전 파이프라인 실행 목록
    func loadPipelineHistory() -> [PipelineRun] {
        guard FileManager.default.fileExists(atPath: historyFilePath),
              let data = FileManager.default.contents(atPath: historyFilePath) else {
            print("[PipelineCoordinator] 히스토리 파일 없음: \(historyFilePath)")
            return []
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let runs = try decoder.decode([PipelineRun].self, from: data)
            print("[PipelineCoordinator] 히스토리 로드 성공: \(runs.count)개")
            return runs.sorted { $0.createdAt > $1.createdAt }
        } catch {
            print("[PipelineCoordinator] 히스토리 로드 실패: \(error)")
            return []
        }
    }

    /// 파이프라인 실행 저장
    func savePipelineRun(_ run: PipelineRun) {
        var history = loadPipelineHistory()

        // 기존 항목 업데이트 또는 추가
        if let index = history.firstIndex(where: { $0.id == run.id }) {
            history[index] = run
        } else {
            history.insert(run, at: 0)
        }

        // 최대 100개까지만 유지
        if history.count > 100 {
            history = Array(history.prefix(100))
        }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(history)

            // 디렉토리 생성
            let directory = (historyFilePath as NSString).deletingLastPathComponent
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)

            try data.write(to: URL(fileURLWithPath: historyFilePath))
            print("[PipelineCoordinator] 파이프라인 저장됨: \(historyFilePath)")

            // 히스토리 변경 알림 (뷰 새로고침)
            Task { @MainActor in
                self.historyUpdateId = UUID()
            }
        } catch {
            print("[PipelineCoordinator] 파이프라인 저장 실패: \(error)")
        }
    }

    /// 프로젝트별 히스토리 조회
    func loadPipelineHistory(for projectId: UUID) -> [PipelineRun] {
        return loadPipelineHistory().filter { $0.projectId == projectId }
    }

    /// 파이프라인 히스토리 삭제
    func deletePipelineRun(_ runId: UUID) {
        var history = loadPipelineHistory()

        // 해당 항목 제거
        history.removeAll { $0.id == runId }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(history)

            try data.write(to: URL(fileURLWithPath: historyFilePath))
            print("[PipelineCoordinator] 파이프라인 삭제됨: \(runId)")

            // 히스토리 변경 알림 (뷰 새로고침)
            Task { @MainActor in
                self.historyUpdateId = UUID()
            }

            showNotification("히스토리가 삭제되었습니다.", type: .info)
        } catch {
            print("[PipelineCoordinator] 파이프라인 삭제 실패: \(error)")
            showNotification("삭제에 실패했습니다.", type: .error)
        }
    }
}

// MARK: - Pipeline TODO Item

/// 파이프라인 TODO 아이템
struct PipelineTodoItem: Identifiable {
    let id = UUID()
    let phase: PipelinePhase
    let title: String
    let description: String
    var status: PipelineTodoStatus = .pending
}

enum PipelineTodoStatus {
    case pending
    case inProgress
    case completed
    case skipped

    var icon: String {
        switch self {
        case .pending: return "circle"
        case .inProgress: return "circle.dotted"
        case .completed: return "checkmark.circle.fill"
        case .skipped: return "minus.circle"
        }
    }

    var color: Color {
        switch self {
        case .pending: return .secondary
        case .inProgress: return .blue
        case .completed: return .green
        case .skipped: return .gray
        }
    }
}
