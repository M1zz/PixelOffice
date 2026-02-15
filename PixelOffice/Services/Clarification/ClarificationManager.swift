import Foundation
import SwiftUI

/// 질문-답변 세션을 관리하는 매니저
@MainActor
class ClarificationManager: ObservableObject {
    // MARK: - Published Properties

    @Published var currentSession: ClarificationSession?
    @Published var isAnalyzing: Bool = false
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private let analyzer = RequirementAnalyzer()

    // MARK: - Session Management

    /// 새 질문-답변 세션 시작
    /// - Parameters:
    ///   - requirement: 사용자 요구사항
    ///   - project: 프로젝트
    /// - Returns: 생성된 세션 (질문이 없으면 nil)
    func startSession(
        requirement: String,
        project: Project
    ) async -> ClarificationSession? {
        isAnalyzing = true
        errorMessage = nil

        do {
            let employees = project.departments.flatMap { $0.employees }
            let questions = try await analyzer.analyzeRequirement(
                requirement: requirement,
                project: project,
                employees: employees
            )

            // 질문이 없으면 세션 생성 안 함
            guard !questions.isEmpty else {
                isAnalyzing = false
                return nil
            }

            let session = ClarificationSession(
                requirement: requirement,
                requests: questions,
                projectId: project.id
            )

            currentSession = session
            isAnalyzing = false
            return session

        } catch {
            errorMessage = error.localizedDescription
            isAnalyzing = false
            print("[ClarificationManager] 분석 실패: \(error)")
            return nil
        }
    }

    /// 질문에 답변 저장
    /// - Parameters:
    ///   - questionId: 질문 ID
    ///   - answer: 답변 내용
    func answerQuestion(_ questionId: UUID, with answer: String) {
        guard var session = currentSession else { return }

        if let index = session.requests.firstIndex(where: { $0.id == questionId }) {
            session.requests[index].answer = answer
            session.requests[index].isAnswered = true
            currentSession = session
        }
    }

    /// 옵션으로 답변 (선택지가 있는 경우)
    /// - Parameters:
    ///   - questionId: 질문 ID
    ///   - option: 선택한 옵션
    func answerWithOption(_ questionId: UUID, option: String) {
        answerQuestion(questionId, with: option)
    }

    /// 세션 완료 처리
    func completeSession() {
        guard var session = currentSession else { return }
        session.isComplete = true
        currentSession = session
    }

    /// 세션 취소 (스킵)
    func skipSession() {
        // 모든 미답변 질문에 기본값 설정
        guard var session = currentSession else { return }

        for index in session.requests.indices {
            if !session.requests[index].isAnswered {
                session.requests[index].answer = "AI가 판단해서 진행"
                session.requests[index].isAnswered = true
            }
        }

        session.isComplete = true
        currentSession = session
    }

    /// 세션 리셋
    func resetSession() {
        currentSession = nil
        errorMessage = nil
    }

    /// 보강된 요구사항 생성
    func getEnrichedRequirement() -> String? {
        return currentSession?.enrichedRequirement()
    }

    /// 모든 필수 질문이 답변되었는지
    var canComplete: Bool {
        currentSession?.allCriticalAnswered ?? true
    }

    /// 진행률
    var progress: Double {
        currentSession?.progress ?? 0
    }
}
