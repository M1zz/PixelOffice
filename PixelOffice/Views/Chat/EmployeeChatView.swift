import SwiftUI

/// 직원과의 대화 화면
struct EmployeeChatView: View {
    let employee: Employee
    @EnvironmentObject var companyStore: CompanyStore
    @Environment(\.dismiss) private var dismiss

    @State private var inputText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var messages: [ChatMessage] = []
    @State private var useClaudeCode = true  // Claude Code CLI 사용 여부
    @State private var currentThinking: EmployeeThinking?  // 현재 사고 과정
    @State private var loadingStartTime: Date?  // 로딩 시작 시간
    @State private var showPermissionHistory = false  // 권한 요청 히스토리 표시

    private let claudeService = ClaudeService()
    private let claudeCodeService = ClaudeCodeService()

    var apiConfig: APIConfiguration? {
        companyStore.getAPIConfiguration(for: employee.aiType)
    }

    /// Claude Code CLI 사용 가능 여부 (Claude 타입만)
    var canUseClaudeCode: Bool {
        employee.aiType == .claude
    }

    /// 직원이 속한 부서 찾기
    var employeeDepartment: Department? {
        companyStore.company.departments.first { dept in
            dept.employees.contains { $0.id == employee.id }
        }
    }

    /// 부서 타입 (없으면 general)
    var departmentType: DepartmentType {
        employeeDepartment?.type ?? .general
    }

    /// 부서별 문서 폴더 경로 (전사 공용)
    var departmentDocumentsPath: String {
        let basePath = DataPathService.shared.basePath
        let deptDir = departmentType.directoryName
        let path = "\(basePath)/_shared/\(deptDir)/documents"
        DataPathService.shared.createDirectoryIfNeeded(at: path)
        return path
    }

    /// 부서별 전문가 역할이 반영된 시스템 프롬프트 (커스터마이징 가능)
    var customSkills: DepartmentSkillSet {
        companyStore.getDepartmentSkills(for: departmentType)
    }

    /// 이전 업무 기록 요약
    var workLogSummary: String {
        EmployeeWorkLogService.shared.getWorkLogSummary(for: employee.id, employeeName: employee.name)
    }

    /// 문서 경로 정보
    var documentsInfo: String {
        let basePath = "datas/_shared"
        let deptDir = departmentType.directoryName

        return """
        ## 📁 문서 경로
        당신이 작성한 문서는 다음 경로에 자동 저장됩니다:
        - 부서 문서: \(basePath)/\(deptDir)/documents/
        - 직원 프로필: \(basePath)/people/

        ## 📚 참고할 수 있는 문서
        다른 부서의 문서도 참고할 수 있습니다:
        - 기획팀: \(basePath)/기획/documents/
        - 디자인팀: \(basePath)/디자인/documents/
        - 개발팀: \(basePath)/개발/documents/
        - QA팀: \(basePath)/QA/documents/
        - 마케팅팀: \(basePath)/마케팅/documents/

        ## ⚠️ 중요: 문서 작성 전 필수 확인
        문서를 작성하기 전에 반드시 해당 프로젝트의 README.md 파일을 읽어주세요.
        README.md에는 문서 구조, 명명 규칙, 부서별 문서 형식이 정의되어 있습니다.
        이 가이드를 따라야 팀 전체가 일관된 문서 체계를 유지할 수 있습니다.
        """
    }

    /// 부서별 전문가 역할이 반영된 시스템 프롬프트
    var systemPrompt: String {
        """
        당신의 이름은 \(employee.name)입니다.
        당신은 \(departmentType.rawValue)팀 소속입니다.

        \(documentsInfo)

        \(customSkills.fullPrompt)

        중요한 규칙:
        - 한국어로 대화합니다
        - 전문적이지만 친근하게 대화합니다
        - 질문할 때는 구체적이고 실무적인 질문을 합니다
        - 답변할 때는 10년 경력의 전문가답게 깊이 있는 인사이트를 제공합니다

        \(AIActionGuide.guide)

        \(workLogSummary)

        📄 문서 작성 기능:
        문서를 작성해달라는 요청을 받으면, 다음 형식으로 마크다운 문서를 작성하세요:

        <<<FILE:파일명.md>>>
        (여기에 마크다운 내용)
        <<<END_FILE>>>

        예시:
        <<<FILE:프로젝트-기획서.md>>>
        # 프로젝트 기획서
        ## 개요
        ...
        <<<END_FILE>>>

        문서 작성 후에는 간단히 어떤 문서를 만들었는지 설명해주세요.

        ⚠️ 중요: 파일이나 문서를 작성할 때 사용자에게 미리 물어보지 말고 바로 작성하세요.
        권한은 이미 승인되어 있으므로, 필요한 파일은 즉시 생성하면 됩니다.
        "권한이 필요합니다" 같은 메시지 없이 바로 작업을 진행하세요.

        📝 업무 결과 문서화:
        사용자가 "문서화해줘", "정리해줘", "위키에 작성해줘", "결과물 작성" 등을 요청하면:
        1. 지금까지 대화에서 논의된 핵심 내용을 정리
        2. 결정된 사항, 액션 아이템, 주요 인사이트 포함
        3. 부서 특성에 맞는 문서 형식 사용:
           - 기획팀: PRD, 기획서, 요구사항 정의서
           - 디자인팀: 디자인 가이드, UI/UX 명세서
           - 개발팀: 기술 명세서, API 문서, 아키텍처 설계서
           - QA팀: 테스트 계획서, QA 리포트
           - 마케팅팀: 마케팅 전략, 캠페인 기획서
        4. 반드시 <<<FILE:파일명.md>>>...<<<END_FILE>>> 형식으로 작성하여 위키에 자동 저장되도록 함

        🤝 다른 부서에 협업 요청:
        다른 부서의 도움이 필요하면 멘션을 사용하세요:
        - @기획팀: 기획 관련 질문이나 요청
        - @디자인팀: 디자인 관련 질문이나 요청
        - @개발팀: 개발/기술 관련 질문이나 요청
        - @QA팀: 테스트/품질 관련 질문이나 요청
        - @마케팅팀: 마케팅 관련 질문이나 요청

        멘션 형식:
        <<<MENTION:@부서명>>>
        [요청 내용을 구체적으로 작성]
        <<<END_MENTION>>>

        예시:
        <<<MENTION:@개발팀>>>
        이 기능의 기술적 구현 가능성과 예상 일정을 알려주세요.
        <<<END_MENTION>>>

        다른 부서의 응답은 자동으로 전달됩니다.

        💭 인사이트 축적 기능:
        대화 중 중요한 정보나 인사이트를 발견하면 다음 형식으로 기록하세요:

        <<<INSIGHT>>>
        (발견한 핵심 인사이트나 중요 정보)
        <<<END_INSIGHT>>>

        인사이트를 기록할 때:
        - 비즈니스에 영향을 주는 중요한 정보일 때
        - 의사결정에 도움이 될 패턴이나 트렌드를 발견했을 때
        - 여러 정보를 종합해서 새로운 결론에 도달했을 때
        - 사용자가 제공한 중요한 수치나 데이터를 받았을 때

        충분한 인사이트가 모이면 자동으로 커뮤니티에 게시됩니다.
        """
    }

    /// 현재 사고 과정 상태
    var thinkingStatus: String {
        guard let thinking = currentThinking else { return "" }
        return "💭 \(thinking.reasoning.keyInsights.count)개 인사이트 축적 중 (준비도: \(thinking.reasoning.readinessScore)/10)"
    }

    /// 회사 내 모든 부서 목록 (멘션용)
    var availableDepartments: [DepartmentType] {
        companyStore.company.departments.map { $0.type }
    }

    /// 첫 인사 시 물어볼 질문 (부서별로 다름)
    var greetingQuestion: String {
        let questions = departmentType.onboardingQuestions
        // 직원 ID를 기반으로 일관된 질문 선택 (같은 직원은 항상 같은 질문)
        let index = abs(employee.id.hashValue) % questions.count
        return questions[index]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            ChatHeader(
                employee: employee,
                thinkingStatus: currentThinking != nil ? "💭 \(currentThinking!.reasoning.keyInsights.count)개 인사이트 (준비도: \(currentThinking!.reasoning.readinessScore)/10)" : nil,
                pendingPermissionCount: companyStore.company.permissionRequests.filter { $0.employeeId == employee.id && $0.status == .pending }.count,
                onClose: { dismiss() },
                onClearConversation: { clearConversation() },
                onDocumentize: { requestDocumentize() },
                onShowPermissions: { showPermissionHistory = true }
            )

            Divider()

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            ChatBubble(message: message, aiType: employee.aiType)
                        }

                        // 권한 요청 카드 표시
                        let pendingRequests = companyStore.company.permissionRequests.filter { $0.employeeId == employee.id && $0.status == .pending }
                        let _ = print("🎨 [UI] 권한 카드 필터링 결과: \(pendingRequests.count)개 (전체 \(companyStore.company.permissionRequests.count)개 중)")
                        let _ = print("   - 현재 직원 ID: \(employee.id)")
                        let _ = print("   - 이 직원의 모든 권한 요청: \(companyStore.company.permissionRequests.filter { $0.employeeId == employee.id }.count)개")

                        ForEach(pendingRequests) { request in
                            PermissionRequestCard(
                                request: request,
                                onApprove: { reason in
                                    handlePermissionApproval(request.id, reason: reason)
                                },
                                onDeny: { reason in
                                    handlePermissionDenial(request.id, reason: reason)
                                }
                            )
                            .padding(.horizontal)
                            .onAppear {
                                print("🎨 [UI] 권한 카드 표시됨: \(request.title)")
                            }
                        }

                        if isLoading {
                            AIThinkingIndicator(
                                departmentType: departmentType,
                                employeeName: employee.name,
                                startTime: loadingStartTime ?? Date(),
                                userMessage: messages.last(where: { $0.role == .user })?.content
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _, _ in
                    if let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Error message
            if let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.body)
                    Spacer()
                    Button("닫기") {
                        errorMessage = nil
                    }
                    .font(.body)
                }
                .padding(10)
                .background(Color.orange.opacity(0.1))
            }

            Divider()

            // Input
            ChatInputView(
                text: $inputText,
                isLoading: isLoading,
                isConfigured: (canUseClaudeCode && useClaudeCode) || (apiConfig?.isConfigured ?? false),
                availableDepartments: availableDepartments,
                onSend: sendMessage
            )
        }
        .frame(width: 500, height: 600)
        .sheet(isPresented: $showPermissionHistory) {
            PermissionRequestHistoryView(employeeId: employee.id)
                .environmentObject(companyStore)
        }
        .onAppear {
            // 기존 대화 기록 로드
            messages = employee.conversationHistory.map { msg in
                ChatMessage(
                    role: msg.role == .user ? .user : .assistant,
                    content: msg.content
                )
            }

            // 기존 사고 과정 로드
            currentThinking = companyStore.getActiveThinking(employeeId: employee.id)

            // 대화 기록이 없으면 AI가 먼저 인사
            if messages.isEmpty {
                sendGreeting()
            }
        }
    }

    /// AI 직원이 먼저 인사하는 함수
    private func sendGreeting() {
        isLoading = true
        loadingStartTime = Date()
        companyStore.updateEmployeeStatus(employee.id, status: .thinking)  // 생각중으로 변경

        let greetingPrompt = """
        당신은 방금 새로운 팀에 합류했고, 사용자(당신의 상사/PM)가 대화창을 열었습니다.

        다음 형식으로 인사하세요:
        1. 짧은 자기소개 (이름, 역할, 1문장)
        2. 업무 시작을 위해 꼭 알아야 할 질문 하나

        반드시 다음 질문을 포함하세요:
        "\(greetingQuestion)"

        전체 3-4문장으로 짧고 전문적으로 작성하세요.
        """

        Task {
            do {
                let response: String
                var inputTokens = 0
                var outputTokens = 0

                // Claude 타입이면 Claude Code CLI 먼저 시도
                if canUseClaudeCode && useClaudeCode {
                    response = try await claudeCodeService.sendMessage(
                        greetingPrompt,
                        systemPrompt: systemPrompt
                    )
                    // ClaudeCodeService는 아직 토큰 정보를 반환하지 않음
                } else if let config = apiConfig, config.isConfigured {
                    // 그 외에는 직접 API 호출
                    let result = try await claudeService.sendMessage(
                        greetingPrompt,
                        employeeId: employee.id,
                        configuration: config,
                        systemPrompt: systemPrompt,
                        isGreeting: true
                    )
                    response = result.response
                    inputTokens = result.inputTokens
                    outputTokens = result.outputTokens
                } else {
                    throw ClaudeCodeError.notInstalled
                }

                await MainActor.run {
                    let assistantMessage = ChatMessage(role: .assistant, content: response)
                    messages.append(assistantMessage)
                    isLoading = false
                    companyStore.updateEmployeeStatus(employee.id, status: .idle)  // 휴식중으로 변경

                    // 토큰 사용량 업데이트 (API 직접 호출인 경우만)
                    if inputTokens > 0 || outputTokens > 0 {
                        companyStore.updateEmployeeTokenUsage(employee.id, inputTokens: inputTokens, outputTokens: outputTokens)
                    }

                    saveConversation()
                }
            } catch {
                await MainActor.run {
                    // 오류 시 기본 인사 표시
                    let greeting = "안녕하세요! \(employee.name)입니다. 무엇을 도와드릴까요?"
                    messages.append(ChatMessage(role: .assistant, content: greeting))
                    errorMessage = error.localizedDescription
                    isLoading = false
                    companyStore.updateEmployeeStatus(employee.id, status: .idle)  // 휴식중으로 변경
                }
            }
        }
    }

    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // Claude Code 사용 가능 여부 또는 API 설정 확인
        let hasClaudeCode = canUseClaudeCode && useClaudeCode
        let hasAPIConfig = apiConfig?.isConfigured ?? false

        guard hasClaudeCode || hasAPIConfig else {
            errorMessage = "Claude Code가 설치되어 있지 않거나, API가 설정되지 않았습니다."
            return
        }

        let userMessage = ChatMessage(role: .user, content: inputText)
        messages.append(userMessage)
        let messageToSend = inputText
        inputText = ""
        isLoading = true
        loadingStartTime = Date()
        errorMessage = nil
        companyStore.updateEmployeeStatus(employee.id, status: .thinking)  // 생각중으로 변경

        Task {
            do {
                let response: String
                var inputTokens = 0
                var outputTokens = 0

                // Claude 타입이면 Claude Code CLI 먼저 시도
                if hasClaudeCode {
                    response = try await claudeCodeService.sendMessage(
                        messageToSend,
                        systemPrompt: systemPrompt,
                        conversationHistory: employee.conversationHistory
                    )
                    // ClaudeCodeService는 아직 토큰 정보를 반환하지 않음
                } else if let config = apiConfig, config.isConfigured {
                    // 그 외에는 직접 API 호출
                    let result = try await claudeService.sendMessage(
                        messageToSend,
                        employeeId: employee.id,
                        configuration: config,
                        systemPrompt: systemPrompt
                    )
                    response = result.response
                    inputTokens = result.inputTokens
                    outputTokens = result.outputTokens
                } else {
                    throw ClaudeCodeError.notInstalled
                }

                // ✨ AI 액션 파싱 및 실행
                let actions = await AIActionParser.shared.parseActions(from: response)
                var actionResults: [String] = []

                if !actions.isEmpty {
                    await AIActionParser.shared.executeActions(
                        actions,
                        projectId: nil,  // 회사 직원은 프로젝트 ID 없음
                        employeeId: employee.id,
                        companyStore: companyStore
                    )

                    // 실행된 액션 요약
                    for action in actions {
                        switch action {
                        case .createWiki(let title, _, _):
                            actionResults.append("📄 위키 문서 생성: \(title)")
                        case .createTask(let title, _, _, _, _):
                            actionResults.append("✅ 태스크 추가: \(title)")
                        case .mention(_, let targetName, _):
                            actionResults.append("🔔 멘션: @\(targetName)")
                        case .createCollaboration(let title, _, _, _):
                            actionResults.append("🤝 협업 기록: \(title)")
                        }
                    }
                }

                // 응답에서 파일 추출 및 저장 (기존 로직)
                let (fileCleanedResponse, savedFiles) = await MainActor.run {
                    extractAndSaveFiles(from: response)
                }

                // 응답에서 인사이트 추출 및 사고 과정 업데이트
                let insightCleanedResponse = await MainActor.run {
                    extractAndProcessInsights(from: fileCleanedResponse, userMessage: messageToSend)
                }

                // 응답에서 멘션 추출 및 처리
                let (cleanedResponse, mentionResponses) = await extractAndProcessMentions(from: insightCleanedResponse)

                await MainActor.run {
                    let assistantMessage = ChatMessage(role: .assistant, content: cleanedResponse)
                    messages.append(assistantMessage)

                    // 액션 실행 결과 표시
                    if !actionResults.isEmpty {
                        let actionMessage = ChatMessage(
                            role: .system,
                            content: "🛠️ 실행된 작업:\n" + actionResults.map { "  • \($0)" }.joined(separator: "\n")
                        )
                        messages.append(actionMessage)
                    }

                    // 저장된 파일이 있으면 알림
                    if !savedFiles.isEmpty {
                        let fileNames = savedFiles.joined(separator: ", ")
                        let fileMessage = ChatMessage(role: .assistant, content: "📄 문서가 저장되었습니다: \(fileNames)\n위치: datas/_shared/wiki/")
                        messages.append(fileMessage)
                    }

                    // 멘션 응답이 있으면 표시
                    for mentionResponse in mentionResponses {
                        let mentionMessage = ChatMessage(role: .assistant, content: mentionResponse)
                        messages.append(mentionMessage)
                    }

                    isLoading = false
                    companyStore.updateEmployeeStatus(employee.id, status: .idle)

                    // 토큰 사용량 업데이트 (API 직접 호출인 경우만)
                    if inputTokens > 0 || outputTokens > 0 {
                        companyStore.updateEmployeeTokenUsage(employee.id, inputTokens: inputTokens, outputTokens: outputTokens)
                    }

                    // 대화 기록 저장
                    saveConversation()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                    companyStore.updateEmployeeStatus(employee.id, status: .idle)  // 휴식중으로 변경
                }
            }
        }
    }

    /// 부서 타입에 따른 위키 카테고리
    var wikiCategory: WikiCategory {
        switch departmentType {
        case .planning:
            return .projectDocs
        case .design:
            return .guidelines
        case .development:
            return .guidelines
        case .qa:
            return .projectDocs
        case .marketing:
            return .companyInfo
        case .general:
            return .reference
        }
    }

    /// AI 응답에서 파일을 추출하고 저장
    private func extractAndSaveFiles(from response: String) -> (cleanedResponse: String, savedFiles: [String]) {
        var cleanedResponse = response
        var savedFiles: [String] = []

        // <<<FILE:파일명.md>>> ... <<<END_FILE>>> 패턴 찾기
        let pattern = "<<<FILE:([^>]+)>>>([\\s\\S]*?)<<<END_FILE>>>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return (response, [])
        }

        let nsString = response as NSString
        let matches = regex.matches(in: response, options: [], range: NSRange(location: 0, length: nsString.length))

        for match in matches.reversed() {
            guard match.numberOfRanges >= 3 else { continue }

            let fileNameRange = match.range(at: 1)
            let contentRange = match.range(at: 2)
            let fullRange = match.range(at: 0)

            let fileName = nsString.substring(with: fileNameRange).trimmingCharacters(in: .whitespaces)
            let content = nsString.substring(with: contentRange).trimmingCharacters(in: .whitespacesAndNewlines)

            // WikiDocument 생성
            let document = WikiDocument(
                title: (fileName as NSString).deletingPathExtension.replacingOccurrences(of: "-", with: " "),
                content: content,
                category: wikiCategory,
                createdBy: "\(departmentType.rawValue)팀",
                tags: [employee.name],
                fileName: fileName
            )

            // 부서별 documents 폴더에 저장
            do {
                let deptDocsFilePath = (departmentDocumentsPath as NSString).appendingPathComponent(fileName)
                try content.write(toFile: deptDocsFilePath, atomically: true, encoding: .utf8)
                savedFiles.append(fileName)

                // CompanyStore에 등록 (앱 내에서 문서 목록 표시용)
                companyStore.addWikiDocument(document)
            } catch {
                print("파일 저장 실패: \(error)")
            }

            // 응답에서 파일 블록 제거
            cleanedResponse = (cleanedResponse as NSString).replacingCharacters(in: fullRange, with: "")
        }

        return (cleanedResponse.trimmingCharacters(in: .whitespacesAndNewlines), savedFiles)
    }

    /// AI 응답에서 멘션을 추출하고 해당 부서에 요청
    private func extractAndProcessMentions(from response: String) async -> (cleanedResponse: String, mentionResponses: [String]) {
        var cleanedResponse = response
        var mentionResponses: [String] = []

        // <<<MENTION:@부서명>>> ... <<<END_MENTION>>> 패턴 찾기
        let pattern = "<<<MENTION:@([^>]+)>>>([\\s\\S]*?)<<<END_MENTION>>>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return (response, [])
        }

        let nsString = response as NSString
        let matches = regex.matches(in: response, options: [], range: NSRange(location: 0, length: nsString.length))

        for match in matches.reversed() {
            guard match.numberOfRanges >= 3 else { continue }

            let departmentNameRange = match.range(at: 1)
            let requestContentRange = match.range(at: 2)
            let fullRange = match.range(at: 0)

            let departmentName = nsString.substring(with: departmentNameRange).trimmingCharacters(in: .whitespaces)
            let requestContent = nsString.substring(with: requestContentRange).trimmingCharacters(in: .whitespacesAndNewlines)

            // 해당 부서 찾기
            if let targetDept = findDepartment(byName: departmentName),
               let targetEmployee = targetDept.employees.first {

                // 멘션 요청 메시지 추가
                let mentionMessage = ChatMessage(role: .assistant, content: "🔄 @\(departmentName)에 협업 요청 중...")
                await MainActor.run {
                    messages.append(mentionMessage)
                }

                // 해당 부서 직원에게 요청 보내기
                do {
                    let mentionSystemPrompt = """
                    당신은 \(targetEmployee.name)입니다. \(targetDept.type.rawValue)팀 소속입니다.
                    \(targetDept.type.expertRolePrompt)

                    다른 부서(\(departmentType.rawValue)팀의 \(employee.name))에서 협업 요청이 왔습니다.
                    전문가로서 간결하고 명확하게 답변해주세요.
                    """

                    let mentionResponse: String
                    var mentionInputTokens = 0
                    var mentionOutputTokens = 0

                    if canUseClaudeCode && useClaudeCode {
                        mentionResponse = try await claudeCodeService.sendMessage(
                            requestContent,
                            systemPrompt: mentionSystemPrompt
                        )
                    } else if let config = apiConfig, config.isConfigured {
                        let result = try await claudeService.sendMessage(
                            requestContent,
                            employeeId: targetEmployee.id,
                            configuration: config,
                            systemPrompt: mentionSystemPrompt
                        )
                        mentionResponse = result.response
                        mentionInputTokens = result.inputTokens
                        mentionOutputTokens = result.outputTokens
                    } else {
                        mentionResponse = "[\(departmentName) 응답 실패: API 미설정]"
                    }

                    // 멘션 대상 직원의 토큰 사용량 업데이트
                    if mentionInputTokens > 0 || mentionOutputTokens > 0 {
                        await MainActor.run {
                            companyStore.updateEmployeeTokenUsage(targetEmployee.id, inputTokens: mentionInputTokens, outputTokens: mentionOutputTokens)
                        }
                    }

                    let formattedResponse = "📨 **@\(departmentName) (\(targetEmployee.name))의 답변:**\n\(mentionResponse)"
                    mentionResponses.append(formattedResponse)

                    // 협업 기록 저장
                    let record = CollaborationRecord(
                        requesterId: employee.id,
                        requesterName: employee.name,
                        requesterDepartment: departmentType.rawValue,
                        responderId: targetEmployee.id,
                        responderName: targetEmployee.name,
                        responderDepartment: targetDept.type.rawValue,
                        requestContent: requestContent,
                        responseContent: mentionResponse,
                        tags: [departmentType.rawValue, targetDept.type.rawValue]
                    )
                    await MainActor.run {
                        companyStore.addCollaborationRecord(record)
                    }

                } catch {
                    mentionResponses.append("📨 **@\(departmentName) 응답 실패:** \(error.localizedDescription)")
                }
            } else {
                mentionResponses.append("⚠️ '\(departmentName)' 부서를 찾을 수 없습니다.")
            }

            // 응답에서 멘션 블록 제거
            cleanedResponse = (cleanedResponse as NSString).replacingCharacters(in: fullRange, with: "")
        }

        return (cleanedResponse.trimmingCharacters(in: .whitespacesAndNewlines), mentionResponses)
    }

    /// 부서명으로 부서 찾기
    private func findDepartment(byName name: String) -> Department? {
        let normalizedName = name.replacingOccurrences(of: "팀", with: "").trimmingCharacters(in: .whitespaces)

        return companyStore.company.departments.first { dept in
            let deptName = dept.type.rawValue.replacingOccurrences(of: "팀", with: "")
            return deptName.contains(normalizedName) || normalizedName.contains(deptName)
        }
    }

    // MARK: - 사고 축적 시스템

    /// 응답에서 인사이트 추출 및 사고 과정 업데이트
    private func extractAndProcessInsights(from response: String, userMessage: String) -> String {
        var cleanedResponse = response
        var extractedInsights: [String] = []

        // <<<INSIGHT>>> ... <<<END_INSIGHT>>> 패턴 찾기
        let pattern = "<<<INSIGHT>>>([\\s\\S]*?)<<<END_INSIGHT>>>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return response
        }

        let nsString = response as NSString
        let matches = regex.matches(in: response, options: [], range: NSRange(location: 0, length: nsString.length))

        for match in matches.reversed() {
            guard match.numberOfRanges >= 2 else { continue }

            let insightRange = match.range(at: 1)
            let fullRange = match.range(at: 0)

            let insight = nsString.substring(with: insightRange).trimmingCharacters(in: .whitespacesAndNewlines)
            if !insight.isEmpty {
                extractedInsights.append(insight)
            }

            // 응답에서 인사이트 블록 제거
            cleanedResponse = (cleanedResponse as NSString).replacingCharacters(in: fullRange, with: "")
        }

        // 추출된 인사이트가 있으면 사고 과정에 추가
        if !extractedInsights.isEmpty {
            processInsights(extractedInsights, userMessage: userMessage)
        }

        return cleanedResponse.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 인사이트를 사고 과정에 추가하고 준비도 평가
    private func processInsights(_ insights: [String], userMessage: String) {
        // 현재 사고 과정이 없으면 새로 시작
        if currentThinking == nil {
            // 첫 대화 주제를 사고 주제로 설정
            let topic = extractTopic(from: userMessage)
            currentThinking = companyStore.startThinking(
                employeeId: employee.id,
                employeeName: employee.name,
                departmentType: departmentType,
                topic: topic
            )
        }

        guard var thinking = currentThinking else { return }

        // 입력 정보 추가
        let input = ThinkingInput(
            content: userMessage,
            source: "대화"
        )
        companyStore.addThinkingInput(thinkingId: thinking.id, content: userMessage, source: "대화")
        thinking.inputs.append(input)

        // 기존 인사이트와 비교하여 새 인사이트인지 확인
        var newInsightCount = 0
        for insight in insights {
            if !thinking.reasoning.keyInsights.contains(where: { $0.contains(insight.prefix(50)) || insight.contains($0.prefix(50)) }) {
                thinking.reasoning.keyInsights.append(insight)
                newInsightCount += 1
            }
        }

        // 새 인사이트가 없으면 카운트 증가 (사고가 포화 상태)
        if newInsightCount == 0 {
            thinking.reasoning.noNewInsightsCount += 1
        } else {
            thinking.reasoning.noNewInsightsCount = 0
        }

        // 준비도 점수 계산
        thinking.reasoning.readinessScore = calculateReadiness(thinking)

        // 사고 과정 저장
        companyStore.updateThinkingReasoning(thinkingId: thinking.id, reasoning: thinking.reasoning)
        currentThinking = thinking

        // 결론 준비가 되었는지 확인
        if thinking.isReadyForConclusion {
            generateConclusionAndPost(thinking)
        }
    }

    /// 메시지에서 주제 추출
    private func extractTopic(from message: String) -> String {
        // 첫 50자를 주제로 사용 (더 정교한 로직 필요 시 AI 사용)
        let topic = String(message.prefix(100))
        if topic.count < message.count {
            return topic + "..."
        }
        return topic
    }

    /// 준비도 점수 계산 (1-10)
    private func calculateReadiness(_ thinking: EmployeeThinking) -> Int {
        var score = 0

        // 인사이트 수에 따른 점수 (최대 4점)
        score += min(thinking.reasoning.keyInsights.count, 4)

        // 입력 정보 수에 따른 점수 (최대 3점)
        score += min(thinking.inputs.count / 2, 3)

        // 사고 포화 상태 (새 인사이트가 안 나오면) 보너스 (최대 2점)
        score += min(thinking.reasoning.noNewInsightsCount, 2)

        // 대화 깊이 (메시지 수)에 따른 점수 (최대 1점)
        if messages.count >= 6 {
            score += 1
        }

        return min(score, 10)
    }

    /// 결론 생성 및 커뮤니티에 게시
    private func generateConclusionAndPost(_ thinking: EmployeeThinking) {
        Task {
            do {
                let conclusionPrompt = """
                지금까지 대화에서 축적된 인사이트를 바탕으로 결론을 내려주세요.

                ## 축적된 인사이트:
                \(thinking.reasoning.keyInsights.enumerated().map { "- \($0.element)" }.joined(separator: "\n"))

                ## 입력된 정보:
                \(thinking.inputs.map { "- \($0.content)" }.joined(separator: "\n"))

                다음 형식으로 답변해주세요:

                <<<CONCLUSION>>>
                요약: (3줄 이내의 핵심 결론)

                근거: (왜 이런 결론에 도달했는지)

                실행계획:
                - (구체적 액션 아이템 1)
                - (구체적 액션 아이템 2)
                - (구체적 액션 아이템 3)

                리스크:
                - (주의해야 할 점이나 리스크)
                <<<END_CONCLUSION>>>
                """

                let response: String
                var inputTokens = 0
                var outputTokens = 0

                if canUseClaudeCode && useClaudeCode {
                    response = try await claudeCodeService.sendMessage(
                        conclusionPrompt,
                        systemPrompt: systemPrompt
                    )
                } else if let config = apiConfig, config.isConfigured {
                    let result = try await claudeService.sendMessage(
                        conclusionPrompt,
                        employeeId: employee.id,
                        configuration: config,
                        systemPrompt: systemPrompt
                    )
                    response = result.response
                    inputTokens = result.inputTokens
                    outputTokens = result.outputTokens
                } else {
                    return
                }

                // 토큰 사용량 업데이트
                if inputTokens > 0 || outputTokens > 0 {
                    await MainActor.run {
                        companyStore.updateEmployeeTokenUsage(employee.id, inputTokens: inputTokens, outputTokens: outputTokens)
                    }
                }

                // 결론 파싱
                if let conclusion = parseConclusion(from: response) {
                    var updatedThinking = thinking
                    updatedThinking.conclusion = conclusion

                    // 결론 저장
                    companyStore.setThinkingConclusion(thinkingId: thinking.id, conclusion: conclusion)

                    // 커뮤니티에 게시
                    if let post = companyStore.createPostFromThinking(updatedThinking) {
                        await MainActor.run {
                            let postMessage = ChatMessage(
                                role: .assistant,
                                content: "💡 **인사이트 결론이 도출되었습니다!**\n\n\(conclusion.summary)\n\n📝 커뮤니티에 '\(post.title)' 제목으로 게시되었습니다."
                            )
                            messages.append(postMessage)
                            currentThinking = nil  // 새 사고 과정을 위해 초기화
                        }
                    }
                }
            } catch {
                print("결론 생성 실패: \(error)")
            }
        }
    }

    /// 응답에서 결론 파싱
    private func parseConclusion(from response: String) -> ThinkingConclusion? {
        let pattern = "<<<CONCLUSION>>>([\\s\\S]*?)<<<END_CONCLUSION>>>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: response, options: [], range: NSRange(location: 0, length: (response as NSString).length)),
              match.numberOfRanges >= 2 else {
            return nil
        }

        let content = (response as NSString).substring(with: match.range(at: 1))

        // 간단한 파싱 (실제로는 더 정교하게)
        var summary = ""
        var reasoning = ""
        var actionPlan: [String] = []
        var risks: [String] = []

        let lines = content.components(separatedBy: "\n")
        var currentSection = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("요약:") {
                currentSection = "summary"
                summary = trimmed.replacingOccurrences(of: "요약:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("근거:") {
                currentSection = "reasoning"
                reasoning = trimmed.replacingOccurrences(of: "근거:", with: "").trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("실행계획:") {
                currentSection = "action"
            } else if trimmed.hasPrefix("리스크:") {
                currentSection = "risks"
            } else if trimmed.hasPrefix("- ") {
                let item = trimmed.replacingOccurrences(of: "- ", with: "")
                if currentSection == "action" {
                    actionPlan.append(item)
                } else if currentSection == "risks" {
                    risks.append(item)
                }
            } else if !trimmed.isEmpty {
                if currentSection == "summary" {
                    summary += " " + trimmed
                } else if currentSection == "reasoning" {
                    reasoning += " " + trimmed
                }
            }
        }

        guard !summary.isEmpty else { return nil }

        return ThinkingConclusion(
            summary: summary,
            reasoning: reasoning,
            actionPlan: actionPlan,
            risks: risks,
            turningPoints: []
        )
    }

    private func saveConversation() {
        // Employee의 conversationHistory 업데이트
        let newMessages = messages.map { msg in
            Message(
                role: msg.role == .user ? .user : .assistant,
                content: msg.content
            )
        }

        // CompanyStore를 통해 저장
        for (deptIndex, dept) in companyStore.company.departments.enumerated() {
            if let empIndex = dept.employees.firstIndex(where: { $0.id == employee.id }) {
                companyStore.company.departments[deptIndex].employees[empIndex].conversationHistory = newMessages
                companyStore.saveCompany()
                break
            }
        }

        // 업무 기록 저장 (대화 내용 요약)
        saveWorkLog()
    }

    /// 업무 기록 저장
    private func saveWorkLog() {
        // 최소 4개 이상의 메시지가 있을 때만 저장 (인사 + 1회 이상의 대화)
        guard messages.count >= 4 else { return }

        // 마지막 대화 내용을 기반으로 업무 기록 생성
        let recentMessages = messages.suffix(4)
        let userMessages = recentMessages.filter { $0.role == .user }.map { $0.content }
        let assistantMessages = recentMessages.filter { $0.role == .assistant }.map { $0.content }

        // 대화 요약 생성
        let summary = userMessages.joined(separator: " / ")
        let keyPoints = assistantMessages.compactMap { msg -> String? in
            // 응답의 첫 문장을 핵심 포인트로 추출
            let firstSentence = msg.components(separatedBy: CharacterSet(charactersIn: ".!?")).first ?? ""
            return firstSentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : firstSentence.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // 업무 기록 서비스에 저장
        EmployeeWorkLogService.shared.addConversationSummary(
            for: employee.id,
            employeeName: employee.name,
            departmentType: departmentType,
            conversationSummary: summary.prefix(200).description,
            keyPoints: Array(keyPoints.prefix(3)),
            actionItems: []
        )
    }

    /// 대화 내용 초기화
    private func clearConversation() {
        // UI 메시지 초기화
        messages.removeAll()

        // CompanyStore에서도 초기화
        for (deptIndex, dept) in companyStore.company.departments.enumerated() {
            if let empIndex = dept.employees.firstIndex(where: { $0.id == employee.id }) {
                companyStore.company.departments[deptIndex].employees[empIndex].conversationHistory = []
                companyStore.saveCompany()
                break
            }
        }

        // 새 인사 시작
        sendGreeting()
    }

    /// 업무 결과 문서화 요청
    private func requestDocumentize() {
        // 대화가 충분히 진행되었는지 확인
        guard messages.count >= 2 else {
            errorMessage = "문서화할 대화 내용이 충분하지 않습니다."
            return
        }

        // 문서화 요청 메시지 전송
        inputText = "지금까지 논의된 내용을 정리하여 위키 문서로 작성해주세요. 핵심 내용, 결정 사항, 액션 아이템을 포함해주세요."
        sendMessage()
    }

    // MARK: - Permission Request Handling

    /// AI 응답에서 권한 요청 추출
    private func extractPermissionRequests(from response: String) -> (cleanedResponse: String, requests: [PermissionRequest]) {
        print("🔍 [Permission] 권한 요청 추출 시작")
        print("📝 [Permission] 응답 길이: \(response.count)자")

        var cleanedResponse = response
        var extractedRequests: [PermissionRequest] = []

        // <<<PERMISSION:권한타입>>> ... <<<END_PERMISSION>>> 패턴 찾기
        let pattern = "<<<PERMISSION:([^>]+)>>>([\\s\\S]*?)<<<END_PERMISSION>>>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            print("❌ [Permission] 정규식 생성 실패")
            return (response, [])
        }

        let nsString = response as NSString
        let matches = regex.matches(in: response, options: [], range: NSRange(location: 0, length: nsString.length))
        print("🔎 [Permission] 발견된 패턴 수: \(matches.count)")

        for match in matches.reversed() {
            guard match.numberOfRanges >= 3 else { continue }

            let permissionTypeRange = match.range(at: 1)
            let contentRange = match.range(at: 2)
            let fullRange = match.range(at: 0)

            let permissionTypeStr = nsString.substring(with: permissionTypeRange).trimmingCharacters(in: .whitespaces)
            let content = nsString.substring(with: contentRange).trimmingCharacters(in: .whitespacesAndNewlines)

            print("📋 [Permission] 권한 타입: \(permissionTypeStr)")
            print("📄 [Permission] 내용 미리보기: \(content.prefix(100))...")

            // 권한 타입 파싱
            guard let permissionType = parsePermissionType(permissionTypeStr) else { continue }

            // 내용 파싱
            let fields = parsePermissionFields(content)

            guard let title = fields["제목"] else { continue }
            let description = fields["설명"] ?? ""
            let targetPath = fields["경로"]
            let estimatedSize = fields["크기"].flatMap { Int($0) }
            let metadataStr = fields["메타데이터"] ?? ""
            let metadata = parseMetadata(metadataStr)

            // PermissionRequest 생성
            let request = PermissionRequest(
                type: permissionType,
                employeeId: employee.id,
                employeeName: employee.name,
                employeeDepartment: departmentType.rawValue,
                projectId: nil,
                projectName: nil,
                title: title,
                description: description,
                targetPath: targetPath,
                estimatedSize: estimatedSize,
                metadata: metadata
            )

            print("✅ [Permission] 권한 요청 생성 완료:")
            print("   - ID: \(request.id)")
            print("   - 타입: \(request.type.rawValue)")
            print("   - 제목: \(request.title)")
            print("   - 직원: \(request.employeeName) (\(request.employeeId))")
            print("   - 경로: \(request.targetPath ?? "없음")")

            extractedRequests.append(request)

            // 응답에서 권한 요청 블록 제거
            cleanedResponse = (cleanedResponse as NSString).replacingCharacters(in: fullRange, with: "")
        }

        print("📊 [Permission] 추출 완료: \(extractedRequests.count)개 권한 요청")
        return (cleanedResponse.trimmingCharacters(in: .whitespacesAndNewlines), extractedRequests)
    }

    /// 권한 타입 문자열을 PermissionType으로 변환
    private func parsePermissionType(_ typeStr: String) -> PermissionType? {
        switch typeStr.uppercased() {
        case "FILE_WRITE":
            return .fileWrite
        case "FILE_EDIT":
            return .fileEdit
        case "FILE_DELETE":
            return .fileDelete
        case "COMMAND_EXECUTION":
            return .commandExecution
        case "API_CALL":
            return .apiCall
        case "DATA_EXPORT":
            return .dataExport
        default:
            return nil
        }
    }

    /// 권한 요청 필드 파싱
    private func parsePermissionFields(_ content: String) -> [String: String] {
        var fields: [String: String] = [:]
        let lines = content.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let colonIndex = trimmed.firstIndex(of: ":") {
                let key = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                fields[key] = value
            }
        }

        return fields
    }

    /// 메타데이터 문자열 파싱 (key1=value1, key2=value2)
    private func parseMetadata(_ metadataStr: String) -> [String: String] {
        var metadata: [String: String] = [:]
        let pairs = metadataStr.components(separatedBy: ",")

        for pair in pairs {
            let trimmed = pair.trimmingCharacters(in: .whitespaces)
            let parts = trimmed.components(separatedBy: "=")
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                metadata[key] = value
            }
        }

        return metadata
    }

    /// 권한 승인 처리
    private func handlePermissionApproval(_ requestId: UUID, reason: String?) {
        print("✅ [Permission] 권한 승인 처리 시작: \(requestId)")

        // 요청 정보 가져오기
        guard let request = companyStore.company.permissionRequests.first(where: { $0.id == requestId }) else {
            print("❌ [Permission] 권한 요청을 찾을 수 없음: \(requestId)")
            return
        }

        print("   - 승인할 요청: \(request.title)")
        companyStore.approvePermissionRequest(requestId, reason: reason)

        let approvalMessage = ChatMessage(
            role: .system,
            content: "✅ '\(request.title)' 권한이 승인되었습니다.\n\(reason.map { "사유: \($0)" } ?? "")"
        )
        messages.append(approvalMessage)

        // AI에게 승인 알림 (작업 진행 요청)
        inputText = "권한이 승인되었습니다. '\(request.title)' 작업을 진행해주세요."
        sendMessage()
    }

    /// 권한 거부 처리
    private func handlePermissionDenial(_ requestId: UUID, reason: String?) {
        print("❌ [Permission] 권한 거부 처리 시작: \(requestId)")

        // 요청 정보 가져오기
        guard let request = companyStore.company.permissionRequests.first(where: { $0.id == requestId }) else {
            print("❌ [Permission] 권한 요청을 찾을 수 없음: \(requestId)")
            return
        }

        print("   - 거부할 요청: \(request.title)")
        companyStore.denyPermissionRequest(requestId, reason: reason)

        let denialMessage = ChatMessage(
            role: .system,
            content: "❌ '\(request.title)' 권한이 거부되었습니다.\n\(reason.map { "사유: \($0)" } ?? "")"
        )
        messages.append(denialMessage)

        // AI에게 거부 알림 (대안 제시 요청)
        inputText = "권한이 거부되었습니다. '\(request.title)' 작업의 대안을 제시해주세요.\n거부 사유: \(reason ?? "사유 없음")"
        sendMessage()
    }
}

struct ChatHeader: View {
    let employee: Employee
    var thinkingStatus: String? = nil
    var pendingPermissionCount: Int = 0
    let onClose: () -> Void
    let onClearConversation: () -> Void
    let onDocumentize: () -> Void
    let onShowPermissions: () -> Void

    var body: some View {
        HStack {
            // Employee info
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(employee.aiType.color.opacity(0.2))
                        .frame(width: 40, height: 40)
                    Image(systemName: employee.aiType.icon)
                        .foregroundStyle(employee.aiType.color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(employee.name)
                        .font(.headline)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(employee.status.color)
                            .frame(width: 8, height: 8)
                        Text(employee.status.rawValue)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    // 사고 상태 표시
                    if let status = thinkingStatus {
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Spacer()

            // 권한 요청 알림 버튼
            Button(action: onShowPermissions) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell.fill")
                        .font(.title3)
                        .foregroundStyle(pendingPermissionCount > 0 ? .orange : .secondary)

                    if pendingPermissionCount > 0 {
                        ZStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 16, height: 16)
                            Text("\(pendingPermissionCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .offset(x: 8, y: -8)
                    }
                }
            }
            .buttonStyle(.plain)
            .help("권한 요청 \(pendingPermissionCount > 0 ? "(\(pendingPermissionCount)개 대기중)" : "")")

            // 문서화 버튼
            Button(action: onDocumentize) {
                Image(systemName: "doc.text")
                    .font(.title3)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
            .help("업무 결과 문서화")

            // 대화 초기화 버튼
            Button(action: onClearConversation) {
                Image(systemName: "trash")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("대화 초기화")

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct ChatInputView: View {
    @Binding var text: String
    let isLoading: Bool
    let isConfigured: Bool
    let availableDepartments: [DepartmentType]
    let onSend: () -> Void

    @State private var showMentionPicker = false

    /// @ 입력 감지
    var shouldShowMentionPicker: Bool {
        text.hasSuffix("@") || (text.contains("@") && !text.hasSuffix(" "))
    }

    var body: some View {
        VStack(spacing: 0) {
            // 멘션 자동완성 팝업
            if showMentionPicker {
                MentionPickerView(
                    departments: availableDepartments,
                    onSelect: { dept in
                        // @ 제거하고 멘션 삽입
                        if text.hasSuffix("@") {
                            text.removeLast()
                        }
                        text += "@\(dept.rawValue) "
                        showMentionPicker = false
                    },
                    onDismiss: {
                        showMentionPicker = false
                    }
                )
            }

            HStack(spacing: 12) {
                // 멘션 버튼
                Button {
                    showMentionPicker.toggle()
                } label: {
                    Image(systemName: "at")
                        .font(.title3)
                        .foregroundStyle(showMentionPicker ? .blue : .secondary)
                }
                .buttonStyle(.plain)
                .help("팀 멘션하기")

                TextField(isConfigured ? "메시지를 입력하세요... (@로 팀 멘션)" : "API 설정이 필요합니다", text: $text)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Color(NSColor.textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .disabled(!isConfigured || isLoading)
                    .onChange(of: text) { _, newValue in
                        // @ 입력 시 멘션 피커 표시
                        if newValue.hasSuffix("@") {
                            showMentionPicker = true
                        }
                    }
                    .onSubmit {
                        if !text.isEmpty && isConfigured && !isLoading {
                            onSend()
                        }
                    }

                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                        .foregroundStyle(text.isEmpty || !isConfigured || isLoading ? Color.secondary : Color.blue)
                }
                .buttonStyle(.plain)
                .disabled(text.isEmpty || !isConfigured || isLoading)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
        }
    }
}

/// 멘션 선택 팝업
struct MentionPickerView: View {
    let departments: [DepartmentType]
    let onSelect: (DepartmentType) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("팀 멘션")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            ForEach(departments.filter { $0 != .general }, id: \.self) { dept in
                Button {
                    onSelect(dept)
                } label: {
                    HStack {
                        Image(systemName: dept.icon)
                            .frame(width: 20)
                            .foregroundStyle(dept.color)
                        Text("@\(dept.rawValue)")
                        Spacer()
                        Text(dept.shortDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(Color.clear)
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
        .padding(.horizontal)
        .padding(.bottom, 4)
    }
}

struct ChatBubble: View {
    let message: ChatMessage
    let aiType: AIType

    var isUser: Bool {
        message.role == .user
    }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .textSelection(.enabled)  // 텍스트 선택 가능
                    .padding(12)
                    .background(isUser ? Color.blue : Color(NSColor.controlBackgroundColor))
                    .foregroundStyle(isUser ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .contextMenu {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(message.content, forType: .string)
                        } label: {
                            Label("복사", systemImage: "doc.on.doc")
                        }
                    }

                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            if !isUser { Spacer(minLength: 60) }
        }
    }
}

/// 채팅 메시지 모델
struct ChatMessage: Identifiable {
    let id = UUID()
    let role: ChatRole
    let content: String
    let timestamp: Date

    init(role: ChatRole, content: String, timestamp: Date = Date()) {
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

enum ChatRole {
    case user
    case assistant
    case system
}

// MARK: - AI Thinking Indicator

/// AI가 생각하는 동안 표시되는 인디케이터 (최근 업무 주제 기반 메시지 + 경과 시간)
struct AIThinkingIndicator: View {
    let departmentType: DepartmentType
    let employeeName: String
    let startTime: Date
    let userMessage: String?  // 사용자의 최근 메시지

    @State private var currentMessageIndex = 0
    @State private var elapsedTime: TimeInterval = 0

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    let messageTimer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 12) {
            // 애니메이션 프로그레스
            ProgressView()
                .scaleEffect(0.8)

            VStack(alignment: .leading, spacing: 2) {
                // 메인 메시지 (컨텍스트 기반 + 로테이션)
                Text(currentMessage)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .animation(.easeInOut, value: currentMessageIndex)

                // 경과 시간
                Text(elapsedTimeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onReceive(timer) { _ in
            elapsedTime = Date().timeIntervalSince(startTime)
        }
        .onReceive(messageTimer) { _ in
            withAnimation {
                currentMessageIndex = (currentMessageIndex + 1) % thinkingMessages.count
            }
        }
    }

    /// 최근 업무 주제에 따른 동적 메시지 생성
    private var thinkingMessages: [String] {
        // 사용자 메시지가 있으면 키워드 기반 컨텍스트 메시지 생성
        if let message = userMessage?.lowercased() {
            var contextualMessages: [String] = []

            // 로그인/인증 관련
            if message.contains("로그인") || message.contains("인증") || message.contains("회원가입") || message.contains("authentication") {
                contextualMessages.append("\(employeeName)이(가) 인증 시스템을 설계하고 있습니다...")
                contextualMessages.append("로그인 플로우를 구상하고 있습니다...")
                contextualMessages.append("보안 요구사항을 검토하고 있습니다...")
            }

            // 데이터/DB 관련
            if message.contains("데이터") || message.contains("데이터베이스") || message.contains("db") || message.contains("저장") || message.contains("조회") {
                contextualMessages.append("\(employeeName)이(가) 데이터 구조를 설계하고 있습니다...")
                contextualMessages.append("데이터베이스 스키마를 검토하고 있습니다...")
                contextualMessages.append("데이터 흐름을 분석하고 있습니다...")
            }

            // UI/디자인 관련
            if message.contains("디자인") || message.contains("ui") || message.contains("화면") || message.contains("레이아웃") || message.contains("스타일") {
                contextualMessages.append("\(employeeName)이(가) 화면 레이아웃을 구상하고 있습니다...")
                contextualMessages.append("디자인 컨셉을 고민하고 있습니다...")
                contextualMessages.append("사용자 인터페이스를 설계하고 있습니다...")
            }

            // API/통신 관련
            if message.contains("api") || message.contains("통신") || message.contains("요청") || message.contains("응답") || message.contains("서버") {
                contextualMessages.append("\(employeeName)이(가) API 명세를 작성하고 있습니다...")
                contextualMessages.append("서버 통신 로직을 설계하고 있습니다...")
                contextualMessages.append("엔드포인트를 정의하고 있습니다...")
            }

            // 테스트/버그 관련
            if message.contains("테스트") || message.contains("버그") || message.contains("오류") || message.contains("에러") || message.contains("디버깅") {
                contextualMessages.append("\(employeeName)이(가) 테스트 시나리오를 구상하고 있습니다...")
                contextualMessages.append("버그 원인을 분석하고 있습니다...")
                contextualMessages.append("품질 검증 방법을 고민하고 있습니다...")
            }

            // 문서/정리 관련
            if message.contains("문서") || message.contains("작성") || message.contains("정리") || message.contains("위키") || message.contains("문서화") {
                contextualMessages.append("\(employeeName)이(가) 문서 구조를 구성하고 있습니다...")
                contextualMessages.append("핵심 내용을 정리하고 있습니다...")
                contextualMessages.append("문서 형식을 검토하고 있습니다...")
            }

            // 성능/최적화 관련
            if message.contains("성능") || message.contains("최적화") || message.contains("속도") || message.contains("개선") {
                contextualMessages.append("\(employeeName)이(가) 성능 개선 방안을 모색하고 있습니다...")
                contextualMessages.append("최적화 포인트를 분석하고 있습니다...")
                contextualMessages.append("효율적인 구현 방법을 고민하고 있습니다...")
            }

            // 기획/분석 관련
            if message.contains("기획") || message.contains("요구사항") || message.contains("분석") || message.contains("전략") {
                contextualMessages.append("\(employeeName)이(가) 요구사항을 분석하고 있습니다...")
                contextualMessages.append("전략을 수립하고 있습니다...")
                contextualMessages.append("기획안을 구상하고 있습니다...")
            }

            // 배포/운영 관련
            if message.contains("배포") || message.contains("운영") || message.contains("릴리즈") || message.contains("출시") {
                contextualMessages.append("\(employeeName)이(가) 배포 전략을 수립하고 있습니다...")
                contextualMessages.append("릴리즈 계획을 검토하고 있습니다...")
                contextualMessages.append("운영 방안을 고민하고 있습니다...")
            }

            // 매칭된 컨텍스트 메시지가 있으면 사용
            if !contextualMessages.isEmpty {
                // 부서별 기본 메시지도 1-2개 추가하여 다양성 확보
                let defaultMessages = defaultDepartmentMessages
                contextualMessages.append(defaultMessages[0])
                if defaultMessages.count > 1 {
                    contextualMessages.append(defaultMessages[1])
                }
                return contextualMessages
            }
        }

        // 컨텍스트가 없으면 기본 부서별 메시지 사용
        return defaultDepartmentMessages
    }

    /// 부서별 기본 메시지
    private var defaultDepartmentMessages: [String] {
        switch departmentType {
        case .planning:
            return [
                "\(employeeName)이(가) 전략을 수립하고 있습니다...",
                "요구사항을 분석하고 있습니다...",
                "프로젝트 계획을 검토하고 있습니다...",
                "기획안을 구상하고 있습니다..."
            ]
        case .design:
            return [
                "\(employeeName)이(가) 디자인을 구상하고 있습니다...",
                "사용자 경험을 검토하고 있습니다...",
                "레퍼런스를 분석하고 있습니다...",
                "디자인 시스템을 고려하고 있습니다..."
            ]
        case .development:
            return [
                "\(employeeName)이(가) 코드를 분석하고 있습니다...",
                "기술적 해결 방안을 모색하고 있습니다...",
                "아키텍처를 검토하고 있습니다...",
                "구현 방법을 고민하고 있습니다..."
            ]
        case .qa:
            return [
                "\(employeeName)이(가) 테스트 계획을 수립하고 있습니다...",
                "품질 기준을 검토하고 있습니다...",
                "테스트 케이스를 구상하고 있습니다...",
                "버그 시나리오를 분석하고 있습니다..."
            ]
        case .marketing:
            return [
                "\(employeeName)이(가) 마케팅 전략을 검토하고 있습니다...",
                "타겟 고객을 분석하고 있습니다...",
                "캠페인 아이디어를 구상하고 있습니다...",
                "시장 트렌드를 파악하고 있습니다..."
            ]
        case .general:
            return [
                "\(employeeName)이(가) 생각하고 있습니다...",
                "답변을 준비하고 있습니다...",
                "내용을 정리하고 있습니다...",
                "최선의 답변을 찾고 있습니다..."
            ]
        }
    }

    private var currentMessage: String {
        thinkingMessages[currentMessageIndex]
    }

    private var elapsedTimeText: String {
        let seconds = Int(elapsedTime)
        if seconds < 60 {
            return "\(seconds)초 경과"
        } else {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            return "\(minutes)분 \(remainingSeconds)초 경과"
        }
    }
}

#Preview {
    EmployeeChatView(
        employee: Employee(name: "Claude-기획", aiType: .claude)
    )
    .environmentObject(CompanyStore())
}
