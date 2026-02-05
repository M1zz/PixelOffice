import Foundation
import SwiftUI

// MARK: - 토론 모델

/// 구조화된 토론 세션
struct Debate: Codable, Identifiable {
    var id: UUID = UUID()
    var topic: String                          // 토론 주제
    var context: String                        // 추가 배경 정보
    var projectId: UUID?                       // 연결된 프로젝트 (선택)
    var participants: [DebateParticipant]       // 참여 직원들
    var phases: [DebatePhase]                  // 진행된 페이즈들
    var currentPhaseType: DebatePhaseType      // 현재 페이즈
    var synthesis: DebateSynthesis?            // 최종 종합 결과
    var status: DebateStatus                   // 토론 상태
    var settings: DebateSettings               // 토론 설정
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    /// 현재 페이즈의 진행률 (0.0 ~ 1.0)
    var progress: Double {
        let totalPhases = 4.0
        let currentIndex: Double
        switch currentPhaseType {
        case .topic: currentIndex = 0
        case .independentOpinion: currentIndex = 1
        case .crossReview: currentIndex = 2
        case .synthesis: currentIndex = 3
        }
        let phaseProgress = status == .completed ? 1.0 : 0.0
        return (currentIndex + phaseProgress) / totalPhases
    }
}

/// 토론 참여자 정보
struct DebateParticipant: Codable, Identifiable {
    var id: UUID = UUID()
    var employeeId: UUID
    var employeeName: String
    var departmentType: DepartmentType
    var aiType: AIType
    var personality: String
    var strengths: [String]
    var isProjectEmployee: Bool = false
    var projectId: UUID?
}

// MARK: - 토론 페이즈

/// 페이즈 타입
enum DebatePhaseType: String, Codable, CaseIterable {
    case topic = "주제 제시"
    case independentOpinion = "독립 의견"
    case crossReview = "교차 검토"
    case synthesis = "종합"

    var icon: String {
        switch self {
        case .topic: return "doc.text.fill"
        case .independentOpinion: return "person.fill.questionmark"
        case .crossReview: return "arrow.triangle.2.circlepath"
        case .synthesis: return "lightbulb.max.fill"
        }
    }

    var color: Color {
        switch self {
        case .topic: return .blue
        case .independentOpinion: return .orange
        case .crossReview: return .purple
        case .synthesis: return .green
        }
    }

    var description: String {
        switch self {
        case .topic: return "토론 주제와 배경 정보 정리"
        case .independentOpinion: return "각 직원이 독립적으로 의견 제출"
        case .crossReview: return "다른 직원 의견에 대한 반박/보완"
        case .synthesis: return "합의점, 쟁점, 액션 아이템 도출"
        }
    }

    /// 다음 페이즈
    var next: DebatePhaseType? {
        switch self {
        case .topic: return .independentOpinion
        case .independentOpinion: return .crossReview
        case .crossReview: return .synthesis
        case .synthesis: return nil
        }
    }
}

/// 토론 페이즈 데이터
struct DebatePhase: Codable, Identifiable {
    var id: UUID = UUID()
    var type: DebatePhaseType
    var opinions: [DebateOpinion]               // 이 페이즈에서 나온 의견들
    var startedAt: Date = Date()
    var completedAt: Date?
    var isCompleted: Bool { completedAt != nil }
}

/// 개별 의견
struct DebateOpinion: Codable, Identifiable {
    var id: UUID = UUID()
    var participantId: UUID                     // DebateParticipant.id
    var employeeId: UUID
    var employeeName: String
    var departmentType: DepartmentType
    var content: String                         // 의견 내용
    var phase: DebatePhaseType                  // 어떤 페이즈에서 나온 의견인지
    var referencedOpinionIds: [UUID]            // 교차 검토 시 참고한 의견들
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var createdAt: Date = Date()
}

// MARK: - 종합 결과

/// 토론 종합 결과
struct DebateSynthesis: Codable {
    var summary: String                         // 핵심 요약 (3줄)
    var agreements: [String]                    // 합의된 사항
    var disagreements: [String]                 // 쟁점 (의견이 갈린 부분)
    var actionItems: [DebateActionItem]         // 구체적 액션 아이템
    var risks: [String]                         // 리스크 및 주의사항
    var keyInsights: [String]                   // 핵심 인사이트
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var createdAt: Date = Date()
}

/// 액션 아이템
struct DebateActionItem: Codable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var description: String
    var assignedDepartment: DepartmentType?     // 담당 부서
    var priority: ActionPriority
}

/// 액션 우선순위
enum ActionPriority: String, Codable, CaseIterable {
    case high = "높음"
    case medium = "보통"
    case low = "낮음"

    var color: Color {
        switch self {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        }
    }
}

// MARK: - 토론 상태

/// 토론 진행 상태
enum DebateStatus: String, Codable {
    case preparing = "준비 중"
    case inProgress = "진행 중"
    case completed = "완료"
    case failed = "실패"
    case cancelled = "취소"

    var icon: String {
        switch self {
        case .preparing: return "clock.fill"
        case .inProgress: return "play.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .cancelled: return "stop.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .preparing: return .gray
        case .inProgress: return .blue
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .secondary
        }
    }
}

// MARK: - 토론 설정

/// 토론 설정
struct DebateSettings: Codable {
    var crossReviewRounds: Int = 1              // 교차 검토 라운드 수 (1~2)
    var maxTokensPerOpinion: Int = 2048         // 의견당 최대 토큰
    var includeWebSearch: Bool = false           // 웹 검색 활용 여부
    var autoPostToCommunity: Bool = true        // 완료 후 자동 커뮤니티 게시
    var saveToWiki: Bool = true                 // 위키에 회의록 저장

    init(
        crossReviewRounds: Int = 1,
        maxTokensPerOpinion: Int = 2048,
        includeWebSearch: Bool = false,
        autoPostToCommunity: Bool = true,
        saveToWiki: Bool = true
    ) {
        self.crossReviewRounds = crossReviewRounds
        self.maxTokensPerOpinion = maxTokensPerOpinion
        self.includeWebSearch = includeWebSearch
        self.autoPostToCommunity = autoPostToCommunity
        self.saveToWiki = saveToWiki
    }
}

// MARK: - 토론 컨텍스트 (윈도우 열기용)

/// 토론 윈도우 컨텍스트
struct DebateContext: Codable, Hashable {
    var debateId: UUID
    var projectId: UUID?
}
