import Foundation
import SwiftUI

// MARK: - Sub-Agent Status

/// Sub-agent 실행 상태
enum SubAgentStatus: String, Codable, CaseIterable {
    case idle = "대기"
    case running = "실행 중"
    case completed = "완료"
    case failed = "실패"
    case paused = "일시정지"
    case cancelled = "취소됨"
    
    var icon: String {
        switch self {
        case .idle: return "circle"
        case .running: return "play.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .paused: return "pause.circle.fill"
        case .cancelled: return "stop.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .idle: return .secondary
        case .running: return .blue
        case .completed: return .green
        case .failed: return .red
        case .paused: return .orange
        case .cancelled: return .gray
        }
    }
    
    var isActive: Bool {
        self == .running
    }
    
    var isTerminal: Bool {
        switch self {
        case .completed, .failed, .cancelled:
            return true
        default:
            return false
        }
    }
}

// MARK: - Sub-Agent

/// Sub-agent 모델 - 병렬 작업을 위한 독립 에이전트
struct SubAgent: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var task: SubAgentTask
    var status: SubAgentStatus = .idle
    var result: SubAgentResult?
    var error: String?
    
    /// 할당된 직원 ID (옵션)
    var assignedEmployeeId: UUID?
    var assignedEmployeeName: String?
    
    /// 생성/실행 시간
    var createdAt: Date = Date()
    var startedAt: Date?
    var completedAt: Date?
    
    /// 진행률 (0.0 ~ 1.0)
    var progress: Double = 0.0
    
    /// 현재 수행 중인 작업 설명
    var currentAction: String = ""
    
    /// 토큰 사용량
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var costUSD: Double = 0.0
    
    /// 부모 오케스트레이터 ID
    var parentOrchestratorId: UUID?
    
    /// 의존하는 다른 sub-agent ID들
    var dependencies: [UUID] = []
    
    /// 소요 시간 (초)
    var duration: TimeInterval? {
        guard let start = startedAt else { return nil }
        let end = completedAt ?? Date()
        return end.timeIntervalSince(start)
    }
    
    /// 총 토큰 수
    var totalTokens: Int {
        inputTokens + outputTokens
    }
    
    // MARK: - Hashable
    
    static func == (lhs: SubAgent, rhs: SubAgent) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Sub-Agent Task

/// Sub-agent가 수행할 태스크
struct SubAgentTask: Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var description: String
    var type: SubAgentTaskType
    var priority: TaskPriority = .medium
    
    /// 태스크에 필요한 컨텍스트
    var context: String?
    
    /// 사용할 스킬 ID들
    var skillIds: [String] = []
    
    /// 입력 데이터 (JSON 문자열)
    var inputData: String?
    
    /// 예상 소요 시간 (초)
    var estimatedDuration: TimeInterval?
}

/// Sub-agent 태스크 유형
enum SubAgentTaskType: String, Codable, CaseIterable {
    case codeGeneration = "코드 생성"
    case codeAnalysis = "코드 분석"
    case testing = "테스트"
    case documentation = "문서화"
    case refactoring = "리팩토링"
    case design = "디자인"
    case review = "코드 리뷰"
    case research = "조사"
    case custom = "커스텀"
    
    var icon: String {
        switch self {
        case .codeGeneration: return "chevron.left.forwardslash.chevron.right"
        case .codeAnalysis: return "magnifyingglass.circle"
        case .testing: return "checkmark.shield"
        case .documentation: return "doc.text"
        case .refactoring: return "arrow.triangle.2.circlepath"
        case .design: return "paintbrush"
        case .review: return "eye"
        case .research: return "book"
        case .custom: return "gearshape"
        }
    }
    
    var color: Color {
        switch self {
        case .codeGeneration: return .blue
        case .codeAnalysis: return .purple
        case .testing: return .green
        case .documentation: return .orange
        case .refactoring: return .yellow
        case .design: return .pink
        case .review: return .cyan
        case .research: return .indigo
        case .custom: return .secondary
        }
    }
}

// MARK: - Sub-Agent Result

/// Sub-agent 실행 결과
struct SubAgentResult: Codable, Hashable {
    var id: UUID = UUID()
    var output: String
    var artifacts: [SubAgentArtifact] = []
    var metrics: SubAgentMetrics?
    var decisions: [PipelineDecision] = []
    var thinking: String = ""
    
    /// 생성된 파일들
    var createdFiles: [String] = []
    
    /// 수정된 파일들
    var modifiedFiles: [String] = []
    
    /// 결과 요약
    var summary: String?
}

/// Sub-agent가 생성한 아티팩트
struct SubAgentArtifact: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var type: ArtifactType
    var content: String
    var filePath: String?
    
    enum ArtifactType: String, Codable {
        case code = "코드"
        case document = "문서"
        case test = "테스트"
        case design = "디자인"
        case data = "데이터"
        case other = "기타"
    }
}

/// Sub-agent 실행 메트릭
struct SubAgentMetrics: Codable, Hashable {
    var executionTime: TimeInterval
    var inputTokens: Int
    var outputTokens: Int
    var costUSD: Double
    var toolCallCount: Int = 0
    var fileReadCount: Int = 0
    var fileWriteCount: Int = 0
}

// MARK: - Orchestrator Session

/// 오케스트레이터 세션 - 여러 sub-agent를 조율
struct OrchestratorSession: Codable, Identifiable {
    var id: UUID = UUID()
    var projectId: UUID
    var requirement: String
    var subAgents: [SubAgent] = []
    var status: OrchestratorStatus = .planning
    var createdAt: Date = Date()
    var startedAt: Date?
    var completedAt: Date?
    
    /// 전체 진행률
    var progress: Double {
        guard !subAgents.isEmpty else { return 0 }
        let completed = subAgents.filter { $0.status.isTerminal }.count
        return Double(completed) / Double(subAgents.count)
    }
    
    /// 성공한 sub-agent 수
    var successCount: Int {
        subAgents.filter { $0.status == .completed }.count
    }
    
    /// 실패한 sub-agent 수
    var failureCount: Int {
        subAgents.filter { $0.status == .failed }.count
    }
    
    /// 실행 중인 sub-agent 수
    var runningCount: Int {
        subAgents.filter { $0.status == .running }.count
    }
    
    /// 총 토큰 사용량
    var totalTokens: Int {
        subAgents.reduce(0) { $0 + $1.totalTokens }
    }
    
    /// 총 비용
    var totalCostUSD: Double {
        subAgents.reduce(0) { $0 + $1.costUSD }
    }
}

/// 오케스트레이터 상태
enum OrchestratorStatus: String, Codable {
    case planning = "계획 중"
    case running = "실행 중"
    case aggregating = "결과 수집 중"
    case completed = "완료"
    case failed = "실패"
    case cancelled = "취소됨"
    
    var icon: String {
        switch self {
        case .planning: return "brain"
        case .running: return "play.circle.fill"
        case .aggregating: return "arrow.triangle.merge"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .cancelled: return "stop.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .planning: return .purple
        case .running: return .blue
        case .aggregating: return .orange
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .gray
        }
    }
}
