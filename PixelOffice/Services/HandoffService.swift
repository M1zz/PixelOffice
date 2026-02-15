//
//  HandoffService.swift
//  PixelOffice
//
//  Created by Pipeline on 2026-02-15.
//
//  작업 인계(핸드오프) 관리 서비스
//

import Foundation

/// 핸드오프 관리 서비스
@MainActor
class HandoffService {
    static let shared = HandoffService()
    
    private let fileManager = FileManager.default
    private var handoffs: [TaskHandoff] = []
    
    private init() {
        loadHandoffs()
    }
    
    // MARK: - Public API
    
    /// 핸드오프 생성
    func createHandoff(_ handoff: TaskHandoff) {
        var newHandoff = handoff
        newHandoff.status = .pending
        handoffs.append(newHandoff)
        saveHandoffs()
        
        print("[HandoffService] 📤 핸드오프 생성: \(handoff.summary)")
    }
    
    /// 워크플로우 단계 완료 시 자동 핸드오프
    func createPhaseHandoff(
        task: ProjectTask,
        from: ProjectEmployee,
        to: ProjectEmployee,
        project: Project,
        deliverables: [String] = []
    ) {
        let handoff = TaskHandoff.forPhaseCompletion(
            task: task,
            from: from,
            to: to,
            project: project,
            deliverables: deliverables
        )
        createHandoff(handoff)
    }
    
    /// 핸드오프 수락
    func acceptHandoff(id: UUID) {
        guard let index = handoffs.firstIndex(where: { $0.id == id }) else { return }
        handoffs[index].status = .accepted
        handoffs[index].acceptedAt = Date()
        saveHandoffs()
        
        print("[HandoffService] ✅ 핸드오프 수락: \(handoffs[index].taskTitle)")
    }
    
    /// 핸드오프 완료
    func completeHandoff(id: UUID) {
        guard let index = handoffs.firstIndex(where: { $0.id == id }) else { return }
        handoffs[index].status = .completed
        handoffs[index].completedAt = Date()
        saveHandoffs()
        
        print("[HandoffService] ✅ 핸드오프 완료: \(handoffs[index].taskTitle)")
    }
    
    /// 핸드오프 거절
    func rejectHandoff(id: UUID, reason: String) {
        guard let index = handoffs.firstIndex(where: { $0.id == id }) else { return }
        handoffs[index].status = .rejected
        handoffs[index].notes = reason
        saveHandoffs()
        
        print("[HandoffService] ❌ 핸드오프 거절: \(handoffs[index].taskTitle)")
    }
    
    // MARK: - Queries
    
    /// 모든 핸드오프 (최신순)
    var allHandoffs: [TaskHandoff] {
        handoffs.sorted { $0.timestamp > $1.timestamp }
    }
    
    /// 대기 중인 핸드오프
    var pendingHandoffs: [TaskHandoff] {
        handoffs.filter { $0.status == .pending }
    }
    
    /// 특정 직원에게 온 핸드오프
    func handoffsFor(employeeId: UUID) -> [TaskHandoff] {
        handoffs.filter { $0.toEmployeeId == employeeId }
    }
    
    /// 특정 직원이 보낸 핸드오프
    func handoffsFrom(employeeId: UUID) -> [TaskHandoff] {
        handoffs.filter { $0.fromEmployeeId == employeeId }
    }
    
    /// 특정 프로젝트의 핸드오프
    func handoffsFor(projectId: UUID) -> [TaskHandoff] {
        handoffs.filter { $0.projectId == projectId }
    }
    
    /// 부서 간 핸드오프 통계
    func handoffStats() -> [String: Int] {
        var stats: [String: Int] = [:]
        for handoff in handoffs {
            let key = "\(handoff.fromDepartment.rawValue) → \(handoff.toDepartment.rawValue)"
            stats[key, default: 0] += 1
        }
        return stats
    }
    
    // MARK: - Workflow Integration
    
    /// 워크플로우 순서에 따른 다음 부서 결정
    func nextDepartment(after current: DepartmentType) -> DepartmentType? {
        let workflow: [DepartmentType] = [.planning, .design, .development, .qa, .marketing]
        guard let currentIndex = workflow.firstIndex(of: current) else { return nil }
        let nextIndex = currentIndex + 1
        return nextIndex < workflow.count ? workflow[nextIndex] : nil
    }
    
    /// 워크플로우에 따른 자동 핸드오프 추천
    func suggestHandoff(
        task: ProjectTask,
        currentEmployee: ProjectEmployee,
        project: Project
    ) -> (department: DepartmentType, employee: ProjectEmployee?)? {
        guard let nextDept = nextDepartment(after: currentEmployee.departmentType) else {
            return nil
        }
        
        let nextEmployee = SkillMatchingService.shared.recommendNextAssignee(
            currentTask: task,
            nextDepartment: nextDept,
            project: project
        )
        
        return (nextDept, nextEmployee)
    }
    
    // MARK: - Persistence
    
    private var handoffsFilePath: String {
        "\(DataPathService.shared.sharedPath)/handoffs.json"
    }
    
    private func loadHandoffs() {
        guard fileManager.fileExists(atPath: handoffsFilePath),
              let data = fileManager.contents(atPath: handoffsFilePath) else {
            return
        }
        
        do {
            handoffs = try JSONDecoder().decode([TaskHandoff].self, from: data)
            print("[HandoffService] 📂 핸드오프 \(handoffs.count)개 로드")
        } catch {
            print("[HandoffService] ⚠️ 로드 실패: \(error)")
        }
    }
    
    private func saveHandoffs() {
        do {
            let data = try JSONEncoder().encode(handoffs)
            try data.write(to: URL(fileURLWithPath: handoffsFilePath))
        } catch {
            print("[HandoffService] ⚠️ 저장 실패: \(error)")
        }
    }
}

// MARK: - Handoff Detection

extension HandoffService {
    /// AI 응답에서 핸드오프 의도 감지
    func detectHandoffIntent(from response: String) -> (department: DepartmentType, reason: HandoffReason)? {
        let handoffPatterns: [(pattern: String, department: DepartmentType, reason: HandoffReason)] = [
            ("디자인.*넘기", .design, .phaseComplete),
            ("개발.*전달", .development, .phaseComplete),
            ("QA.*검토", .qa, .review),
            ("기획.*확인", .planning, .review),
            ("코드 리뷰", .development, .review),
            ("디자인 리뷰", .design, .review),
            ("테스트.*요청", .qa, .support),
        ]
        
        for (pattern, dept, reason) in handoffPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
               regex.firstMatch(in: response, options: [], range: NSRange(response.startIndex..., in: response)) != nil {
                return (dept, reason)
            }
        }
        
        return nil
    }
}
