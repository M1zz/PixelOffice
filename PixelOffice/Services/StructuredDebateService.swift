import Foundation
import Combine

/// 구조화된 토론 서비스
/// AI 직원들이 4단계 토론을 통해 인사이트를 도출
@MainActor
class StructuredDebateService: ObservableObject {
    static let shared = StructuredDebateService()

    @Published var activeDebates: [Debate] = []
    @Published var debateHistory: [Debate] = []
    @Published var isRunning: Bool = false
    @Published var currentError: String?

    private let claudeService = ClaudeService()
    private let claudeCodeService = ClaudeCodeService()
    private weak var companyStore: CompanyStore?

    private init() {}

    /// CompanyStore 설정 (앱 시작 시 호출)
    func setCompanyStore(_ store: CompanyStore) {
        self.companyStore = store
        print("✅ [토론] CompanyStore 연결 완료")
    }

    // MARK: - 토론 생성

    /// 새 토론 생성
    func createDebate(
        topic: String,
        context: String = "",
        participants: [DebateParticipant],
        projectId: UUID? = nil,
        settings: DebateSettings = DebateSettings()
    ) -> Debate {
        let debate = Debate(
            topic: topic,
            context: context,
            projectId: projectId,
            participants: participants,
            phases: [],
            currentPhaseType: .topic,
            status: .preparing,
            settings: settings
        )

        activeDebates.append(debate)
        print("📋 [토론] 새 토론 생성: \"\(topic)\" — 참여자 \(participants.count)명")
        return debate
    }

    /// 회사 직원으로부터 참여자 생성
    func makeParticipant(from employee: Employee, departmentType: DepartmentType) -> DebateParticipant {
        DebateParticipant(
            employeeId: employee.id,
            employeeName: employee.name,
            departmentType: departmentType,
            aiType: employee.aiType,
            personality: employee.personality,
            strengths: employee.strengths
        )
    }

    /// 프로젝트 직원으로부터 참여자 생성
    func makeParticipant(from employee: ProjectEmployee, projectId: UUID) -> DebateParticipant {
        DebateParticipant(
            employeeId: employee.id,
            employeeName: employee.name,
            departmentType: employee.departmentType,
            aiType: employee.aiType,
            personality: employee.personality,
            strengths: employee.strengths,
            isProjectEmployee: true,
            projectId: projectId
        )
    }

    // MARK: - 토론 실행

    /// 토론 전체 실행 (Phase 1 → 4 자동 진행)
    func runDebate(_ debateId: UUID) async {
        guard var debate = activeDebates.first(where: { $0.id == debateId }) else {
            print("❌ [토론] 토론을 찾을 수 없습니다: \(debateId)")
            return
        }

        guard let companyStore = self.companyStore else {
            print("❌ [토론] CompanyStore가 설정되지 않았습니다")
            updateDebateStatus(debateId, status: .failed)
            return
        }

        isRunning = true
        currentError = nil
        updateDebateStatus(debateId, status: .inProgress)

        do {
            // Phase 1: 주제 제시
            print("🔵 [토론] Phase 1: 주제 제시 — \"\(debate.topic)\"")
            debate = try await runTopicPhase(debate)
            updateDebate(debate)

            // Phase 2: 독립 의견 수집
            print("🟠 [토론] Phase 2: 독립 의견 수집 — 참여자 \(debate.participants.count)명")
            debate = try await runIndependentOpinionPhase(debate, companyStore: companyStore)
            updateDebate(debate)

            // Phase 3: 교차 검토
            let rounds = debate.settings.crossReviewRounds
            print("🟣 [토론] Phase 3: 교차 검토 — \(rounds)라운드")
            for round in 1...rounds {
                print("   ↳ 라운드 \(round)/\(rounds)")
                debate = try await runCrossReviewPhase(debate, round: round, companyStore: companyStore)
                updateDebate(debate)
            }

            // Phase 4: 종합
            print("🟢 [토론] Phase 4: 종합")
            debate = try await runSynthesisPhase(debate, companyStore: companyStore)
            updateDebate(debate)

            // 완료
            debate.status = .completed
            debate.updatedAt = Date()
            updateDebate(debate)

            // 후처리: 커뮤니티 게시 & 위키 저장
            if debate.settings.autoPostToCommunity {
                postToCommunity(debate, companyStore: companyStore)
            }
            if debate.settings.saveToWiki, let projectId = debate.projectId {
                saveToWiki(debate, projectId: projectId)
            }

            print("✅ [토론] 완료: \"\(debate.topic)\"")

        } catch {
            print("❌ [토론] 실패: \(error.localizedDescription)")
            currentError = error.localizedDescription
            updateDebateStatus(debateId, status: .failed)
        }

        isRunning = false
    }

    /// 토론 취소
    func cancelDebate(_ debateId: UUID) {
        updateDebateStatus(debateId, status: .cancelled)
        isRunning = false
        print("⏹ [토론] 취소됨: \(debateId)")
    }

    // MARK: - Phase 1: 주제 제시

    private func runTopicPhase(_ debate: Debate) async throws -> Debate {
        var debate = debate
        let phase = DebatePhase(
            type: .topic,
            opinions: [],
            completedAt: Date()
        )
        debate.phases.append(phase)
        debate.currentPhaseType = .independentOpinion
        return debate
    }

    // MARK: - Phase 2: 독립 의견

    private func runIndependentOpinionPhase(_ debate: Debate, companyStore: CompanyStore) async throws -> Debate {
        var debate = debate
        var opinions: [DebateOpinion] = []

        // 병렬로 각 참여자의 의견 수집
        try await withThrowingTaskGroup(of: DebateOpinion.self) { group in
            for participant in debate.participants {
                group.addTask { [self] in
                    try await self.generateIndependentOpinion(
                        debate: debate,
                        participant: participant,
                        companyStore: companyStore
                    )
                }
            }

            for try await opinion in group {
                opinions.append(opinion)
            }
        }

        let phase = DebatePhase(
            type: .independentOpinion,
            opinions: opinions,
            completedAt: Date()
        )
        debate.phases.append(phase)
        debate.currentPhaseType = .crossReview
        return debate
    }

    private func generateIndependentOpinion(
        debate: Debate,
        participant: DebateParticipant,
        companyStore: CompanyStore
    ) async throws -> DebateOpinion {
        let systemPrompt = buildParticipantSystemPrompt(participant: participant)

        let prompt = """
        ## 토론 주제

        **\(debate.topic)**

        \(debate.context.isEmpty ? "" : "### 배경\n\(debate.context)\n")

        ## 요청

        당신은 \(participant.departmentType.rawValue)팀 소속 \(participant.employeeName)입니다.
        위 주제에 대해 **당신의 전문 분야 관점에서** 독립적인 의견을 제시해주세요.

        다음 구조로 작성해주세요:
        1. **핵심 주장** (한 줄 요약)
        2. **근거** (2~3가지)
        3. **제안** (구체적인 실행 방안)
        4. **우려사항** (예상되는 리스크나 과제)

        전문가답게 깊이 있되, 간결하게 작성해주세요.
        """

        let result = try await callAI(
            prompt: prompt,
            systemPrompt: systemPrompt,
            participant: participant,
            companyStore: companyStore
        )

        print("   ✅ \(participant.employeeName)(\(participant.departmentType.rawValue)팀) 의견 제출")

        return DebateOpinion(
            participantId: participant.id,
            employeeId: participant.employeeId,
            employeeName: participant.employeeName,
            departmentType: participant.departmentType,
            content: result.response,
            phase: .independentOpinion,
            referencedOpinionIds: [],
            inputTokens: result.inputTokens,
            outputTokens: result.outputTokens
        )
    }

    // MARK: - Phase 3: 교차 검토

    private func runCrossReviewPhase(_ debate: Debate, round: Int, companyStore: CompanyStore) async throws -> Debate {
        var debate = debate

        // 이전 페이즈의 모든 의견 수집
        let previousOpinions = debate.phases.flatMap { $0.opinions }
        var reviewOpinions: [DebateOpinion] = []

        // 병렬로 교차 검토
        try await withThrowingTaskGroup(of: DebateOpinion.self) { group in
            for participant in debate.participants {
                // 자기 의견을 제외한 다른 사람 의견들
                let othersOpinions = previousOpinions.filter { $0.employeeId != participant.employeeId }

                group.addTask { [self] in
                    try await self.generateCrossReview(
                        debate: debate,
                        participant: participant,
                        othersOpinions: othersOpinions,
                        round: round,
                        companyStore: companyStore
                    )
                }
            }

            for try await opinion in group {
                reviewOpinions.append(opinion)
            }
        }

        let phase = DebatePhase(
            type: .crossReview,
            opinions: reviewOpinions,
            completedAt: Date()
        )
        debate.phases.append(phase)

        // 마지막 라운드면 다음 페이즈로
        if round >= debate.settings.crossReviewRounds {
            debate.currentPhaseType = .synthesis
        }

        return debate
    }

    private func generateCrossReview(
        debate: Debate,
        participant: DebateParticipant,
        othersOpinions: [DebateOpinion],
        round: Int,
        companyStore: CompanyStore
    ) async throws -> DebateOpinion {
        let systemPrompt = buildParticipantSystemPrompt(participant: participant)

        let opinionsText = othersOpinions.map { opinion in
            """
            ### \(opinion.employeeName) (\(opinion.departmentType.rawValue)팀)
            \(opinion.content)
            """
        }.joined(separator: "\n\n---\n\n")

        let prompt = """
        ## 토론 주제

        **\(debate.topic)**

        ## 다른 직원들의 의견

        \(opinionsText)

        ## 요청

        당신은 \(participant.departmentType.rawValue)팀 소속 \(participant.employeeName)입니다.
        위 동료들의 의견을 읽고, \(round)차 교차 검토를 수행해주세요.

        다음 구조로 작성해주세요:
        1. **동의하는 부분** — 어떤 의견의 어떤 점에 동의하는지
        2. **반박/보완** — 놓친 관점이나 수정이 필요한 부분
        3. **새로운 제안** — 다른 의견들을 종합해서 떠오른 새 아이디어
        4. **합의 가능한 방향** — 공통 방향성 제안

        건설적이고 구체적으로 작성해주세요.
        """

        let result = try await callAI(
            prompt: prompt,
            systemPrompt: systemPrompt,
            participant: participant,
            companyStore: companyStore
        )

        print("   ✅ \(participant.employeeName)(\(participant.departmentType.rawValue)팀) 교차 검토 완료")

        return DebateOpinion(
            participantId: participant.id,
            employeeId: participant.employeeId,
            employeeName: participant.employeeName,
            departmentType: participant.departmentType,
            content: result.response,
            phase: .crossReview,
            referencedOpinionIds: othersOpinions.map { $0.id },
            inputTokens: result.inputTokens,
            outputTokens: result.outputTokens
        )
    }

    // MARK: - Phase 4: 종합

    private func runSynthesisPhase(_ debate: Debate, companyStore: CompanyStore) async throws -> Debate {
        var debate = debate

        // 모든 의견 수집
        let allOpinions = debate.phases.flatMap { $0.opinions }
        let synthesisText = try await generateSynthesis(debate: debate, allOpinions: allOpinions, companyStore: companyStore)

        // 종합 결과 파싱
        let synthesis = parseSynthesis(synthesisText)

        let phase = DebatePhase(
            type: .synthesis,
            opinions: [],
            completedAt: Date()
        )
        debate.phases.append(phase)
        debate.synthesis = synthesis
        debate.currentPhaseType = .synthesis
        return debate
    }

    private func generateSynthesis(
        debate: Debate,
        allOpinions: [DebateOpinion],
        companyStore: CompanyStore
    ) async throws -> (response: String, inputTokens: Int, outputTokens: Int) {
        // 페이즈별로 의견 정리
        let phase2Opinions = allOpinions.filter { $0.phase == .independentOpinion }
        let phase3Opinions = allOpinions.filter { $0.phase == .crossReview }

        let phase2Text = phase2Opinions.map { "**\($0.employeeName)(\($0.departmentType.rawValue)팀):**\n\($0.content)" }.joined(separator: "\n\n---\n\n")
        let phase3Text = phase3Opinions.map { "**\($0.employeeName)(\($0.departmentType.rawValue)팀):**\n\($0.content)" }.joined(separator: "\n\n---\n\n")

        let prompt = """
        ## 토론 주제

        **\(debate.topic)**

        \(debate.context.isEmpty ? "" : "### 배경\n\(debate.context)\n")

        ## Phase 2: 독립 의견

        \(phase2Text)

        ## Phase 3: 교차 검토

        \(phase3Text)

        ## 요청

        위 토론 내용을 종합하여 **회의록 형태**로 정리해주세요.

        반드시 다음 섹션을 포함하세요:

        ### 핵심 요약
        (3줄 이내로 토론 결과 요약)

        ### 합의 사항
        - (모든 참여자가 동의한 내용들)

        ### 쟁점 사항
        - (의견이 갈린 부분들, 각자의 입장 포함)

        ### 액션 아이템
        - [담당부서] 항목 설명 (우선순위: 높음/보통/낮음)

        ### 핵심 인사이트
        - (이번 토론에서 나온 가장 가치 있는 인사이트들)

        ### 리스크
        - (주의해야 할 리스크나 과제들)

        한국어로 작성해주세요.
        """

        let systemPrompt = "당신은 회의 내용을 정리하는 전문 퍼실리테이터입니다. 토론의 핵심을 놓치지 않고, 모든 참여자의 관점을 공정하게 반영합니다."

        // 종합은 첫 번째 참여자의 AI 타입 사용 (또는 기본 Claude)
        let aiType = debate.participants.first?.aiType ?? .claude
        if let apiConfig = companyStore.getAPIConfiguration(for: aiType) {
            let sessionId = UUID()
            await claudeService.createSession(for: sessionId)

            return try await claudeService.sendMessage(
                prompt,
                employeeId: sessionId,
                configuration: apiConfig,
                systemPrompt: systemPrompt
            )
        }

        // API 없으면 Claude Code CLI 폴백
        guard await claudeCodeService.isClaudeCodeAvailable() else {
            throw APIError.notConfigured
        }

        let response = try await claudeCodeService.sendMessage(prompt, systemPrompt: systemPrompt)
        return (response: response, inputTokens: 0, outputTokens: 0)
    }

    /// 종합 텍스트에서 구조화된 데이터 파싱
    private func parseSynthesis(_ result: (response: String, inputTokens: Int, outputTokens: Int)) -> DebateSynthesis {
        let text = result.response

        // 섹션별 파싱
        let summary = extractSection(from: text, header: "핵심 요약") ?? "요약을 추출하지 못했습니다."
        let agreements = extractListItems(from: text, header: "합의 사항")
        let disagreements = extractListItems(from: text, header: "쟁점 사항")
        let actionItemTexts = extractListItems(from: text, header: "액션 아이템")
        let insights = extractListItems(from: text, header: "핵심 인사이트")
        let risks = extractListItems(from: text, header: "리스크")

        // 액션 아이템 파싱
        let actionItems = actionItemTexts.map { text -> DebateActionItem in
            let priority: ActionPriority
            if text.contains("높음") { priority = .high }
            else if text.contains("낮음") { priority = .low }
            else { priority = .medium }

            // [부서명] 형태에서 부서 추출
            var department: DepartmentType?
            for dept in DepartmentType.allCases {
                if text.contains("[\(dept.rawValue)]") || text.contains(dept.rawValue) {
                    department = dept
                    break
                }
            }

            return DebateActionItem(
                title: text.replacingOccurrences(of: "\\[.*?\\]", with: "", options: .regularExpression).trimmingCharacters(in: .whitespaces),
                description: text,
                assignedDepartment: department,
                priority: priority
            )
        }

        return DebateSynthesis(
            summary: summary,
            agreements: agreements,
            disagreements: disagreements,
            actionItems: actionItems,
            risks: risks,
            keyInsights: insights,
            inputTokens: result.inputTokens,
            outputTokens: result.outputTokens
        )
    }

    // MARK: - AI 호출

    private func callAI(
        prompt: String,
        systemPrompt: String,
        participant: DebateParticipant,
        companyStore: CompanyStore
    ) async throws -> (response: String, inputTokens: Int, outputTokens: Int) {
        // API 설정이 있으면 기존대로 ClaudeService 사용
        if let apiConfig = companyStore.getAPIConfiguration(for: participant.aiType) {
            let sessionId = UUID()
            await claudeService.createSession(for: sessionId)

            return try await claudeService.sendMessage(
                prompt,
                employeeId: sessionId,
                configuration: apiConfig,
                systemPrompt: systemPrompt
            )
        }

        // API 없으면 Claude Code CLI 폴백
        guard await claudeCodeService.isClaudeCodeAvailable() else {
            throw APIError.notConfigured
        }

        let response = try await claudeCodeService.sendMessage(prompt, systemPrompt: systemPrompt)
        return (response: response, inputTokens: 0, outputTokens: 0)
    }

    private func buildParticipantSystemPrompt(participant: DebateParticipant) -> String {
        """
        당신의 이름은 \(participant.employeeName)입니다.
        당신은 \(participant.departmentType.rawValue)팀 소속 10년차 전문가입니다.

        성격: \(participant.personality)
        강점: \(participant.strengths.joined(separator: ", "))

        중요한 규칙:
        - 한국어로 대화합니다
        - 전문적이지만 친근하게 작성합니다
        - 당신의 전문 분야 관점에서 깊이 있는 의견을 제시합니다
        - 다른 부서의 관점도 존중하되, 당신만의 시각을 분명히 합니다
        - 구체적인 근거와 실행 방안을 포함합니다
        """
    }

    // MARK: - 텍스트 파싱 헬퍼

    private func extractSection(from text: String, header: String) -> String? {
        let pattern = "###?\\s*\(header)\\s*\n([\\s\\S]*?)(?=\n###?\\s|$)"
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractListItems(from text: String, header: String) -> [String] {
        guard let section = extractSection(from: text, header: header) else { return [] }
        return section
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("-") || $0.hasPrefix("•") || $0.hasPrefix("*") }
            .map { String($0.dropFirst()).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: - 상태 업데이트

    private func updateDebate(_ debate: Debate) {
        if let index = activeDebates.firstIndex(where: { $0.id == debate.id }) {
            activeDebates[index] = debate
        }
    }

    private func updateDebateStatus(_ debateId: UUID, status: DebateStatus) {
        if let index = activeDebates.firstIndex(where: { $0.id == debateId }) {
            activeDebates[index].status = status
            activeDebates[index].updatedAt = Date()

            if status == .completed || status == .failed || status == .cancelled {
                let debate = activeDebates.remove(at: index)
                debateHistory.append(debate)
            }
        }
    }

    // MARK: - 후처리

    /// 커뮤니티에 토론 결과 게시
    private func postToCommunity(_ debate: Debate, companyStore: CompanyStore) {
        guard let synthesis = debate.synthesis else { return }

        let participantNames = debate.participants.map { $0.employeeName }.joined(separator: ", ")

        let content = """
        ## 핵심 요약

        \(synthesis.summary)

        ## 합의 사항

        \(synthesis.agreements.map { "- \($0)" }.joined(separator: "\n"))

        ## 핵심 인사이트

        \(synthesis.keyInsights.map { "- \($0)" }.joined(separator: "\n"))

        ## 액션 아이템

        \(synthesis.actionItems.map { "- [\($0.priority.rawValue)] \($0.title)" }.joined(separator: "\n"))

        ---
        참여: \(participantNames)
        """

        let post = CommunityPost(
            employeeId: debate.participants.first?.employeeId ?? UUID(),
            employeeName: participantNames,
            departmentType: debate.participants.first?.departmentType ?? .general,
            title: "🏛️ 토론: \(debate.topic)",
            content: content,
            summary: synthesis.summary,
            tags: ["토론"] + debate.participants.map { $0.departmentType.rawValue },
            source: .debate,
            createdAt: Date()
        )

        companyStore.addCommunityPost(post)
        print("📝 [토론] 커뮤니티 게시 완료: \(debate.topic)")
    }

    /// 위키에 회의록 저장
    private func saveToWiki(_ debate: Debate, projectId: UUID) {
        guard let synthesis = debate.synthesis else { return }
        guard let companyStore = self.companyStore,
              let project = companyStore.company.projects.first(where: { $0.id == projectId }) else { return }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: debate.createdAt)

        let participantNames = debate.participants.map { "\($0.employeeName)(\($0.departmentType.rawValue))" }.joined(separator: ", ")

        // 모든 의견 포함한 전체 회의록
        var fullMinutes = """
        # 🏛️ 토론: \(debate.topic)

        - **일시**: \(dateStr)
        - **참여자**: \(participantNames)
        - **상태**: \(debate.status.rawValue)

        ---

        ## 핵심 요약

        \(synthesis.summary)

        ## 합의 사항

        \(synthesis.agreements.map { "- \($0)" }.joined(separator: "\n"))

        ## 쟁점 사항

        \(synthesis.disagreements.map { "- \($0)" }.joined(separator: "\n"))

        ## 액션 아이템

        \(synthesis.actionItems.map { "- **[\($0.priority.rawValue)]** \($0.title)" }.joined(separator: "\n"))

        ## 핵심 인사이트

        \(synthesis.keyInsights.map { "- \($0)" }.joined(separator: "\n"))

        ## 리스크

        \(synthesis.risks.map { "- \($0)" }.joined(separator: "\n"))

        ---

        ## 상세 토론 내용

        """

        // 페이즈별 의견 추가
        for phase in debate.phases {
            if phase.opinions.isEmpty { continue }
            fullMinutes += "\n### \(phase.type.rawValue)\n\n"
            for opinion in phase.opinions {
                fullMinutes += "#### \(opinion.employeeName) (\(opinion.departmentType.rawValue)팀)\n\n"
                fullMinutes += opinion.content + "\n\n"
            }
        }

        // 파일 저장
        let wikiPath = DataPathService.shared.projectWikiPath(project.name)
        let fileName = "\(dateStr)-토론-\(debate.topic.prefix(20)).md"
        let filePath = (wikiPath as NSString).appendingPathComponent(fileName)

        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: wikiPath) {
            try? fileManager.createDirectory(atPath: wikiPath, withIntermediateDirectories: true)
        }
        try? fullMinutes.write(toFile: filePath, atomically: true, encoding: .utf8)

        print("📄 [토론] 위키 저장 완료: \(filePath)")
    }

    // MARK: - 통계

    /// 총 토큰 사용량
    func totalTokenUsage(for debate: Debate) -> (input: Int, output: Int) {
        let allOpinions = debate.phases.flatMap { $0.opinions }
        let opinionInput = allOpinions.reduce(0) { $0 + $1.inputTokens }
        let opinionOutput = allOpinions.reduce(0) { $0 + $1.outputTokens }
        let synthInput = debate.synthesis?.inputTokens ?? 0
        let synthOutput = debate.synthesis?.outputTokens ?? 0
        return (opinionInput + synthInput, opinionOutput + synthOutput)
    }
}
