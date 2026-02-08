import Foundation

/// 실행 모드
enum PipelineExecutionMode: String, CaseIterable {
    case full = "전체"           // 모든 도구 허용 (느리지만 정확)
    case lightweight = "경량"    // 제한된 도구 (빠르지만 제한적)
    case codeOnly = "코드만"     // 코드 생성만 (가장 빠름)

    var description: String {
        switch self {
        case .full: return "모든 도구 허용 - 파일 읽기/쓰기 가능 (느림, 토큰 많이 사용)"
        case .lightweight: return "제한된 도구 - 읽기만 가능 (중간)"
        case .codeOnly: return "코드 생성만 - 도구 없음 (빠름, 토큰 적게 사용)"
        }
    }
}

/// 분해된 태스크를 실행하는 엔진 (병렬 실행 지원)
actor PipelineExecutor {
    private let claudeService = ClaudeCodeService()

    /// 최대 동시 실행 태스크 수
    private let maxConcurrentTasks: Int

    /// 실행 모드
    private let executionMode: PipelineExecutionMode

    /// 태스크 실행 진행 상황 콜백
    typealias ProgressCallback = @Sendable (DecomposedTask, String) -> Void

    /// 토큰 사용량 콜백
    typealias TokenCallback = @Sendable (Int, Int, Double) -> Void  // (inputTokens, outputTokens, costUSD)

    /// 직원 상태 변경 콜백 (employeeId, employeeName, isWorking)
    typealias EmployeeStatusCallback = @Sendable (UUID, String, Bool) -> Void

    init(maxConcurrentTasks: Int = 3, executionMode: PipelineExecutionMode = .lightweight) {
        self.maxConcurrentTasks = maxConcurrentTasks
        self.executionMode = executionMode
    }

    /// 태스크 목록 실행 (병렬 실행 지원)
    /// - Parameters:
    ///   - tasks: 실행할 태스크 목록
    ///   - project: 프로젝트 정보
    ///   - projectInfo: 프로젝트 기술 정보
    ///   - employees: 프로젝트 직원들
    ///   - projectContext: 프로젝트 문서 컨텍스트 (PROJECT.md 등)
    ///   - autoApprove: AI 도구 자동 승인 여부
    ///   - onProgress: 진행 상황 콜백
    /// - Returns: 실행 완료된 태스크 목록
    func executeTasks(
        _ tasks: [DecomposedTask],
        project: Project,
        projectInfo: ProjectInfo?,
        employees: [ProjectEmployee],
        projectContext: String? = nil,
        autoApprove: Bool = true,
        onProgress: ProgressCallback? = nil,
        onTokenUsage: TokenCallback? = nil,
        onEmployeeStatus: EmployeeStatusCallback? = nil
    ) async throws -> [DecomposedTask] {
        // 태스크 상태를 추적할 actor
        let taskState = TaskStateManager(tasks: tasks)

        // 의존성 레벨별로 태스크 그룹화
        let levels = buildExecutionLevels(tasks)
        print("[PipelineExecutor] 실행 레벨: \(levels.count)개, 총 태스크: \(tasks.count)개")

        for (levelIndex, levelTasks) in levels.enumerated() {
            print("[PipelineExecutor] 레벨 \(levelIndex + 1)/\(levels.count): \(levelTasks.count)개 태스크 병렬 실행")

            // 이 레벨의 태스크들을 병렬로 실행
            await withTaskGroup(of: (UUID, TaskExecutionResult?, Error?).self) { group in
                for task in levelTasks {
                    group.addTask {
                        await self.executeTaskWithTracking(
                            task: task,
                            project: project,
                            projectInfo: projectInfo,
                            employees: employees,
                            projectContext: projectContext,
                            autoApprove: autoApprove,
                            taskState: taskState,
                            onProgress: onProgress,
                            onTokenUsage: onTokenUsage,
                            onEmployeeStatus: onEmployeeStatus
                        )
                    }
                }

                // 모든 태스크 완료 대기
                for await (taskId, result, error) in group {
                    await taskState.markCompleted(taskId, result: result, error: error)
                }
            }
        }

        return await taskState.getAllTasks()
    }

    /// 태스크 실행 및 추적
    private func executeTaskWithTracking(
        task: DecomposedTask,
        project: Project,
        projectInfo: ProjectInfo?,
        employees: [ProjectEmployee],
        projectContext: String?,
        autoApprove: Bool,
        taskState: TaskStateManager,
        onProgress: ProgressCallback?,
        onTokenUsage: TokenCallback?,
        onEmployeeStatus: EmployeeStatusCallback?
    ) async -> (UUID, TaskExecutionResult?, Error?) {
        // 태스크 시작 표시
        await taskState.markRunning(task.id)

        // 실행 모드에 따른 로그
        let modeDescription: String
        switch executionMode {
        case .full:
            modeDescription = "전체 모드 (모든 도구 허용)"
        case .lightweight:
            modeDescription = "경량 모드 (읽기 도구만)"
        case .codeOnly:
            modeDescription = "코드 생성 모드 (도구 없음)"
        }

        onProgress?(task, "🚀 태스크 시작: \(task.title)")
        onProgress?(task, "   📋 부서: \(task.department.rawValue), 우선순위: \(task.priority.rawValue)")
        onProgress?(task, "   ⚙️ 실행 모드: \(modeDescription)")

        // 적합한 직원 찾기
        onProgress?(task, "   🔍 담당 직원 검색 중...")
        let targetDept = (task.department == .general) ? DepartmentType.development : task.department
        let (employee, employeeWarning) = findEmployee(for: task.department, from: employees)

        if let warning = employeeWarning {
            onProgress?(task, warning)
        }

        // 직원이 없으면 실패
        guard let employee = employee else {
            let error = PipelineError.noEmployee(department: targetDept.rawValue)
            onProgress?(task, "❌ 실패: \(task.title) - 담당 직원 없음")
            return (task.id, nil, error)
        }

        onProgress?(task, "   👤 담당자: \(employee.name) (\(employee.departmentType.rawValue)팀)")

        // 직원 상태를 '작업 중'으로 변경
        onEmployeeStatus?(employee.id, employee.name, true)

        do {
            onProgress?(task, "   🤖 Claude Code 호출 중...")
            let startTime = Date()

            let result = try await executeTask(
                task,
                project: project,
                projectInfo: projectInfo,
                employee: employee,
                projectContext: projectContext,
                autoApprove: autoApprove
            )

            let elapsed = Date().timeIntervalSince(startTime)
            let elapsedStr = String(format: "%.1f", elapsed)

            // 토큰 사용량 콜백 호출
            if result.totalTokens > 0 {
                onTokenUsage?(result.inputTokens, result.outputTokens, result.costUSD)
            }

            // 상세 결과 로그
            onProgress?(task, "   ⏱️ 소요시간: \(elapsedStr)초")
            if result.totalTokens > 0 {
                onProgress?(task, "   📊 토큰: 입력 \(result.inputTokens) + 출력 \(result.outputTokens) = \(result.totalTokens)")
                onProgress?(task, "   💰 비용: $\(String(format: "%.4f", result.costUSD)) (\(result.model))")
            }
            if !result.createdFiles.isEmpty {
                onProgress?(task, "   📁 생성된 파일: \(result.createdFiles.joined(separator: ", "))")
            }
            if !result.modifiedFiles.isEmpty {
                onProgress?(task, "   ✏️ 수정된 파일: \(result.modifiedFiles.joined(separator: ", "))")
            }

            onProgress?(task, "✅ 완료: \(task.title)")

            // 직원 상태를 '휴식 중'으로 변경
            onEmployeeStatus?(employee.id, employee.name, false)

            return (task.id, result, nil)

        } catch {
            // 직원 상태를 '휴식 중'으로 변경 (실패/취소 시에도)
            onEmployeeStatus?(employee.id, employee.name, false)

            // 취소된 경우
            if case ClaudeCodeError.cancelled = error {
                onProgress?(task, "⏹️ 취소됨: \(task.title)")
            } else {
                onProgress?(task, "❌ 실패: \(task.title) - \(error.localizedDescription)")
            }
            return (task.id, nil, error)
        }
    }

    /// 의존성 기반으로 실행 레벨 생성 (같은 레벨은 병렬 실행 가능)
    private func buildExecutionLevels(_ tasks: [DecomposedTask]) -> [[DecomposedTask]] {
        var levels: [[DecomposedTask]] = []
        var remaining = Set(tasks.map { $0.id })
        var completed = Set<UUID>()
        let taskMap = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })

        while !remaining.isEmpty {
            // 현재 레벨에서 실행 가능한 태스크 찾기
            var currentLevel: [DecomposedTask] = []

            for taskId in remaining {
                guard let task = taskMap[taskId] else { continue }

                // 의존성이 모두 완료되었는지 확인
                let dependenciesMet = task.dependencies.allSatisfy { completed.contains($0) }
                if dependenciesMet {
                    currentLevel.append(task)
                }
            }

            // 실행 가능한 태스크가 없으면 순환 의존성 또는 오류
            if currentLevel.isEmpty && !remaining.isEmpty {
                print("[PipelineExecutor] 경고: 순환 의존성 감지, 남은 태스크 강제 실행")
                // 남은 태스크를 강제로 추가
                for taskId in remaining {
                    if let task = taskMap[taskId] {
                        currentLevel.append(task)
                    }
                }
            }

            // 현재 레벨 태스크들을 완료 처리
            for task in currentLevel {
                remaining.remove(task.id)
                completed.insert(task.id)
            }

            if !currentLevel.isEmpty {
                // order 순서대로 정렬
                levels.append(currentLevel.sorted { $0.order < $1.order })
            }
        }

        return levels
    }

    /// 단일 태스크 실행
    private func executeTask(
        _ task: DecomposedTask,
        project: Project,
        projectInfo: ProjectInfo?,
        employee: ProjectEmployee?,
        projectContext: String? = nil,
        autoApprove: Bool = true
    ) async throws -> TaskExecutionResult {
        let prompt = buildExecutionPrompt(
            task: task,
            project: project,
            projectInfo: projectInfo,
            projectContext: projectContext
        )
        let systemPrompt = buildSystemPrompt(task: task, employee: employee)

        // 실행 모드에 따라 허용 도구 결정
        let allowedTools: ClaudeCodeService.AllowedTools
        switch executionMode {
        case .full:
            allowedTools = autoApprove ? .all : .webOnly
        case .lightweight:
            allowedTools = .readOnly  // 읽기만 허용
        case .codeOnly:
            allowedTools = .none  // 도구 없음
        }

        // 토큰 사용량 추적을 위해 sendMessageWithTokens 사용
        let tokenResult = try await claudeService.sendMessageWithTokens(
            prompt,
            systemPrompt: systemPrompt,
            allowedTools: allowedTools
        )

        // 응답에서 파일 변경사항 추출
        let (createdFiles, modifiedFiles) = parseFileChanges(from: tokenResult.response)

        return TaskExecutionResult(
            response: tokenResult.response,
            createdFiles: createdFiles,
            modifiedFiles: modifiedFiles,
            inputTokens: tokenResult.inputTokens,
            outputTokens: tokenResult.outputTokens,
            cacheReadTokens: tokenResult.cacheReadInputTokens,
            cacheCreationTokens: tokenResult.cacheCreationInputTokens,
            costUSD: tokenResult.totalCostUSD,
            model: tokenResult.model
        )
    }

    /// 실행 프롬프트 생성
    private func buildExecutionPrompt(
        task: DecomposedTask,
        project: Project,
        projectInfo: ProjectInfo?,
        projectContext: String? = nil
    ) -> String {
        var prompt = """
        다음 태스크를 수행해주세요.

        ## 태스크
        **제목**: \(task.title)
        **설명**: \(task.description)
        **부서**: \(task.department.rawValue)
        **우선순위**: \(task.priority.rawValue)

        ## 프로젝트
        **이름**: \(project.name)
        """

        if let info = projectInfo {
            prompt += """

            **기술 스택**:
            - 언어: \(info.language)
            - 프레임워크: \(info.framework)
            - 빌드 도구: \(info.buildTool)

            **프로젝트 경로**: \(info.absolutePath)
            """
        }

        // 프로젝트 컨텍스트 추가 (PROJECT.md 등)
        if let context = projectContext, !context.isEmpty {
            prompt += """

            ## 프로젝트 컨텍스트 (PROJECT.md에서 가져옴)
            다음 정보를 참고하여 프로젝트의 코드 스타일과 구조를 따르세요:

            \(context)
            """
        }

        // 실행 모드에 따른 안내
        switch executionMode {
        case .full:
            prompt += """

            ## 요청사항
            1. 위 태스크를 완수하기 위한 코드를 작성해주세요
            2. 필요한 파일을 생성하거나 수정해주세요
            3. 각 변경사항에 대해 설명해주세요
            """
        case .lightweight:
            prompt += """

            ## 요청사항 (경량 모드)
            1. 프로젝트 컨텍스트를 참고하여 코드를 작성해주세요
            2. 읽기 도구만 사용 가능합니다 (파일 수정은 제안만 해주세요)
            3. 수정이 필요한 파일 경로와 변경 내용을 명확히 제시해주세요
            """
        case .codeOnly:
            prompt += """

            ## 요청사항 (코드 생성 모드)
            1. 주어진 컨텍스트만으로 코드를 작성해주세요
            2. 파일 탐색 도구를 사용하지 마세요
            3. 프로젝트 구조는 위 컨텍스트를 참고하세요
            4. 완성된 코드와 저장할 파일 경로를 제시해주세요
            """
        }

        return prompt
    }

    /// 시스템 프롬프트 생성
    private func buildSystemPrompt(task: DecomposedTask, employee: ProjectEmployee?) -> String {
        var prompt = task.department.expertRolePrompt

        prompt += """

        중요한 규칙:
        - 한국어로 응답합니다
        - 코드는 정확하고 실행 가능해야 합니다
        - 파일 변경시 전체 경로를 명시합니다
        - 에러 없이 빌드될 수 있도록 합니다
        """

        if let employee = employee {
            prompt = "당신의 이름은 \(employee.name)입니다.\n\n" + prompt
        }

        return prompt
    }

    /// 응답에서 파일 변경사항 파싱
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

    /// 부서에 맞는 직원 찾기
    private func findEmployee(for department: DepartmentType, from employees: [ProjectEmployee]) -> (employee: ProjectEmployee?, warning: String?) {
        let targetDepartment = (department == .general) ? .development : department

        // 해당 부서의 유휴 직원 우선
        if let idleEmployee = employees.first(where: { $0.departmentType == targetDepartment && $0.status == .idle }) {
            return (idleEmployee, nil)
        }
        // 해당 부서의 아무 직원
        if let deptEmployee = employees.first(where: { $0.departmentType == targetDepartment }) {
            return (deptEmployee, nil)
        }
        // 개발팀으로 대체
        if targetDepartment != .development {
            if let devEmployee = employees.first(where: { $0.departmentType == .development }) {
                return (devEmployee, "⚠️ \(targetDepartment.rawValue)팀에 직원이 없어 개발팀 \(devEmployee.name)이(가) 대신 작업합니다.")
            }
        }
        // 아무 직원이라도
        if let anyEmployee = employees.first {
            return (anyEmployee, "⚠️ \(targetDepartment.rawValue)팀에 직원이 없어 \(anyEmployee.departmentType.rawValue)팀 \(anyEmployee.name)이(가) 대신 작업합니다.")
        }
        return (nil, "❌ \(targetDepartment.rawValue)팀 작업을 수행할 직원이 없습니다.")
    }
}

// MARK: - Task State Manager

/// 태스크 상태를 스레드 안전하게 관리
actor TaskStateManager {
    private var tasks: [UUID: DecomposedTask]

    init(tasks: [DecomposedTask]) {
        self.tasks = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
    }

    func markRunning(_ taskId: UUID) {
        tasks[taskId]?.status = .running
        tasks[taskId]?.startedAt = Date()
    }

    func markCompleted(_ taskId: UUID, result: TaskExecutionResult?, error: Error?) {
        guard var task = tasks[taskId] else { return }

        task.completedAt = Date()

        if let result = result {
            task.status = .completed
            task.response = result.response
            task.createdFiles = result.createdFiles
            task.modifiedFiles = result.modifiedFiles
        } else if let error = error {
            task.status = .failed
            task.error = error.localizedDescription
        }

        tasks[taskId] = task
    }

    func getAllTasks() -> [DecomposedTask] {
        Array(tasks.values).sorted { $0.order < $1.order }
    }
}

// MARK: - Supporting Types

/// 태스크 실행 결과
struct TaskExecutionResult: Sendable {
    var response: String
    var createdFiles: [String]
    var modifiedFiles: [String]

    // 토큰 사용량
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheReadTokens: Int = 0
    var cacheCreationTokens: Int = 0
    var costUSD: Double = 0
    var model: String = "unknown"

    var totalTokens: Int {
        inputTokens + outputTokens
    }
}

/// 파이프라인 에러
enum PipelineError: LocalizedError {
    case noEmployee(department: String)
    case cancelled
    case dependencyFailed(taskId: UUID)

    var errorDescription: String? {
        switch self {
        case .noEmployee(let department):
            return "\(department)팀 직원이 없습니다. 직원을 고용해주세요."
        case .cancelled:
            return "작업이 취소되었습니다."
        case .dependencyFailed(let taskId):
            return "의존성 태스크(\(taskId))가 실패했습니다."
        }
    }
}
