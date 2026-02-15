import Foundation

/// 커뮤니티 게시글 및 직원 사고 과정 담당 도메인 Store
@MainActor
final class CommunityStore {

    // MARK: - Properties

    unowned let coordinator: StoreCoordinator
    
    /// 파일 기반 커뮤니티 서비스
    private let fileService = CommunityService.shared

    /// 댓글 템플릿 (부서별)
    private let commentTemplates: [DepartmentType: [String]] = [
        .planning: [
            "좋은 인사이트네요! 프로젝트에 반영해보면 좋겠어요.",
            "이 부분 기획서에 추가하면 좋을 것 같습니다.",
            "사용자 관점에서 중요한 포인트예요!",
            "다음 회의에서 논의해봐요.",
            "ROI 측면에서도 검토해보면 좋겠네요."
        ],
        .design: [
            "UX 관점에서 좋은 접근이에요!",
            "비주얼적으로 어떻게 표현할지 고민해볼게요.",
            "사용성 테스트에 반영하면 좋겠어요.",
            "디자인 시스템에 추가할 만한 내용이네요.",
            "접근성도 함께 고려해주세요!"
        ],
        .development: [
            "기술적으로 구현 가능해 보여요!",
            "성능 최적화도 고려해봐야 할 것 같아요.",
            "코드 리뷰 때 같이 논의해요.",
            "테스트 케이스 추가가 필요할 것 같네요.",
            "확장성 측면에서 좋은 방향이에요."
        ],
        .qa: [
            "테스트 시나리오에 추가할게요!",
            "엣지 케이스도 고려해봐야 할 것 같아요.",
            "품질 기준에 부합하는 좋은 제안이에요.",
            "회귀 테스트 대상에 포함시킬게요.",
            "버그 예방 차원에서 중요한 포인트예요."
        ],
        .marketing: [
            "마케팅 메시지에 활용할 수 있겠어요!",
            "타겟 고객에게 어필할 수 있는 내용이네요.",
            "캠페인에 반영해보면 좋겠어요.",
            "소셜 미디어에서 좋은 반응을 얻을 수 있을 것 같아요.",
            "브랜드 가치와 잘 맞아요!"
        ],
        .general: [
            "좋은 의견이에요!",
            "공감합니다.",
            "참고하겠습니다!",
            "다양한 관점이 있네요.",
            "함께 고민해봐요!"
        ]
    ]

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
    /// - Parameters:
    ///   - post: 게시글
    ///   - autoComment: 자동 댓글 추가 여부 (기본: true)
    ///   - commentCount: 자동 추가할 댓글 수 (기본: 1~3개 랜덤)
    func addCommunityPost(_ post: CommunityPost, autoComment: Bool = true, commentCount: Int? = nil) {
        coordinator.company.communityPosts.append(post)

        // 연결된 사고 과정이 있으면 상태 업데이트
        if let thinkingId = post.thinkingId,
           let index = coordinator.company.employeeThinkings.firstIndex(where: { $0.id == thinkingId }) {
            coordinator.company.employeeThinkings[index].status = .posted
        }

        coordinator.saveCompany()
        
        // 📁 파일로도 저장 (동기화)
        syncPostToFile(post)

        // 자동 댓글 추가
        if autoComment {
            let count = commentCount ?? Int.random(in: 1...3)
            Task { @MainActor in
                // 약간의 딜레이 후 댓글 추가 (자연스러움)
                try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5초
                self.addRandomComments(to: post.id, count: count)
            }
        }
    }
    
    // MARK: - 파일 동기화
    
    /// 게시글을 마크다운 파일로 저장
    private func syncPostToFile(_ post: CommunityPost) {
        let thought = CommunityThought(
            id: fileService.generateThoughtId(),
            title: post.title,
            content: post.content,
            author: post.employeeName,
            authorId: post.employeeId.uuidString,
            department: post.departmentType.rawValue,
            project: nil,
            created: post.createdAt,
            tags: post.tags,
            comments: post.comments.map { comment in
                ThoughtComment(
                    id: comment.id.uuidString,
                    author: comment.employeeName,
                    authorId: comment.employeeId.uuidString,
                    department: "",
                    content: comment.content,
                    created: comment.createdAt
                )
            }
        )
        
        do {
            try fileService.saveThought(thought)
            print("📁 [CommunityStore] 파일로 동기화됨: \(thought.fileName)")
        } catch {
            print("⚠️ [CommunityStore] 파일 동기화 실패: \(error)")
        }
    }
    
    /// 댓글 추가 시 파일도 업데이트
    private func syncCommentsToFile(postId: UUID) {
        guard let post = coordinator.company.communityPosts.first(where: { $0.id == postId }) else { return }
        syncPostToFile(post)
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
        
        // 📁 파일도 업데이트
        syncCommentsToFile(postId: postId)
    }

    /// 게시글 삭제
    func removeCommunityPost(_ postId: UUID) {
        coordinator.company.communityPosts.removeAll { $0.id == postId }
        coordinator.saveCompany()
    }
    
    // MARK: - 회의 (Conversations)
    
    /// 회의 시작
    func startConversation(topic: String, project: String?, participants: [String], initiator: String) -> CommunityConversation {
        fileService.startConversation(
            topic: topic,
            project: project,
            participants: participants,
            initiator: initiator
        )
    }
    
    /// 회의에 메시지 추가
    func addMessageToConversation(_ conversationId: String, author: String, department: String, content: String) {
        let message = ConversationMessage(
            id: UUID().uuidString,
            author: author,
            department: department,
            content: content,
            timestamp: Date()
        )
        try? fileService.addMessage(to: conversationId, message: message)
    }
    
    /// 회의 종료
    func endConversation(_ conversationId: String, summary: String?) {
        try? fileService.endConversation(id: conversationId, summary: summary)
    }
    
    /// 진행 중인 회의 목록
    var activeConversations: [CommunityConversation] {
        fileService.getActiveConversations()
    }
    
    /// 모든 회의 목록
    var allConversations: [CommunityConversation] {
        fileService.listConversations()
    }
    
    /// 특정 회의 조회
    func getConversation(id: String) -> CommunityConversation? {
        fileService.getConversation(id: id)
    }
    
    // MARK: - 파일에서 게시글 로드
    
    /// 파일에서 게시글 불러오기 (앱 시작 시 동기화)
    func loadPostsFromFiles() {
        let thoughts = fileService.listThoughts()
        print("📁 [CommunityStore] 파일에서 \(thoughts.count)개 생각 글 발견")
        
        for thought in thoughts {
            // 이미 앱에 있는지 확인 (제목+작성자로 중복 체크)
            let exists = coordinator.company.communityPosts.contains {
                $0.title == thought.title && $0.employeeName == thought.author
            }
            
            if !exists {
                // 파일에서 불러온 게시글 추가
                let post = CommunityPost(
                    employeeId: UUID(uuidString: thought.authorId) ?? UUID(),
                    employeeName: thought.author,
                    departmentType: DepartmentType(rawValue: thought.department) ?? .general,
                    thinkingId: nil,
                    title: thought.title,
                    content: thought.content,
                    summary: String(thought.content.prefix(100)),
                    tags: thought.tags,
                    source: .manual,
                    likes: 0,
                    comments: thought.comments.map { comment in
                        PostComment(
                            id: UUID(uuidString: comment.id) ?? UUID(),
                            employeeId: UUID(uuidString: comment.authorId) ?? UUID(),
                            employeeName: comment.author,
                            content: comment.content,
                            createdAt: comment.created
                        )
                    },
                    createdAt: thought.created
                )
                coordinator.company.communityPosts.append(post)
                print("📥 [CommunityStore] 파일에서 로드: \(thought.title)")
            }
        }
        
        coordinator.saveCompany()
    }

    // MARK: - 자동 댓글

    /// 랜덤 직원들이 게시글에 댓글 추가
    private func addRandomComments(to postId: UUID, count: Int) {
        guard let post = coordinator.company.communityPosts.first(where: { $0.id == postId }) else { return }

        // 모든 직원 수집 (회사 + 프로젝트)
        var allEmployees: [(id: UUID, name: String, dept: DepartmentType)] = []

        for dept in coordinator.company.departments {
            for emp in dept.employees {
                allEmployees.append((emp.id, emp.name, dept.type))
            }
        }
        for project in coordinator.company.projects {
            for dept in project.departments {
                for emp in dept.employees {
                    allEmployees.append((emp.id, emp.name, emp.departmentType))
                }
            }
        }

        guard !allEmployees.isEmpty else {
            print("💬 [AutoComment] 댓글을 달 직원이 없습니다")
            return
        }

        // 게시글 작성자 제외하고 셔플
        let availableEmployees = allEmployees.filter { $0.id != post.employeeId }.shuffled()
        let commenters = availableEmployees.prefix(min(count, availableEmployees.count))

        for employee in commenters {
            let templates = commentTemplates[employee.dept] ?? commentTemplates[.general]!
            if let commentContent = templates.randomElement() {
                let comment = PostComment(
                    employeeId: employee.id,
                    employeeName: employee.name,
                    content: commentContent
                )

                // 직접 추가 (재귀 방지)
                if let index = coordinator.company.communityPosts.firstIndex(where: { $0.id == postId }) {
                    coordinator.company.communityPosts[index].comments.append(comment)
                }
            }
        }

        if !commenters.isEmpty {
            coordinator.saveCompany()
            print("💬 [AutoComment] '\(post.title.prefix(20))...'에 \(commenters.count)개 댓글 추가됨")
        }
    }
}
