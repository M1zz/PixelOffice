import Foundation
import SwiftUI

// MARK: - Pipeline State

/// 파이프라인 실행 상태
enum PipelineState: String, Codable, CaseIterable {
    case idle = "대기"
    case decomposing = "분해중"
    case executing = "실행중"
    case building = "빌드중"
    case healing = "수정중"
    case completed = "완료"
    case failed = "실패"
    case cancelled = "취소됨"
    case paused = "일시정지"  // 중단됨 (재개 가능)

    var icon: String {
        switch self {
        case .idle: return "circle"
        case .decomposing: return "brain"
        case .executing: return "gearshape.2"
        case .building: return "hammer"
        case .healing: return "bandage"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .cancelled: return "stop.circle.fill"
        case .paused: return "pause.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .idle: return .secondary
        case .decomposing: return .purple
        case .executing: return .blue
        case .building: return .orange
        case .healing: return .yellow
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .gray
        case .paused: return .orange
        }
    }

    var isActive: Bool {
        switch self {
        case .decomposing, .executing, .building, .healing:
            return true
        default:
            return false
        }
    }

    /// 재개 가능 여부
    var canResume: Bool {
        switch self {
        case .paused, .failed:
            return true
        default:
            return false
        }
    }
}

// MARK: - Pipeline Phase

/// 파이프라인 단계 (1~4)
enum PipelinePhase: Int, Codable, CaseIterable {
    case decomposition = 1  // 요구사항 분해
    case development = 2    // 코드 생성
    case build = 3          // 빌드
    case healing = 4        // Self-Healing

    var name: String {
        switch self {
        case .decomposition: return "요구사항 분해"
        case .development: return "코드 생성"
        case .build: return "빌드"
        case .healing: return "Self-Healing"
        }
    }

    var icon: String {
        switch self {
        case .decomposition: return "brain"
        case .development: return "chevron.left.forwardslash.chevron.right"
        case .build: return "hammer"
        case .healing: return "bandage"
        }
    }

    var color: Color {
        switch self {
        case .decomposition: return .purple
        case .development: return .blue
        case .build: return .orange
        case .healing: return .yellow
        }
    }
}

// MARK: - Pipeline Run

/// 파이프라인 실행 단위
struct PipelineRun: Codable, Identifiable {
    var id: UUID = UUID()
    var projectId: UUID
    var projectName: String = ""  // 프로젝트 이름 (표시용)
    var requirement: String
    var state: PipelineState = .idle
    var currentPhase: PipelinePhase = .decomposition
    var decomposedTasks: [DecomposedTask] = []
    var buildAttempts: [BuildAttempt] = []
    var healingAttempts: Int = 0
    var maxHealingAttempts: Int = 1
    var logs: [PipelineLogEntry] = []
    var createdAt: Date = Date()
    var startedAt: Date?
    var completedAt: Date?
    var lastSavedAt: Date?  // 마지막 저장 시각

    /// 완료된 Phase 목록 (재개 시 사용)
    var completedPhases: [PipelinePhase] = []

    /// 현재 실행 중인 태스크 인덱스 (재개 시 사용)
    var currentTaskIndex: Int = 0

    /// 담당자 정보 (모르는 것이 있을 때 질문할 대상)
    var assignedEmployeeId: UUID?
    var assignedEmployeeName: String?

    /// 총 소요 시간 (초)
    var duration: TimeInterval? {
        guard let start = startedAt else { return nil }
        let end = completedAt ?? Date()
        return end.timeIntervalSince(start)
    }

    /// 마지막 빌드 시도
    var lastBuildAttempt: BuildAttempt? {
        buildAttempts.last
    }

    /// 빌드 성공 여부
    var isBuildSuccessful: Bool {
        lastBuildAttempt?.success == true
    }

    /// Self-Healing 가능 여부
    var canHeal: Bool {
        healingAttempts < maxHealingAttempts && !isBuildSuccessful
    }

    /// 재개 가능 여부
    var canResume: Bool {
        // 완료/취소가 아니고, 진행 중이었던 상태
        state != .completed && state != .cancelled && startedAt != nil && completedAt == nil
    }

    /// 재개 시 시작할 Phase
    var resumePhase: PipelinePhase {
        // 마지막으로 완료된 Phase 다음부터 시작
        if let lastCompleted = completedPhases.max(by: { $0.rawValue < $1.rawValue }) {
            if let nextPhase = PipelinePhase(rawValue: lastCompleted.rawValue + 1) {
                return nextPhase
            }
        }
        return currentPhase
    }

    mutating func addLog(_ message: String, level: PipelineLogLevel = .info) {
        logs.append(PipelineLogEntry(message: message, level: level, phase: currentPhase))
    }

    mutating func markPhaseCompleted(_ phase: PipelinePhase) {
        if !completedPhases.contains(phase) {
            completedPhases.append(phase)
        }
    }
}

// MARK: - Build Attempt

/// 빌드 시도 기록
struct BuildAttempt: Codable, Identifiable {
    var id: UUID = UUID()
    var success: Bool
    var exitCode: Int32
    var output: String
    var errors: [BuildError]
    var startedAt: Date
    var completedAt: Date
    var isHealingAttempt: Bool = false

    /// 소요 시간 (초)
    var duration: TimeInterval {
        completedAt.timeIntervalSince(startedAt)
    }
}

/// 빌드 에러
struct BuildError: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var file: String?
    var line: Int?
    var column: Int?
    var message: String
    var severity: BuildErrorSeverity

    var location: String {
        var loc = ""
        if let file = file {
            loc = file
            if let line = line {
                loc += ":\(line)"
                if let column = column {
                    loc += ":\(column)"
                }
            }
        }
        return loc
    }
}

enum BuildErrorSeverity: String, Codable {
    case error = "error"
    case warning = "warning"
    case note = "note"

    var color: Color {
        switch self {
        case .error: return .red
        case .warning: return .orange
        case .note: return .secondary
        }
    }

    var icon: String {
        switch self {
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .note: return "info.circle.fill"
        }
    }
}

// MARK: - Pipeline Log

/// 파이프라인 로그 항목
struct PipelineLogEntry: Codable, Identifiable {
    var id: UUID = UUID()
    var timestamp: Date = Date()
    var message: String
    var level: PipelineLogLevel
    var phase: PipelinePhase?

    init(message: String, level: PipelineLogLevel = .info, phase: PipelinePhase? = nil) {
        self.message = message
        self.level = level
        self.phase = phase
    }
}

enum PipelineLogLevel: String, Codable {
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
    case success = "success"

    var color: Color {
        switch self {
        case .debug: return .secondary
        case .info: return .primary
        case .warning: return .orange
        case .error: return .red
        case .success: return .green
        }
    }

    var icon: String {
        switch self {
        case .debug: return "ant"
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        case .success: return "checkmark.circle"
        }
    }
}

// MARK: - Decomposition Result

/// 요구사항 분해 결과
struct DecompositionResult: Codable {
    var tasks: [DecomposedTask]
    var summary: String
    var warnings: [String]
    var estimatedTime: String?

    init(tasks: [DecomposedTask] = [], summary: String = "", warnings: [String] = [], estimatedTime: String? = nil) {
        self.tasks = tasks
        self.summary = summary
        self.warnings = warnings
        self.estimatedTime = estimatedTime
    }
}
