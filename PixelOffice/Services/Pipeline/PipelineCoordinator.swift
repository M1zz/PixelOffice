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

    // MARK: - Private Properties

    private weak var companyStore: CompanyStore?
    private let decomposer = RequirementDecomposer()
    private let executor = PipelineExecutor()
    private let buildService = BuildService()
    private var cancellationFlag = false
    private var currentProjectName: String = ""

    // MARK: - Init

    init(companyStore: CompanyStore? = nil) {
        self.companyStore = companyStore
    }

    func setCompanyStore(_ store: CompanyStore) {
        self.companyStore = store
    }

    // MARK: - Pipeline Control

    /// 파이프라인 시작
    func startPipeline(requirement: String, project: Project) async {
        guard !isRunning else {
            print("[PipelineCoordinator] Pipeline already running")
            return
        }

        isRunning = true
        cancellationFlag = false
        progress = 0.0
        currentProjectName = project.name

        // TODO 리스트 초기화
        initializeTodoList()

        var run = PipelineRun(projectId: project.id, requirement: requirement)
        run.projectName = project.name
        run.startedAt = Date()
        run.state = .decomposing
        run.addLog("파이프라인 시작", level: .info)
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

        // TODO 리스트 초기화 (완료된 항목 반영)
        initializeTodoList()
        for phase in run.completedPhases {
            completeTodo(phase: phase)
        }

        var resumeRun = run
        resumeRun.state = .decomposing  // 임시, 실제 Phase에서 변경됨
        resumeRun.addLog("파이프라인 재개 (Phase: \(run.resumePhase.name))", level: .info)
        currentRun = resumeRun
        updateAction("파이프라인 재개 중...")

        // 진행률 복원
        progress = Double(run.completedPhases.count) * 0.25

        await executePipelinePhases(run: &resumeRun, project: project, startPhase: run.resumePhase)
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
            updateAction(currentRun.isBuildSuccessful ? "완료!" : "실패")
            completeTodo(phase: .healing)

            // 리포트 생성
            generateReport(for: currentRun, projectName: project.name)

            // 파이프라인 저장
            savePipelineRun(currentRun)

        } catch {
            run.state = .failed
            run.completedAt = Date()
            run.addLog("오류: \(error.localizedDescription)", level: .error)
            currentRun = run
            updateAction("오류 발생: \(error.localizedDescription)")

            // 실패해도 리포트 생성
            generateReport(for: run, projectName: project.name)

            // 파이프라인 저장
            savePipelineRun(run)
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
    }

    /// 리포트 생성
    private func generateReport(for run: PipelineRun, projectName: String) {
        if let path = PipelineReportService.shared.generateAndSaveReport(for: run, projectName: projectName) {
            lastReportPath = path
            currentRun?.addLog("리포트 생성됨: \(path)", level: .info)
        }
    }

    /// 파이프라인 취소
    func cancelPipeline() {
        cancellationFlag = true
    }

    private func cancel() {
        guard var run = currentRun else { return }
        run.state = .paused  // 취소 대신 일시정지 (재개 가능)
        run.addLog("파이프라인 일시정지됨 (재개 가능)", level: .warning)
        savePipelineRun(run)  // 저장
        currentRun = run
        isRunning = false
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
        updateAction("프로젝트 정보 로드 중...")

        // PROJECT.md에서 ProjectInfo 로드
        let projectInfo = loadProjectInfo(for: project)
        updateAction("PROJECT.md 분석 완료")

        // 프로젝트 컨텍스트 읽기
        var projectContext = project.projectContext
        if let projectMdPath = getProjectMdPath(project: project) {
            if let content = try? String(contentsOfFile: projectMdPath, encoding: .utf8) {
                projectContext = content
            }
        }

        updateAction("AI에게 요구사항 분해 요청 중...")

        let autoApprove = companyStore?.company.settings.autoApproveAI ?? true
        let result = try await decomposer.decompose(
            requirement: run.requirement,
            projectInfo: projectInfo,
            projectContext: projectContext,
            autoApprove: autoApprove
        )

        run.decomposedTasks = result.tasks
        run.addLog("분해 완료: \(result.tasks.count)개 태스크", level: .success)
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
        updateAction("개발 태스크 준비 중...")

        let allEmployees = project.departments.flatMap { $0.employees }
        let projectInfo = loadProjectInfo(for: project)
        let totalTasks = run.decomposedTasks.count
        let autoApprove = companyStore?.company.settings.autoApproveAI ?? true

        run.decomposedTasks = try await executor.executeTasks(
            run.decomposedTasks,
            project: project,
            projectInfo: projectInfo,
            employees: allEmployees,
            autoApprove: autoApprove
        ) { [weak self] task, message in
            Task { @MainActor in
                guard let self = self else { return }
                self.currentRun?.addLog(message, level: .info)
                if let index = run.decomposedTasks.firstIndex(where: { $0.id == task.id }) {
                    self.currentTaskIndex = index + 1
                    self.currentTaskName = task.title
                    self.updateAction("[\(index + 1)/\(totalTasks)] \(task.title)")
                }
            }
        }

        let completedCount = run.decomposedTasks.filter { $0.status == .completed }.count
        let failedCount = run.decomposedTasks.filter { $0.status == .failed }.count

        run.addLog("코드 생성 완료: 성공 \(completedCount), 실패 \(failedCount)", level: completedCount > 0 ? .success : .warning)
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
        run.addLog("Phase 3: 빌드 시작", level: .info)
        currentRun = run

        startTodo(phase: .build)
        updateAction("프로젝트 경로 확인 중...")

        let projectInfo = loadProjectInfo(for: project)
        guard let projectPath = projectInfo?.absolutePath, !projectPath.isEmpty else {
            run.addLog("프로젝트 경로가 설정되지 않음", level: .error)
            updateAction("✗ 프로젝트 경로가 설정되지 않음")
            let attempt = BuildAttempt(
                success: false,
                exitCode: -1,
                output: "프로젝트 경로가 설정되지 않았습니다.",
                errors: [BuildError(message: "프로젝트 경로 없음", severity: .error)],
                startedAt: Date(),
                completedAt: Date()
            )
            run.buildAttempts.append(attempt)
            currentRun = run
            return run
        }

        updateAction("xcodebuild 실행 중... (시간이 걸릴 수 있습니다)")
        let attempt = try await buildService.build(projectPath: projectPath)
        run.buildAttempts.append(attempt)

        if attempt.success {
            run.addLog("빌드 성공!", level: .success)
            updateAction("✓ 빌드 성공!")
        } else {
            run.addLog("빌드 실패: \(attempt.errors.count)개 에러", level: .error)
            updateAction("✗ 빌드 실패: \(attempt.errors.count)개 에러")
            for error in attempt.errors.prefix(5) {
                run.addLog("  - \(error.message)", level: .error)
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
        run.addLog("Phase 4: Self-Healing 시작 (시도 \(run.healingAttempts))", level: .info)
        currentRun = run

        startTodo(phase: .healing)
        updateAction("빌드 에러 분석 중...")

        guard let lastAttempt = run.lastBuildAttempt else { return run }

        let projectInfo = loadProjectInfo(for: project)

        // 에러 수정 프롬프트 생성
        updateAction("에러 수정 프롬프트 생성 중...")
        let healingPrompt = await buildService.generateHealingPrompt(from: lastAttempt, projectInfo: projectInfo)

        // AI에게 수정 요청
        let claudeService = ClaudeCodeService()
        let systemPrompt = """
        당신은 시니어 개발자입니다. 빌드 에러를 분석하고 수정합니다.
        에러를 수정한 후 해당 파일을 직접 수정해주세요.
        """

        run.addLog("에러 분석 및 수정 요청 중...", level: .info)
        updateAction("AI에게 에러 수정 요청 중...")

        let autoApprove = companyStore?.company.settings.autoApproveAI ?? true
        let response = try await claudeService.sendMessage(healingPrompt, systemPrompt: systemPrompt, autoApprove: autoApprove)
        run.addLog("수정 완료, 재빌드 중...", level: .info)
        updateAction("수정 완료, 재빌드 시작...")

        // 재빌드
        if let projectPath = projectInfo?.absolutePath {
            var rebuildAttempt = try await buildService.build(projectPath: projectPath)
            rebuildAttempt.isHealingAttempt = true
            run.buildAttempts.append(rebuildAttempt)

            if rebuildAttempt.success {
                run.addLog("Self-Healing 성공! 빌드 통과", level: .success)
                updateAction("✓ Self-Healing 성공!")
            } else {
                run.addLog("Self-Healing 후에도 빌드 실패", level: .warning)
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

    /// PROJECT.md에서 ProjectInfo 로드
    private func loadProjectInfo(for project: Project) -> ProjectInfo? {
        guard let projectMdPath = getProjectMdPath(project: project),
              let content = try? String(contentsOfFile: projectMdPath, encoding: .utf8) else {
            return nil
        }
        return ProjectInfo.fromMarkdown(content)
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

    /// 특정 Phase TODO 완료
    func completeTodo(phase: PipelinePhase) {
        if let index = todoItems.firstIndex(where: { $0.phase == phase }) {
            todoItems[index].status = .completed
        }
    }

    /// 현재 작업 업데이트
    func updateAction(_ action: String) {
        currentAction = action
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
            return []
        }

        do {
            let runs = try JSONDecoder().decode([PipelineRun].self, from: data)
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
        } catch {
            print("[PipelineCoordinator] 파이프라인 저장 실패: \(error)")
        }
    }

    /// 프로젝트별 히스토리 조회
    func loadPipelineHistory(for projectId: UUID) -> [PipelineRun] {
        return loadPipelineHistory().filter { $0.projectId == projectId }
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
