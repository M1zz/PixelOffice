import Foundation

/// 질문-답변 시스템의 개별 질문
struct ClarificationRequest: Identifiable, Codable {
    let id: UUID
    let question: String           // 질문 내용
    let askedBy: String            // 질문한 직원 이름
    let department: DepartmentType // 부서
    let context: String?           // 질문 배경
    let options: [String]?         // 선택지 (있으면)
    var answer: String?            // 사용자 답변
    var isAnswered: Bool
    let priority: ClarificationPriority
    let createdAt: Date

    init(
        id: UUID = UUID(),
        question: String,
        askedBy: String,
        department: DepartmentType,
        context: String? = nil,
        options: [String]? = nil,
        answer: String? = nil,
        isAnswered: Bool = false,
        priority: ClarificationPriority = .important,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.question = question
        self.askedBy = askedBy
        self.department = department
        self.context = context
        self.options = options
        self.answer = answer
        self.isAnswered = isAnswered
        self.priority = priority
        self.createdAt = createdAt
    }
}

/// 질문 우선순위
enum ClarificationPriority: String, Codable, CaseIterable {
    case critical   // 반드시 필요
    case important  // 중요하지만 기본값 가능
    case optional   // 있으면 좋음

    var displayName: String {
        switch self {
        case .critical: return "필수"
        case .important: return "중요"
        case .optional: return "선택"
        }
    }

    var icon: String {
        switch self {
        case .critical: return "exclamationmark.circle.fill"
        case .important: return "exclamationmark.triangle.fill"
        case .optional: return "questionmark.circle"
        }
    }

    var color: SwiftUI.Color {
        switch self {
        case .critical: return .red
        case .important: return .orange
        case .optional: return .gray
        }
    }
}

/// 질문-답변 세션
struct ClarificationSession: Identifiable, Codable {
    let id: UUID
    let requirement: String
    var requests: [ClarificationRequest]
    var isComplete: Bool
    let projectId: UUID
    let createdAt: Date

    init(
        id: UUID = UUID(),
        requirement: String,
        requests: [ClarificationRequest] = [],
        isComplete: Bool = false,
        projectId: UUID,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.requirement = requirement
        self.requests = requests
        self.isComplete = isComplete
        self.projectId = projectId
        self.createdAt = createdAt
    }

    /// 답변 완료된 질문 수
    var answeredCount: Int {
        requests.filter { $0.isAnswered }.count
    }

    /// 필수(critical) 질문 중 미답변 수
    var unansweredCriticalCount: Int {
        requests.filter { $0.priority == .critical && !$0.isAnswered }.count
    }

    /// 모든 필수 질문이 답변되었는지
    var allCriticalAnswered: Bool {
        requests.filter { $0.priority == .critical }.allSatisfy { $0.isAnswered }
    }

    /// 진행률 (0.0 ~ 1.0)
    var progress: Double {
        guard !requests.isEmpty else { return 1.0 }
        return Double(answeredCount) / Double(requests.count)
    }

    /// 답변을 바탕으로 보강된 요구사항 생성
    func enrichedRequirement() -> String {
        var enriched = requirement

        let answeredRequests = requests.filter { $0.isAnswered && $0.answer != nil }
        if !answeredRequests.isEmpty {
            enriched += "\n\n## 추가 정보 (질문-답변)\n"
            for request in answeredRequests {
                enriched += "- **\(request.question)**: \(request.answer!)\n"
            }
        }

        return enriched
    }
}

import SwiftUI
