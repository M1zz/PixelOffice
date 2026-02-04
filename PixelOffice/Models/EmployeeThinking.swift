import Foundation

/// 직원의 사고 과정을 추적하는 모델
struct EmployeeThinking: Codable, Identifiable {
    var id: UUID = UUID()
    var employeeId: UUID
    var employeeName: String
    var departmentType: DepartmentType

    // 사고 주제
    var topic: String
    var topicCreatedAt: Date

    // 축적된 정보들
    var inputs: [ThinkingInput] = []

    // 현재 사고 상태
    var reasoning: ThinkingReasoning

    // 결론 (조건 충족 시 생성)
    var conclusion: ThinkingConclusion?

    // 상태
    var status: ThinkingStatus = .thinking

    var isReadyForConclusion: Bool {
        reasoning.readinessScore >= 8 ||
        reasoning.unresolvedQuestions.count <= 1 ||
        (reasoning.keyInsights.count >= 5 && inputs.count >= 5) ||
        (inputs.count >= 7 && reasoning.noNewInsightsCount >= 2)
    }
}

/// 입력된 정보
struct ThinkingInput: Codable, Identifiable {
    var id: UUID = UUID()
    var content: String
    var source: String  // 누가/어디서 입력했는지
    var timestamp: Date = Date()
}

/// 사고 과정
struct ThinkingReasoning: Codable {
    var currentUnderstanding: String = ""      // 현재 이해도
    var keyInsights: [String] = []             // 핵심 인사이트
    var unresolvedQuestions: [String] = []     // 미해결 질문
    var tentativeDirection: String = ""        // 잠정적 방향
    var readinessScore: Int = 0                // 결론 준비도 (1-10)
    var noNewInsightsCount: Int = 0            // 새 인사이트 없이 정보가 추가된 횟수
    var lastUpdated: Date = Date()
}

/// 결론
struct ThinkingConclusion: Codable {
    var summary: String                        // 3줄 요약
    var reasoning: String                      // 근거
    var actionPlan: [String]                   // 구체적 실행 계획
    var risks: [String]                        // 리스크와 대안
    var turningPoints: [String]                // 사고 전환점
    var createdAt: Date = Date()
}

/// 사고 상태
enum ThinkingStatus: String, Codable {
    case thinking = "사고 중"
    case needsInput = "정보 필요"
    case concluded = "결론 도출"
    case posted = "게시 완료"

    var icon: String {
        switch self {
        case .thinking: return "brain"
        case .needsInput: return "questionmark.circle"
        case .concluded: return "lightbulb.fill"
        case .posted: return "checkmark.circle.fill"
        }
    }
}

/// 커뮤니티 게시글
struct CommunityPost: Codable, Identifiable {
    var id: UUID = UUID()
    var employeeId: UUID
    var employeeName: String
    var departmentType: DepartmentType
    var thinkingId: UUID?  // 연결된 사고 과정

    var title: String
    var content: String
    var summary: String
    var tags: [String] = []

    var likes: Int = 0
    var comments: [PostComment] = []

    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}

/// 게시글 댓글
struct PostComment: Codable, Identifiable {
    var id: UUID = UUID()
    var employeeId: UUID
    var employeeName: String
    var content: String
    var createdAt: Date = Date()
}
