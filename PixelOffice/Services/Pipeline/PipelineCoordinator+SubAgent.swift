import Foundation
import SwiftUI

// MARK: - Sub-Agent Mode Integration

extension PipelineCoordinator {
    
    /// Sub-Agent 모드 실행 여부 결정
    /// 복잡한 요구사항일 때 자동으로 Sub-Agent 모드로 전환
    func shouldUseSubAgentMode(requirement: String, taskCount: Int) -> Bool {
        // 조건 1: 태스크 수가 5개 이상
        if taskCount >= 5 {
            return true
        }
        
        // 조건 2: 요구사항이 길고 복잡함 (500자 이상이고 여러 항목 포함)
        let hasMultipleItems = requirement.contains("\n-") || requirement.contains("\n*") || requirement.contains("\n1.")
        if requirement.count > 500 && hasMultipleItems {
            return true
        }
        
        // 조건 3: 명시적 키워드 포함
        let subAgentKeywords = ["병렬", "parallel", "동시에", "함께", "여러 팀", "모든 팀"]
        if subAgentKeywords.contains(where: { requirement.localizedCaseInsensitiveContains($0) }) {
            return true
        }
        
        return false
    }
    
    /// Sub-Agent 모드로 파이프라인 실행
    /// - Parameters:
    ///   - requirement: 요구사항
    ///   - project: 대상 프로젝트
    ///   - sprint: 스프린트 (옵션)
    func startPipelineWithSubAgents(
        requirement: String,
        project: Project,
        sprint: Sprint? = nil
    ) async {
        guard !isRunning else {
            print("[PipelineCoordinator] Pipeline already running")
            return
        }
        
        // 프로젝트 경로 확인
        let projectInfo = loadProjectInfo(for: project)
        if projectInfo == nil || projectInfo?.absolutePath.isEmpty == true {
            let errorMessage = buildProjectPathErrorMessage(project: project, projectInfo: projectInfo)
            showNotification(errorMessage, type: .error)
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
        
        run.addLog("🎭 Sub-Agent 모드로 파이프라인 시작", level: .info)
        if let sprint = sprint {
            run.addLog("   스프린트: \(sprint.name)", level: .info)
        }
        
        currentRun = run
        updateAction("Sub-Agent 오케스트레이션 초기화 중...")
        
        // 초기 상태 저장
        saveRunProgress(run)
        
        // Sub-Agent Coordinator 생성 및 실행
        let subAgentCoordinator = SubAgentCoordinator(maxConcurrentAgents: 3)
        let allEmployees = project.departments.flatMap { $0.employees }
        let autoApprove = companyStore?.company.settings.autoApproveAI ?? true
        
        do {
            run.addLog("📋 오케스트레이션 시작...", level: .info)
            updateAction("요구사항 분석 및 태스크 분해 중...")
            
            // 토큰 사용량 연동을 위한 관찰
            let tokenObserver = Task { @MainActor in
                for await _ in Timer.publish(every: 1, on: .main, in: .common).autoconnect().values {
                    if !self.isRunning { break }
                    self.totalInputTokens = subAgentCoordinator.totalInputTokens
                    self.totalOutputTokens = subAgentCoordinator.totalOutputTokens
                    self.totalCostUSD = subAgentCoordinator.totalCostUSD
                    self.progress = subAgentCoordinator.progress
                    self.currentAction = subAgentCoordinator.currentAction
                }
            }
            
            let session = try await subAgentCoordinator.orchestrate(
                requirement: requirement,
                project: project,
                projectInfo: projectInfo,
                employees: allEmployees,
                autoApprove: autoApprove
            )
            
            tokenObserver.cancel()
            
            // 결과 처리
            run.addLog("✅ 오케스트레이션 완료", level: .success)
            run.addLog("   성공: \(session.successCount), 실패: \(session.failureCount)", level: .info)
            run.addLog("   총 토큰: \(session.totalTokens), 비용: $\(String(format: "%.4f", session.totalCostUSD))", level: .info)
            
            // Sub-Agent 결과를 DecomposedTask로 변환
            run.decomposedTasks = session.subAgents.map { agent in
                var task = DecomposedTask(
                    id: agent.id,
                    title: agent.task.title,
                    description: agent.task.description,
                    department: mapTaskTypeToDepartment(agent.task.type),
                    priority: agent.task.priority,
                    order: 0
                )
                
                task.status = mapSubAgentStatus(agent.status)
                task.response = agent.result?.output ?? ""
                task.error = agent.error
                task.createdFiles = agent.result?.createdFiles ?? []
                task.modifiedFiles = agent.result?.modifiedFiles ?? []
                
                return task
            }
            
            // Phase 완료 표시
            run.markPhaseCompleted(.decomposition)
            run.markPhaseCompleted(.development)
            completeTodo(phase: .decomposition)
            completeTodo(phase: .development)
            
            // 빌드 Phase
            run = try await executeBuildPhaseInternal(run: run, project: project)
            run.markPhaseCompleted(.build)
            completeTodo(phase: .build)
            
            // Self-Healing (필요시)
            if !run.isBuildSuccessful && run.canHeal {
                run = try await executeHealingPhaseInternal(run: run, project: project)
                run.markPhaseCompleted(.healing)
            }
            completeTodo(phase: .healing)
            
            // 완료 처리
            run.state = run.isBuildSuccessful ? .completed : .failed
            run.completedAt = Date()
            currentRun = run
            progress = 1.0
            
            // 리포트 생성
            generateReportInternal(for: run, projectName: project.name)
            
            // 저장
            savePipelineRun(run)
            
            // 알림
            if run.isBuildSuccessful {
                showNotification("Sub-Agent 파이프라인이 성공적으로 완료되었습니다!", type: .success)
                syncCompletedTasksToKanbanInternal(run: run, project: project)
            } else {
                showNotification("Sub-Agent 파이프라인이 실패했습니다.", type: .error)
            }
            
        } catch {
            run.state = .failed
            run.completedAt = Date()
            run.addLog("❌ 오케스트레이션 실패: \(error.localizedDescription)", level: .error)
            currentRun = run
            
            savePipelineRun(run)
            showNotification("Sub-Agent 파이프라인 오류: \(error.localizedDescription)", type: .error)
        }
        
        isRunning = false
    }
    
    // MARK: - Helper Methods
    
    /// SubAgentTaskType을 DepartmentType으로 매핑
    private func mapTaskTypeToDepartment(_ type: SubAgentTaskType) -> DepartmentType {
        switch type {
        case .codeGeneration, .codeAnalysis, .refactoring:
            return .development
        case .testing:
            return .qa
        case .documentation, .research:
            return .planning
        case .design:
            return .design
        case .review, .custom:
            return .development
        }
    }
    
    /// SubAgentStatus를 DecomposedTaskStatus로 매핑
    private func mapSubAgentStatus(_ status: SubAgentStatus) -> DecomposedTaskStatus {
        switch status {
        case .idle:
            return .pending
        case .running:
            return .running
        case .completed:
            return .completed
        case .failed:
            return .failed
        case .paused:
            return .pending
        case .cancelled:
            return .failed
        }
    }
    
    /// 내부 빌드 Phase 실행 (private 접근용)
    private func executeBuildPhaseInternal(run: PipelineRun, project: Project) async throws -> PipelineRun {
        var run = run
        run.currentPhase = .build
        run.state = .building
        currentPhaseDescription = "빌드 중..."
        run.addLog("🔨 Phase 3: 빌드 시작", level: .info)
        currentRun = run
        
        startTodo(phase: .build)
        updateAction("빌드 중...")
        
        let projectInfo = loadProjectInfo(for: project)
        guard let projectPath = projectInfo?.absolutePath, !projectPath.isEmpty else {
            let attempt = BuildAttempt(
                success: false,
                exitCode: -1,
                output: "프로젝트 경로가 설정되지 않았습니다.",
                errors: [BuildError(message: "프로젝트 경로 없음", severity: .error)],
                startedAt: Date(),
                completedAt: Date()
            )
            run.buildAttempts.append(attempt)
            return run
        }
        
        let buildService = BuildService()
        let attempt = try await buildService.build(projectPath: projectPath)
        run.buildAttempts.append(attempt)
        
        if attempt.success {
            run.addLog("✅ 빌드 성공!", level: .success)
        } else {
            run.addLog("❌ 빌드 실패: \(attempt.errors.count)개 에러", level: .error)
        }
        
        progress = 0.85
        currentRun = run
        return run
    }
    
    /// 내부 Self-Healing Phase 실행 (private 접근용)
    private func executeHealingPhaseInternal(run: PipelineRun, project: Project) async throws -> PipelineRun {
        var run = run
        run.currentPhase = .healing
        run.state = .healing
        run.healingAttempts += 1
        currentPhaseDescription = "Self-Healing 시도 중..."
        run.addLog("🩹 Phase 4: Self-Healing 시작", level: .info)
        currentRun = run
        
        startTodo(phase: .healing)
        updateAction("빌드 에러 수정 중...")
        
        guard let lastAttempt = run.lastBuildAttempt else { return run }
        
        let projectInfo = loadProjectInfo(for: project)
        let buildService = BuildService()
        let claudeService = ClaudeCodeService()
        
        let healingPrompt = await buildService.generateHealingPrompt(from: lastAttempt, projectInfo: projectInfo)
        let systemPrompt = "당신은 시니어 개발자입니다. 빌드 에러를 분석하고 수정합니다."
        
        let autoApprove = companyStore?.company.settings.autoApproveAI ?? true
        _ = try await claudeService.sendMessage(healingPrompt, systemPrompt: systemPrompt, autoApprove: autoApprove)
        
        // 재빌드
        if let projectPath = projectInfo?.absolutePath {
            var rebuildAttempt = try await buildService.build(projectPath: projectPath)
            rebuildAttempt.isHealingAttempt = true
            run.buildAttempts.append(rebuildAttempt)
            
            if rebuildAttempt.success {
                run.addLog("✅ Self-Healing 성공!", level: .success)
            } else {
                run.addLog("❌ Self-Healing 후에도 빌드 실패", level: .warning)
            }
        }
        
        progress = 0.95
        currentRun = run
        return run
    }
    
    /// 내부 리포트 생성 (private 접근용)
    private func generateReportInternal(for run: PipelineRun, projectName: String) {
        if let path = PipelineReportService.shared.generateAndSaveReport(for: run, projectName: projectName) {
            lastReportPath = path
        }
    }
    
    /// 내부 칸반 동기화 (private 접근용)
    private func syncCompletedTasksToKanbanInternal(run: PipelineRun, project: Project) {
        guard let companyStore = companyStore else { return }
        
        for task in run.decomposedTasks where task.status == .completed {
            if let projectTask = project.tasks.first(where: { $0.id == task.id || $0.decomposedTaskId == task.id }) {
                var updatedTask = projectTask
                updatedTask.status = .done
                updatedTask.completedAt = Date()
                updatedTask.pipelineRunId = run.id
                companyStore.updateTask(updatedTask, inProject: project.id)
            }
        }
    }
}

// MARK: - Project Info Helper (for extension access)

extension PipelineCoordinator {
    /// loadProjectInfo를 extension에서 접근 가능하게
    func loadProjectInfoPublic(for project: Project) -> ProjectInfo? {
        return loadProjectInfo(for: project)
    }
    
    /// buildProjectPathErrorMessage를 extension에서 접근 가능하게
    func buildProjectPathErrorMessagePublic(project: Project, projectInfo: ProjectInfo?) -> String {
        return buildProjectPathErrorMessage(project: project, projectInfo: projectInfo)
    }
}
