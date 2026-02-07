import Foundation

/// 분해된 태스크를 실행하는 엔진
actor PipelineExecutor {
    private let claudeService = ClaudeCodeService()

    /// 태스크 실행 진행 상황 콜백
    typealias ProgressCallback = (DecomposedTask, String) -> Void

    /// 태스크 목록 실행
    /// - Parameters:
    ///   - tasks: 실행할 태스크 목록
    ///   - project: 프로젝트 정보
    ///   - projectInfo: 프로젝트 기술 정보
    ///   - employees: 프로젝트 직원들
    ///   - autoApprove: AI 도구 자동 승인 여부
    ///   - onProgress: 진행 상황 콜백
    /// - Returns: 실행 완료된 태스크 목록
    func executeTasks(
        _ tasks: [DecomposedTask],
        project: Project,
        projectInfo: ProjectInfo?,
        employees: [ProjectEmployee],
        autoApprove: Bool = true,
        onProgress: ProgressCallback? = nil
    ) async throws -> [DecomposedTask] {
        var executedTasks = tasks
        var completedTaskIds: Set<UUID> = []

        // 의존성 순서대로 정렬
        let sortedTasks = topologicalSort(tasks)

        for task in sortedTasks {
            guard let index = executedTasks.firstIndex(where: { $0.id == task.id }) else {
                continue
            }

            // 의존성 확인
            guard task.canExecute(completedTaskIds: completedTaskIds) else {
                print("[PipelineExecutor] Task \(task.title) cannot execute - dependencies not met")
                continue
            }

            // 태스크 시작
            executedTasks[index].status = .running
            executedTasks[index].startedAt = Date()

            onProgress?(executedTasks[index], "실행 시작: \(task.title)")

            do {
                // 적합한 직원 찾기
                let employee = findEmployee(for: task.department, from: employees)
                executedTasks[index].assignedEmployeeId = employee?.id

                // 태스크 실행
                let result = try await executeTask(
                    task,
                    project: project,
                    projectInfo: projectInfo,
                    employee: employee,
                    autoApprove: autoApprove
                )

                executedTasks[index].status = .completed
                executedTasks[index].completedAt = Date()
                executedTasks[index].response = result.response
                executedTasks[index].createdFiles = result.createdFiles
                executedTasks[index].modifiedFiles = result.modifiedFiles

                completedTaskIds.insert(task.id)

                onProgress?(executedTasks[index], "완료: \(task.title)")

            } catch {
                executedTasks[index].status = .failed
                executedTasks[index].completedAt = Date()
                executedTasks[index].error = error.localizedDescription

                onProgress?(executedTasks[index], "실패: \(task.title) - \(error.localizedDescription)")
            }
        }

        return executedTasks
    }

    /// 단일 태스크 실행
    private func executeTask(
        _ task: DecomposedTask,
        project: Project,
        projectInfo: ProjectInfo?,
        employee: ProjectEmployee?,
        autoApprove: Bool = true
    ) async throws -> TaskExecutionResult {
        let prompt = buildExecutionPrompt(task: task, project: project, projectInfo: projectInfo)
        let systemPrompt = buildSystemPrompt(task: task, employee: employee)

        let response = try await claudeService.sendMessage(
            prompt,
            systemPrompt: systemPrompt,
            autoApprove: autoApprove
        )

        // 응답에서 파일 변경사항 추출
        let (createdFiles, modifiedFiles) = parseFileChanges(from: response)

        return TaskExecutionResult(
            response: response,
            createdFiles: createdFiles,
            modifiedFiles: modifiedFiles
        )
    }

    /// 실행 프롬프트 생성
    private func buildExecutionPrompt(task: DecomposedTask, project: Project, projectInfo: ProjectInfo?) -> String {
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

        prompt += """

        ## 요청사항
        1. 위 태스크를 완수하기 위한 코드를 작성해주세요
        2. 필요한 파일을 생성하거나 수정해주세요
        3. 각 변경사항에 대해 설명해주세요
        """

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

        // 간단한 패턴 매칭 (실제로는 Claude가 구조화된 응답을 줄 것으로 예상)
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
        // 백틱 사이의 경로 추출
        if let start = line.firstIndex(of: "`"), let end = line.lastIndex(of: "`"), start < end {
            let path = String(line[line.index(after: start)..<end])
            if path.contains("/") || path.contains(".") {
                return path
            }
        }
        return nil
    }

    /// 부서에 맞는 직원 찾기
    private func findEmployee(for department: DepartmentType, from employees: [ProjectEmployee]) -> ProjectEmployee? {
        // 해당 부서의 유휴 직원 우선
        if let idleEmployee = employees.first(where: { $0.departmentType == department && $0.status == .idle }) {
            return idleEmployee
        }
        // 해당 부서의 아무 직원
        if let deptEmployee = employees.first(where: { $0.departmentType == department }) {
            return deptEmployee
        }
        // 없으면 아무 개발자
        return employees.first(where: { $0.departmentType == .development })
    }

    /// 위상 정렬 (의존성 순서대로 정렬)
    private func topologicalSort(_ tasks: [DecomposedTask]) -> [DecomposedTask] {
        var result: [DecomposedTask] = []
        var visited: Set<UUID> = []
        var taskMap: [UUID: DecomposedTask] = [:]

        for task in tasks {
            taskMap[task.id] = task
        }

        func visit(_ task: DecomposedTask) {
            guard !visited.contains(task.id) else { return }
            visited.insert(task.id)

            for depId in task.dependencies {
                if let depTask = taskMap[depId] {
                    visit(depTask)
                }
            }

            result.append(task)
        }

        // order 순서대로 방문
        for task in tasks.sorted(by: { $0.order < $1.order }) {
            visit(task)
        }

        return result
    }
}

/// 태스크 실행 결과
struct TaskExecutionResult {
    var response: String
    var createdFiles: [String]
    var modifiedFiles: [String]
}
