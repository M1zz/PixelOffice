import Foundation
import SwiftUI
import Combine

/// Sub-agent 생성/관리/결과 수집을 담당하는 코디네이터
@MainActor
class SubAgentCoordinator: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var currentSession: OrchestratorSession?
    @Published var subAgents: [SubAgent] = []
    @Published var isRunning: Bool = false
    @Published var progress: Double = 0.0
    @Published var currentAction: String = ""
    
    /// 실시간 로그
    @Published var logs: [SubAgentLog] = []
    
    /// 토큰 사용량
    @Published var totalInputTokens: Int = 0
    @Published var totalOutputTokens: Int = 0
    @Published var totalCostUSD: Double = 0.0
    
    // MARK: - Private Properties
    
    private let claudeService = ClaudeCodeService()
    private let skillExecutor: SkillExecutor
    private let maxConcurrentAgents: Int
    private var cancellationFlag: Bool = false
    
    // MARK: - Init
    
    init(maxConcurrentAgents: Int = 3) {
        self.maxConcurrentAgents = maxConcurrentAgents
        self.skillExecutor = SkillExecutor()
    }
    
    // MARK: - Public Methods
    
    /// 요구사항을 분석하여 sub-agent들을 생성하고 실행
    func orchestrate(
        requirement: String,
        project: Project,
        projectInfo: ProjectInfo?,
        employees: [ProjectEmployee],
        autoApprove: Bool = true
    ) async throws -> OrchestratorSession {
        guard !isRunning else {
            throw SubAgentError.alreadyRunning
        }
        
        isRunning = true
        cancellationFlag = false
        progress = 0.0
        logs.removeAll()
        
        // 토큰 카운터 초기화
        totalInputTokens = 0
        totalOutputTokens = 0
        totalCostUSD = 0.0
        
        var session = OrchestratorSession(
            projectId: project.id,
            requirement: requirement
        )
        session.startedAt = Date()
        currentSession = session
        
        addLog("🎭 오케스트레이션 시작", level: .info)
        addLog("📋 요구사항: \(requirement.prefix(100))...", level: .debug)
        
        do {
            // Phase 1: 요구사항 분석 및 태스크 분해
            addLog("🧠 Phase 1: 요구사항 분석 중...", level: .info)
            currentAction = "요구사항 분석 중..."
            
            let tasks = try await decomposeRequirement(
                requirement: requirement,
                projectInfo: projectInfo,
                autoApprove: autoApprove
            )
            
            addLog("✅ \(tasks.count)개 태스크로 분해 완료", level: .success)
            progress = 0.2
            
            // Phase 2: Sub-agent 생성
            addLog("👥 Phase 2: Sub-agent 생성 중...", level: .info)
            currentAction = "Sub-agent 생성 중..."
            
            let agents = createSubAgents(from: tasks, employees: employees)
            subAgents = agents
            session.subAgents = agents
            currentSession = session
            
            addLog("✅ \(agents.count)개 Sub-agent 생성 완료", level: .success)
            progress = 0.3
            
            // Phase 3: 병렬 실행
            addLog("🚀 Phase 3: 병렬 실행 시작...", level: .info)
            currentAction = "태스크 실행 중..."
            
            let completedAgents = try await executeAgentsInParallel(
                agents: agents,
                projectInfo: projectInfo,
                autoApprove: autoApprove
            )
            
            subAgents = completedAgents
            session.subAgents = completedAgents
            progress = 0.9
            
            // Phase 4: 결과 수집
            addLog("📦 Phase 4: 결과 수집 중...", level: .info)
            currentAction = "결과 수집 중..."
            
            let aggregatedResult = aggregateResults(from: completedAgents)
            
            session.status = .completed
            session.completedAt = Date()
            currentSession = session
            
            progress = 1.0
            addLog("🎉 오케스트레이션 완료!", level: .success)
            addLog("   성공: \(session.successCount), 실패: \(session.failureCount)", level: .info)
            addLog("   총 토큰: \(totalInputTokens + totalOutputTokens), 비용: $\(String(format: "%.4f", totalCostUSD))", level: .info)
            
            isRunning = false
            return session
            
        } catch {
            session.status = .failed
            session.completedAt = Date()
            currentSession = session
            
            addLog("❌ 오케스트레이션 실패: \(error.localizedDescription)", level: .error)
            isRunning = false
            throw error
        }
    }
    
    /// 단일 sub-agent 실행
    func executeSubAgent(
        _ agent: SubAgent,
        projectInfo: ProjectInfo?,
        autoApprove: Bool = true
    ) async throws -> SubAgent {
        var agent = agent
        agent.status = .running
        agent.startedAt = Date()
        updateAgent(agent)
        
        addLog("▶️ [\(agent.name)] 시작: \(agent.task.title)", level: .info)
        
        do {
            // 스킬이 지정된 경우 스킬 실행
            if !agent.task.skillIds.isEmpty {
                let result = try await executeWithSkills(agent: agent, projectInfo: projectInfo, autoApprove: autoApprove)
                agent.result = result
            } else {
                // 일반 Claude Code 실행
                let result = try await executeWithClaudeCode(agent: agent, projectInfo: projectInfo, autoApprove: autoApprove)
                agent.result = result
            }
            
            agent.status = .completed
            agent.completedAt = Date()
            agent.progress = 1.0
            
            addLog("✅ [\(agent.name)] 완료", level: .success)
            
        } catch {
            agent.status = .failed
            agent.error = error.localizedDescription
            agent.completedAt = Date()
            
            addLog("❌ [\(agent.name)] 실패: \(error.localizedDescription)", level: .error)
        }
        
        updateAgent(agent)
        return agent
    }
    
    /// 실행 취소
    func cancel() {
        cancellationFlag = true
        addLog("⏹️ 취소 요청됨", level: .warning)
        
        // 실행 중인 모든 agent를 취소 상태로 변경
        for i in subAgents.indices {
            if subAgents[i].status == .running {
                subAgents[i].status = .cancelled
                subAgents[i].completedAt = Date()
            }
        }
        
        if var session = currentSession {
            session.status = .cancelled
            session.completedAt = Date()
            currentSession = session
        }
        
        isRunning = false
    }
    
    /// 특정 agent 일시정지
    func pauseAgent(_ agentId: UUID) {
        guard let index = subAgents.firstIndex(where: { $0.id == agentId }) else { return }
        if subAgents[index].status == .running {
            subAgents[index].status = .paused
            addLog("⏸️ [\(subAgents[index].name)] 일시정지", level: .warning)
        }
    }
    
    /// 특정 agent 재개
    func resumeAgent(_ agentId: UUID, projectInfo: ProjectInfo?, autoApprove: Bool = true) {
        guard let index = subAgents.firstIndex(where: { $0.id == agentId }),
              subAgents[index].status == .paused else { return }
        
        Task {
            let agent = subAgents[index]
            addLog("▶️ [\(agent.name)] 재개", level: .info)
            _ = try? await executeSubAgent(agent, projectInfo: projectInfo, autoApprove: autoApprove)
        }
    }
    
    // MARK: - Private Methods
    
    /// 요구사항을 태스크로 분해
    private func decomposeRequirement(
        requirement: String,
        projectInfo: ProjectInfo?,
        autoApprove: Bool
    ) async throws -> [SubAgentTask] {
        let prompt = """
        다음 요구사항을 독립적으로 실행 가능한 태스크들로 분해해주세요.
        
        요구사항:
        \(requirement)
        
        \(projectInfo != nil ? "프로젝트 정보: \(projectInfo!.language), \(projectInfo!.framework)" : "")
        
        각 태스크에 대해 다음 형식으로 응답해주세요:
        
        <<<TASK>>>
        title: 태스크 제목
        description: 상세 설명
        type: 태스크 유형 (codeGeneration, codeAnalysis, testing, documentation, refactoring, design, review, research)
        priority: 우선순위 (high, medium, low)
        skills: 필요한 스킬 (쉼표로 구분, 옵션)
        dependencies: 의존하는 태스크 번호 (쉼표로 구분, 옵션)
        <<<END_TASK>>>
        """
        
        let systemPrompt = "당신은 프로젝트 매니저입니다. 요구사항을 병렬 실행 가능한 태스크로 분해합니다."
        
        let response = try await claudeService.sendMessage(prompt, systemPrompt: systemPrompt, autoApprove: autoApprove)
        
        return parseTasksFromResponse(response)
    }
    
    /// 응답에서 태스크 파싱
    private func parseTasksFromResponse(_ response: String) -> [SubAgentTask] {
        var tasks: [SubAgentTask] = []
        
        let pattern = #"<<<TASK>>>([\s\S]*?)<<<END_TASK>>>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return tasks
        }
        
        let matches = regex.matches(in: response, options: [], range: NSRange(response.startIndex..., in: response))
        
        for match in matches {
            guard let range = Range(match.range(at: 1), in: response) else { continue }
            let content = String(response[range])
            
            var title = ""
            var description = ""
            var type: SubAgentTaskType = .custom
            var priority: TaskPriority = .medium
            var skillIds: [String] = []
            
            for line in content.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("title:") {
                    title = String(trimmed.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                } else if trimmed.hasPrefix("description:") {
                    description = String(trimmed.dropFirst(12)).trimmingCharacters(in: .whitespaces)
                } else if trimmed.hasPrefix("type:") {
                    let typeStr = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                    type = SubAgentTaskType(rawValue: typeStr) ?? parseTaskType(typeStr)
                } else if trimmed.hasPrefix("priority:") {
                    let priorityStr = String(trimmed.dropFirst(9)).trimmingCharacters(in: .whitespaces)
                    priority = TaskPriority(rawValue: priorityStr) ?? .medium
                } else if trimmed.hasPrefix("skills:") {
                    let skillsStr = String(trimmed.dropFirst(7)).trimmingCharacters(in: .whitespaces)
                    skillIds = skillsStr.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                }
            }
            
            if !title.isEmpty {
                tasks.append(SubAgentTask(
                    title: title,
                    description: description,
                    type: type,
                    priority: priority,
                    skillIds: skillIds
                ))
            }
        }
        
        return tasks
    }
    
    /// 태스크 타입 파싱 헬퍼
    private func parseTaskType(_ str: String) -> SubAgentTaskType {
        let lowercased = str.lowercased()
        if lowercased.contains("code") && lowercased.contains("gen") {
            return .codeGeneration
        } else if lowercased.contains("analysis") || lowercased.contains("분석") {
            return .codeAnalysis
        } else if lowercased.contains("test") {
            return .testing
        } else if lowercased.contains("doc") {
            return .documentation
        } else if lowercased.contains("refactor") {
            return .refactoring
        } else if lowercased.contains("design") {
            return .design
        } else if lowercased.contains("review") {
            return .review
        } else if lowercased.contains("research") {
            return .research
        }
        return .custom
    }
    
    /// 태스크에서 Sub-agent 생성
    private func createSubAgents(from tasks: [SubAgentTask], employees: [ProjectEmployee]) -> [SubAgent] {
        return tasks.enumerated().map { index, task in
            // 태스크 유형에 맞는 직원 찾기
            let employee = findSuitableEmployee(for: task, from: employees)
            
            return SubAgent(
                name: "Agent-\(index + 1)",
                task: task,
                assignedEmployeeId: employee?.id,
                assignedEmployeeName: employee?.name
            )
        }
    }
    
    /// 태스크에 적합한 직원 찾기
    private func findSuitableEmployee(for task: SubAgentTask, from employees: [ProjectEmployee]) -> ProjectEmployee? {
        let targetDepartment: DepartmentType
        
        switch task.type {
        case .codeGeneration, .codeAnalysis, .refactoring:
            targetDepartment = .development
        case .testing:
            targetDepartment = .qa
        case .documentation:
            targetDepartment = .planning
        case .design:
            targetDepartment = .design
        case .review, .research, .custom:
            targetDepartment = .development
        }
        
        // 해당 부서의 유휴 직원 우선
        if let idleEmployee = employees.first(where: { $0.departmentType == targetDepartment && $0.status == .idle }) {
            return idleEmployee
        }
        // 해당 부서의 아무 직원
        if let deptEmployee = employees.first(where: { $0.departmentType == targetDepartment }) {
            return deptEmployee
        }
        // 아무 직원
        return employees.first
    }
    
    /// 병렬 실행
    private func executeAgentsInParallel(
        agents: [SubAgent],
        projectInfo: ProjectInfo?,
        autoApprove: Bool
    ) async throws -> [SubAgent] {
        // 의존성 레벨별로 그룹화
        let levels = buildExecutionLevels(agents)
        var completedAgents: [UUID: SubAgent] = [:]
        
        for (levelIndex, levelAgents) in levels.enumerated() {
            addLog("📊 레벨 \(levelIndex + 1)/\(levels.count): \(levelAgents.count)개 agent 실행", level: .debug)
            
            // 이 레벨의 agent들을 병렬로 실행
            await withTaskGroup(of: SubAgent.self) { group in
                for agent in levelAgents {
                    if cancellationFlag { break }
                    
                    group.addTask {
                        do {
                            return try await self.executeSubAgent(agent, projectInfo: projectInfo, autoApprove: autoApprove)
                        } catch {
                            var failedAgent = agent
                            failedAgent.status = .failed
                            failedAgent.error = error.localizedDescription
                            return failedAgent
                        }
                    }
                }
                
                for await completedAgent in group {
                    completedAgents[completedAgent.id] = completedAgent
                    
                    // 진행률 업데이트
                    let completed = completedAgents.count
                    let total = agents.count
                    progress = 0.3 + (Double(completed) / Double(total)) * 0.6
                }
            }
        }
        
        // 원래 순서 유지하면서 결과 반환
        return agents.map { completedAgents[$0.id] ?? $0 }
    }
    
    /// 의존성 기반 실행 레벨 생성
    private func buildExecutionLevels(_ agents: [SubAgent]) -> [[SubAgent]] {
        var levels: [[SubAgent]] = []
        var remaining = Set(agents.map { $0.id })
        var completed = Set<UUID>()
        let agentMap = Dictionary(uniqueKeysWithValues: agents.map { ($0.id, $0) })
        
        while !remaining.isEmpty {
            var currentLevel: [SubAgent] = []
            
            for agentId in remaining {
                guard let agent = agentMap[agentId] else { continue }
                
                // 의존성이 모두 완료되었는지 확인
                let dependenciesMet = agent.dependencies.allSatisfy { completed.contains($0) }
                if dependenciesMet {
                    currentLevel.append(agent)
                }
            }
            
            // 순환 의존성 방지
            if currentLevel.isEmpty && !remaining.isEmpty {
                for agentId in remaining {
                    if let agent = agentMap[agentId] {
                        currentLevel.append(agent)
                    }
                }
            }
            
            for agent in currentLevel {
                remaining.remove(agent.id)
                completed.insert(agent.id)
            }
            
            if !currentLevel.isEmpty {
                levels.append(currentLevel)
            }
        }
        
        return levels
    }
    
    /// 스킬을 사용한 실행
    private func executeWithSkills(
        agent: SubAgent,
        projectInfo: ProjectInfo?,
        autoApprove: Bool
    ) async throws -> SubAgentResult {
        var artifacts: [SubAgentArtifact] = []
        var output = ""
        
        for skillId in agent.task.skillIds {
            let context = SkillContext(
                projectPath: projectInfo?.absolutePath,
                projectInfo: projectInfo,
                additionalContext: agent.task.context
            )
            
            let request = SkillExecutionRequest(
                skillId: skillId,
                input: ["input": AnyCodable(agent.task.description)],
                context: context,
                options: SkillExecutionOptions(autoApprove: autoApprove)
            )
            
            let result = try await skillExecutor.execute(request)
            
            // 토큰 사용량 업데이트
            addTokenUsage(
                input: result.metrics.inputTokens,
                output: result.metrics.outputTokens,
                cost: result.metrics.costUSD
            )
            
            artifacts.append(contentsOf: result.artifacts)
            
            if let outputValue = result.output?["result"]?.value as? String {
                output += outputValue + "\n"
            }
        }
        
        return SubAgentResult(
            output: output,
            artifacts: artifacts,
            summary: "스킬 실행 완료: \(agent.task.skillIds.joined(separator: ", "))"
        )
    }
    
    /// Claude Code를 사용한 실행
    private func executeWithClaudeCode(
        agent: SubAgent,
        projectInfo: ProjectInfo?,
        autoApprove: Bool
    ) async throws -> SubAgentResult {
        let prompt = buildExecutionPrompt(for: agent, projectInfo: projectInfo)
        let systemPrompt = buildSystemPrompt(for: agent)
        
        let tokenResult = try await claudeService.sendMessageWithTokens(
            prompt,
            systemPrompt: systemPrompt,
            allowedTools: autoApprove ? .all : .readOnly,
            workingDirectory: projectInfo?.absolutePath
        )
        
        // 토큰 사용량 업데이트
        addTokenUsage(
            input: tokenResult.inputTokens,
            output: tokenResult.outputTokens,
            cost: tokenResult.totalCostUSD
        )
        
        // 파일 변경사항 추출
        let (createdFiles, modifiedFiles) = parseFileChanges(from: tokenResult.response)
        
        return SubAgentResult(
            output: tokenResult.response,
            createdFiles: createdFiles,
            modifiedFiles: modifiedFiles,
            summary: "태스크 실행 완료"
        )
    }
    
    /// 실행 프롬프트 생성
    private func buildExecutionPrompt(for agent: SubAgent, projectInfo: ProjectInfo?) -> String {
        var prompt = """
        다음 태스크를 수행해주세요.
        
        ## 태스크
        **제목**: \(agent.task.title)
        **설명**: \(agent.task.description)
        **유형**: \(agent.task.type.rawValue)
        **우선순위**: \(agent.task.priority.rawValue)
        """
        
        if let info = projectInfo {
            prompt += """
            
            ## 프로젝트 정보
            - 언어: \(info.language)
            - 프레임워크: \(info.framework)
            - 경로: \(info.absolutePath)
            """
        }
        
        if let context = agent.task.context {
            prompt += "\n\n## 추가 컨텍스트\n\(context)"
        }
        
        return prompt
    }
    
    /// 시스템 프롬프트 생성
    private func buildSystemPrompt(for agent: SubAgent) -> String {
        var prompt = "당신은 "
        
        switch agent.task.type {
        case .codeGeneration:
            prompt += "시니어 소프트웨어 개발자입니다. 깔끔하고 효율적인 코드를 작성합니다."
        case .codeAnalysis:
            prompt += "코드 분석 전문가입니다. 코드 구조와 품질을 분석합니다."
        case .testing:
            prompt += "QA 엔지니어입니다. 철저한 테스트 코드를 작성합니다."
        case .documentation:
            prompt += "기술 문서 작성자입니다. 명확하고 이해하기 쉬운 문서를 작성합니다."
        case .refactoring:
            prompt += "리팩토링 전문가입니다. 코드 품질을 개선합니다."
        case .design:
            prompt += "UI/UX 디자이너입니다. 사용자 중심의 디자인을 제안합니다."
        case .review:
            prompt += "코드 리뷰어입니다. 코드 품질과 잠재적 문제를 검토합니다."
        case .research:
            prompt += "기술 리서처입니다. 최신 기술과 솔루션을 조사합니다."
        case .custom:
            prompt += "전문가입니다. 주어진 태스크를 완수합니다."
        }
        
        if let employeeName = agent.assignedEmployeeName {
            prompt = "당신의 이름은 \(employeeName)입니다. " + prompt
        }
        
        return prompt
    }
    
    /// 파일 변경사항 파싱
    private func parseFileChanges(from response: String) -> (created: [String], modified: [String]) {
        var created: [String] = []
        var modified: [String] = []
        
        let lines = response.components(separatedBy: "\n")
        for line in lines {
            let lowercased = line.lowercased()
            if lowercased.contains("created") || lowercased.contains("생성") {
                if let path = extractPath(from: line) {
                    created.append(path)
                }
            } else if lowercased.contains("modified") || lowercased.contains("수정") {
                if let path = extractPath(from: line) {
                    modified.append(path)
                }
            }
        }
        
        return (created, modified)
    }
    
    /// 경로 추출
    private func extractPath(from line: String) -> String? {
        if let start = line.firstIndex(of: "`"), let end = line.lastIndex(of: "`"), start < end {
            let path = String(line[line.index(after: start)..<end])
            if path.contains("/") || path.contains(".") {
                return path
            }
        }
        return nil
    }
    
    /// 결과 수집
    private func aggregateResults(from agents: [SubAgent]) -> SubAgentResult {
        var combinedOutput = ""
        var allArtifacts: [SubAgentArtifact] = []
        var allCreatedFiles: [String] = []
        var allModifiedFiles: [String] = []
        
        for agent in agents where agent.status == .completed {
            if let result = agent.result {
                combinedOutput += "### \(agent.name): \(agent.task.title)\n"
                combinedOutput += result.output + "\n\n"
                allArtifacts.append(contentsOf: result.artifacts)
                allCreatedFiles.append(contentsOf: result.createdFiles)
                allModifiedFiles.append(contentsOf: result.modifiedFiles)
            }
        }
        
        return SubAgentResult(
            output: combinedOutput,
            artifacts: allArtifacts,
            createdFiles: allCreatedFiles,
            modifiedFiles: allModifiedFiles,
            summary: "총 \(agents.filter { $0.status == .completed }.count)개 태스크 완료"
        )
    }
    
    /// Agent 업데이트
    private func updateAgent(_ agent: SubAgent) {
        if let index = subAgents.firstIndex(where: { $0.id == agent.id }) {
            subAgents[index] = agent
        }
        
        if var session = currentSession {
            if let index = session.subAgents.firstIndex(where: { $0.id == agent.id }) {
                session.subAgents[index] = agent
                currentSession = session
            }
        }
    }
    
    /// 토큰 사용량 추가
    private func addTokenUsage(input: Int, output: Int, cost: Double) {
        totalInputTokens += input
        totalOutputTokens += output
        totalCostUSD += cost
    }
    
    /// 로그 추가
    private func addLog(_ message: String, level: SubAgentLogLevel) {
        logs.append(SubAgentLog(message: message, level: level))
    }
}

// MARK: - Supporting Types

/// Sub-agent 로그
struct SubAgentLog: Identifiable {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var message: String
    var level: SubAgentLogLevel
}

/// 로그 레벨
enum SubAgentLogLevel: String {
    case debug = "debug"
    case info = "info"
    case success = "success"
    case warning = "warning"
    case error = "error"
    
    var color: Color {
        switch self {
        case .debug: return .secondary
        case .info: return .primary
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .debug: return "ant"
        case .info: return "info.circle"
        case .success: return "checkmark.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        }
    }
}

/// Sub-agent 에러
enum SubAgentError: LocalizedError {
    case alreadyRunning
    case noAgents
    case cancelled
    case dependencyFailed(UUID)
    
    var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            return "이미 실행 중입니다."
        case .noAgents:
            return "실행할 Sub-agent가 없습니다."
        case .cancelled:
            return "작업이 취소되었습니다."
        case .dependencyFailed(let id):
            return "의존성 태스크(\(id))가 실패했습니다."
        }
    }
}
