import Foundation

/// 파이프라인과 칸반 보드 양방향 동기화 서비스
class PipelineKanbanService {
    static let shared = PipelineKanbanService()
    
    private init() {}
    
    // MARK: - Public API
    
    /// 분해된 태스크들을 칸반에 동기화
    /// - Parameters:
    ///   - run: 파이프라인 실행 정보
    ///   - project: 프로젝트
    ///   - companyStore: CompanyStore 참조
    /// - Returns: 동기화된 태스크 수
    @MainActor
    @discardableResult
    func syncTasksToKanban(run: PipelineRun, project: Project, companyStore: CompanyStore) -> SyncResult {
        var result = SyncResult()
        
        for decomposedTask in run.decomposedTasks {
            // 이미 칸반에 있는 태스크인지 확인 (decomposedTaskId로)
            let existingTask = findExistingTask(decomposedTaskId: decomposedTask.id, in: project)
            
            if let existing = existingTask {
                // 기존 태스크 업데이트
                let updated = updateExistingTask(
                    existing,
                    with: decomposedTask,
                    pipelineRunId: run.id,
                    project: project,
                    companyStore: companyStore
                )
                if updated {
                    result.updated += 1
                }
            } else {
                // 새 태스크 생성
                let created = createNewTask(
                    from: decomposedTask,
                    pipelineRunId: run.id,
                    sprintId: run.sprintId,
                    project: project,
                    companyStore: companyStore
                )
                if created {
                    result.created += 1
                }
            }
        }
        
        print("[PipelineKanbanService] 동기화 완료 - 생성: \(result.created), 업데이트: \(result.updated)")
        return result
    }
    
    /// 태스크 상태 변경 시 칸반 동기화
    /// - Parameters:
    ///   - decomposedTask: 분해된 태스크
    ///   - pipelineRunId: 파이프라인 실행 ID
    ///   - project: 프로젝트
    ///   - companyStore: CompanyStore 참조
    @MainActor
    func syncTaskStatus(
        decomposedTask: DecomposedTask,
        pipelineRunId: UUID,
        project: Project,
        companyStore: CompanyStore
    ) {
        guard let existingTask = findExistingTask(decomposedTaskId: decomposedTask.id, in: project) else {
            // 태스크가 없으면 새로 생성
            _ = createNewTask(
                from: decomposedTask,
                pipelineRunId: pipelineRunId,
                sprintId: nil,
                project: project,
                companyStore: companyStore
            )
            return
        }
        
        // 상태 매핑
        let newStatus = mapDecomposedStatusToTaskStatus(decomposedTask.status)
        
        // 상태가 변경되었으면 업데이트
        if existingTask.status != newStatus {
            var updatedTask = existingTask
            updatedTask.status = newStatus
            updatedTask.lastPipelineStatus = decomposedTask.status.rawValue
            updatedTask.updatedAt = Date()
            
            if newStatus == .done {
                updatedTask.completedAt = Date()
            }
            
            companyStore.updateTask(updatedTask, inProject: project.id)
            print("[PipelineKanbanService] 태스크 상태 업데이트: \(existingTask.title) -> \(newStatus.rawValue)")
        }
    }
    
    /// 파이프라인 완료/실패 시 최종 동기화
    /// - Parameters:
    ///   - run: 파이프라인 실행 정보
    ///   - project: 프로젝트
    ///   - companyStore: CompanyStore 참조
    @MainActor
    func syncFinalStatus(run: PipelineRun, project: Project, companyStore: CompanyStore) {
        for decomposedTask in run.decomposedTasks {
            guard let existingTask = findExistingTask(decomposedTaskId: decomposedTask.id, in: project) else {
                continue
            }
            
            var updatedTask = existingTask
            updatedTask.lastPipelineStatus = decomposedTask.status.rawValue
            updatedTask.pipelineRunId = run.id
            
            // 최종 상태 매핑
            switch decomposedTask.status {
            case .completed:
                updatedTask.status = .done
                updatedTask.completedAt = Date()
            case .failed:
                // 실패한 태스크는 Backlog로 이동 (재시도 가능)
                updatedTask.status = .backlog
            case .pending, .running:
                // 중단된 경우 - Backlog로
                if run.state == .cancelled || run.state == .paused {
                    updatedTask.status = .backlog
                }
            case .skipped:
                // 건너뛴 경우 - Backlog로
                updatedTask.status = .backlog
            }
            
            updatedTask.updatedAt = Date()
            companyStore.updateTask(updatedTask, inProject: project.id)
        }
        
        print("[PipelineKanbanService] 최종 동기화 완료: \(run.decomposedTasks.count)개 태스크")
    }
    
    // MARK: - Sync Result
    
    struct SyncResult {
        var created: Int = 0
        var updated: Int = 0
        var failed: Int = 0
        
        var total: Int { created + updated }
        
        var description: String {
            if total == 0 {
                return "변경 없음"
            }
            var parts: [String] = []
            if created > 0 { parts.append("\(created)개 생성") }
            if updated > 0 { parts.append("\(updated)개 업데이트") }
            return parts.joined(separator: ", ")
        }
    }
    
    // MARK: - Private Methods
    
    /// 기존 태스크 찾기 (decomposedTaskId로)
    private func findExistingTask(decomposedTaskId: UUID, in project: Project) -> ProjectTask? {
        return project.tasks.first { $0.decomposedTaskId == decomposedTaskId }
    }
    
    /// 기존 태스크 업데이트
    @MainActor
    private func updateExistingTask(
        _ existingTask: ProjectTask,
        with decomposedTask: DecomposedTask,
        pipelineRunId: UUID,
        project: Project,
        companyStore: CompanyStore
    ) -> Bool {
        var updatedTask = existingTask
        
        // 상태 매핑
        let newStatus = mapDecomposedStatusToTaskStatus(decomposedTask.status)
        
        // 변경 사항 확인
        var hasChanges = false
        
        if updatedTask.status != newStatus {
            updatedTask.status = newStatus
            hasChanges = true
        }
        
        if updatedTask.pipelineRunId != pipelineRunId {
            updatedTask.pipelineRunId = pipelineRunId
            hasChanges = true
        }
        
        if updatedTask.lastPipelineStatus != decomposedTask.status.rawValue {
            updatedTask.lastPipelineStatus = decomposedTask.status.rawValue
            hasChanges = true
        }
        
        if newStatus == .done && updatedTask.completedAt == nil {
            updatedTask.completedAt = Date()
            hasChanges = true
        }
        
        if hasChanges {
            updatedTask.updatedAt = Date()
            companyStore.updateTask(updatedTask, inProject: project.id)
            print("[PipelineKanbanService] 태스크 업데이트: \(existingTask.title)")
        }
        
        return hasChanges
    }
    
    /// 새 태스크 생성
    @MainActor
    private func createNewTask(
        from decomposedTask: DecomposedTask,
        pipelineRunId: UUID,
        sprintId: UUID?,
        project: Project,
        companyStore: CompanyStore
    ) -> Bool {
        let newStatus = mapDecomposedStatusToTaskStatus(decomposedTask.status)
        
        var newTask = ProjectTask(
            id: UUID(),  // 새 ID 생성
            title: decomposedTask.title,
            description: decomposedTask.description,
            status: newStatus,
            priority: decomposedTask.priority,
            assigneeId: nil,
            departmentType: decomposedTask.department,
            conversation: [],
            outputs: [],
            createdAt: Date(),
            updatedAt: Date(),
            completedAt: newStatus == .done ? Date() : nil,
            estimatedHours: nil,
            actualHours: nil,
            prompt: "",
            workflowHistory: [],
            parentTaskId: nil,
            sprintId: sprintId,
            pipelineRunId: pipelineRunId,
            decomposedTaskId: decomposedTask.id,
            lastPipelineStatus: decomposedTask.status.rawValue
        )
        
        companyStore.addTask(newTask, toProject: project.id)
        print("[PipelineKanbanService] 태스크 생성: \(decomposedTask.title)")
        return true
    }
    
    /// DecomposedTaskStatus -> TaskStatus 매핑
    private func mapDecomposedStatusToTaskStatus(_ status: DecomposedTaskStatus) -> TaskStatus {
        switch status {
        case .pending:
            return .todo
        case .running:
            return .inProgress
        case .completed:
            return .done
        case .failed:
            return .backlog  // 실패 시 백로그로 (재시도 가능)
        case .skipped:
            return .backlog
        }
    }
}
