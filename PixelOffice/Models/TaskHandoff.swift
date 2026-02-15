//
//  TaskHandoff.swift
//  PixelOffice
//
//  Created by Pipeline on 2026-02-15.
//
//  작업 인계(핸드오프) 기록 - 직원 간 업무 전달 추적
//

import Foundation

/// 작업 인계 기록
struct TaskHandoff: Codable, Identifiable {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    
    // 작업 정보
    var taskId: UUID?
    var taskTitle: String
    var projectId: UUID?
    var projectName: String?
    
    // 인계자 (From)
    var fromEmployeeId: UUID
    var fromEmployeeName: String
    var fromDepartment: DepartmentType
    
    // 인수자 (To)
    var toEmployeeId: UUID
    var toEmployeeName: String
    var toDepartment: DepartmentType
    
    // 인계 내용
    var reason: HandoffReason          // 인계 사유
    var context: String                // 작업 맥락/배경
    var deliverables: [String]         // 인계 산출물 (파일 경로 등)
    var notes: String                  // 추가 메모
    
    // 상태
    var status: HandoffStatus = .pending
    var acceptedAt: Date?
    var completedAt: Date?
    
    /// 포맷된 날짜
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd HH:mm"
        return formatter.string(from: timestamp)
    }
    
    /// 요약
    var summary: String {
        "\(fromEmployeeName)(\(fromDepartment.rawValue)) → \(toEmployeeName)(\(toDepartment.rawValue)): \(taskTitle)"
    }
}

/// 인계 사유
enum HandoffReason: String, Codable, CaseIterable {
    case phaseComplete = "단계 완료"      // 기획 → 디자인 등
    case specialization = "전문성 필요"   // 특정 스킬 필요
    case review = "검토 요청"             // 코드 리뷰, 디자인 리뷰
    case support = "지원 요청"            // 도움 필요
    case delegation = "업무 위임"         // 업무 분담
    case escalation = "상위 에스컬레이션" // 문제 발생
    case other = "기타"
    
    var icon: String {
        switch self {
        case .phaseComplete: return "arrow.right.circle"
        case .specialization: return "star.circle"
        case .review: return "eye.circle"
        case .support: return "hand.raised.circle"
        case .delegation: return "person.2.circle"
        case .escalation: return "exclamationmark.triangle"
        case .other: return "circle"
        }
    }
}

/// 인계 상태
enum HandoffStatus: String, Codable {
    case pending = "대기중"
    case accepted = "수락됨"
    case inProgress = "진행중"
    case completed = "완료"
    case rejected = "거절됨"
    
    var icon: String {
        switch self {
        case .pending: return "clock"
        case .accepted: return "checkmark.circle"
        case .inProgress: return "arrow.triangle.2.circlepath"
        case .completed: return "checkmark.circle.fill"
        case .rejected: return "xmark.circle"
        }
    }
}

// MARK: - Handoff Builder

extension TaskHandoff {
    /// 워크플로우 단계 완료 시 자동 핸드오프 생성
    static func forPhaseCompletion(
        task: ProjectTask,
        from: ProjectEmployee,
        to: ProjectEmployee,
        project: Project,
        deliverables: [String] = []
    ) -> TaskHandoff {
        TaskHandoff(
            taskId: task.id,
            taskTitle: task.title,
            projectId: project.id,
            projectName: project.name,
            fromEmployeeId: from.id,
            fromEmployeeName: from.name,
            fromDepartment: from.departmentType,
            toEmployeeId: to.id,
            toEmployeeName: to.name,
            toDepartment: to.departmentType,
            reason: .phaseComplete,
            context: "[\(from.departmentType.rawValue)] 단계 완료 후 [\(to.departmentType.rawValue)]로 인계",
            deliverables: deliverables,
            notes: ""
        )
    }
    
    /// 리뷰 요청 핸드오프
    static func forReview(
        taskTitle: String,
        from: ProjectEmployee,
        to: ProjectEmployee,
        project: Project?,
        context: String
    ) -> TaskHandoff {
        TaskHandoff(
            taskTitle: taskTitle,
            projectId: project?.id,
            projectName: project?.name,
            fromEmployeeId: from.id,
            fromEmployeeName: from.name,
            fromDepartment: from.departmentType,
            toEmployeeId: to.id,
            toEmployeeName: to.name,
            toDepartment: to.departmentType,
            reason: .review,
            context: context,
            deliverables: [],
            notes: ""
        )
    }
}
