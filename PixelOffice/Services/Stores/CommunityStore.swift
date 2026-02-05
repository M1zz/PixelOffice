import Foundation

/// 커뮤니티 게시글 및 직원 사고 과정 담당 도메인 Store
@MainActor
final class CommunityStore {

    // MARK: - Properties

    unowned let coordinator: StoreCoordinator

    // MARK: - Init

    init(coordinator: StoreCoordinator) {
        self.coordinator = coordinator
    }

    // MARK: - 직원 사고 과정 (Thinking)

    /// 새 사고 과정 시작
    func startThinking(employeeId: UUID, employeeName: String, departmentType: DepartmentType, topic: String) -> EmployeeThinking {
        let thinking = EmployeeThinking(
            employeeId: employeeId,
            employeeName: employeeName,
            departmentType: departmentType,
            topic: topic,
            topicCreatedAt: Date(),
            reasoning: ThinkingReasoning()
        )
        coordinator.company.employeeThinkings.append(thinking)
        coordinator.saveCompany()
        return thinking
    }

    /// 사고 과정에 정보 추가
    func addThinkingInput(thinkingId: UUID, content: String, source: String) {
        guard let index = coordinator.company.employeeThinkings.firstIndex(where: { $0.id == thinkingId }) else { return }
        let input = ThinkingInput(content: content, source: source)
        coordinator.company.employeeThinkings[index].inputs.append(input)
        coordinator.saveCompany()
    }

    /// 사고 과정 갱신
    func updateThinkingReasoning(thinkingId: UUID, reasoning: ThinkingReasoning) {
        guard let index = coordinator.company.employeeThinkings.firstIndex(where: { $0.id == thinkingId }) else { return }
        coordinator.company.employeeThinkings[index].reasoning = reasoning
        coordinator.company.employeeThinkings[index].reasoning.lastUpdated = Date()
        coordinator.saveCompany()
    }

    /// 결론 설정
    func setThinkingConclusion(thinkingId: UUID, conclusion: ThinkingConclusion) {
        guard let index = coordinator.company.employeeThinkings.firstIndex(where: { $0.id == thinkingId }) else { return }
        coordinator.company.employeeThinkings[index].conclusion = conclusion
        coordinator.company.employeeThinkings[index].status = .concluded
        coordinator.saveCompany()
    }

    /// 직원의 활성 사고 과정 조회
    func getActiveThinking(employeeId: UUID) -> EmployeeThinking? {
        coordinator.company.employeeThinkings.first {
            $0.employeeId == employeeId && $0.status == .thinking
        }
    }

    /// 모든 사고 과정 조회 (최신순)
    var employeeThinkings: [EmployeeThinking] {
        coordinator.company.employeeThinkings.sorted { $0.topicCreatedAt > $1.topicCreatedAt }
    }

    // MARK: - 커뮤니티 게시글

    /// 게시글 작성
    func addCommunityPost(_ post: CommunityPost) {
        coordinator.company.communityPosts.append(post)

        // 연결된 사고 과정이 있으면 상태 업데이트
        if let thinkingId = post.thinkingId,
           let index = coordinator.company.employeeThinkings.firstIndex(where: { $0.id == thinkingId }) {
            coordinator.company.employeeThinkings[index].status = .posted
        }

        coordinator.saveCompany()
    }

    /// 사고 과정에서 게시글 생성
    func createPostFromThinking(_ thinking: EmployeeThinking) -> CommunityPost? {
        guard let conclusion = thinking.conclusion else { return nil }

        var post = CommunityPost(
            employeeId: thinking.employeeId,
            employeeName: thinking.employeeName,
            departmentType: thinking.departmentType,
            thinkingId: thinking.id,
            title: thinking.topic,
            content: """
            ## 결론

            \(conclusion.summary)

            ## 근거

            \(conclusion.reasoning)

            ## 실행 계획

            \(conclusion.actionPlan.map { "- \($0)" }.joined(separator: "\n"))

            ## 리스크

            \(conclusion.risks.map { "- \($0)" }.joined(separator: "\n"))
            """,
            summary: conclusion.summary,
            tags: [thinking.departmentType.rawValue]
        )

        post.source = .thinking  // 사고 과정 출처 표시

        addCommunityPost(post)
        return post
    }

    /// 게시글 조회 (최신순)
    var communityPosts: [CommunityPost] {
        coordinator.company.communityPosts.sorted { $0.createdAt > $1.createdAt }
    }

    /// 특정 직원의 게시글
    func getCommunityPosts(employeeId: UUID) -> [CommunityPost] {
        communityPosts.filter { $0.employeeId == employeeId }
    }

    /// 좋아요 추가
    func likeCommunityPost(_ postId: UUID) {
        guard let index = coordinator.company.communityPosts.firstIndex(where: { $0.id == postId }) else { return }
        coordinator.company.communityPosts[index].likes += 1
        coordinator.saveCompany()
    }

    /// 댓글 추가
    func addCommentToPost(_ postId: UUID, comment: PostComment) {
        guard let index = coordinator.company.communityPosts.firstIndex(where: { $0.id == postId }) else { return }
        coordinator.company.communityPosts[index].comments.append(comment)
        coordinator.saveCompany()
    }

    /// 게시글 삭제
    func removeCommunityPost(_ postId: UUID) {
        coordinator.company.communityPosts.removeAll { $0.id == postId }
        coordinator.saveCompany()
    }
}
