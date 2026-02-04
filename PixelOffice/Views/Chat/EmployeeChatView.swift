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
                onClose: { dismiss() },
                onClearConversation: { clearConversation() },
                onDocumentize: { requestDocumentize() }
            )

            Divider()

            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            ChatBubble(message: message, aiType: employee.aiType)
                        }

                        if isLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("생각 중...")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
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

                // Claude 타입이면 Claude Code CLI 먼저 시도
                if canUseClaudeCode && useClaudeCode {
                    response = try await claudeCodeService.sendMessage(
                        greetingPrompt,
                        systemPrompt: systemPrompt
                    )
                } else if let config = apiConfig, config.isConfigured {
                    // 그 외에는 직접 API 호출
                    response = try await claudeService.sendMessage(
                        greetingPrompt,
                        employeeId: employee.id,
                        configuration: config,
                        systemPrompt: systemPrompt,
                        isGreeting: true
                    )
                } else {
                    throw ClaudeCodeError.notInstalled
                }

                await MainActor.run {
                    let assistantMessage = ChatMessage(role: .assistant, content: response)
                    messages.append(assistantMessage)
                    isLoading = false
                    companyStore.updateEmployeeStatus(employee.id, status: .idle)  // 휴식중으로 변경
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
        errorMessage = nil
        companyStore.updateEmployeeStatus(employee.id, status: .thinking)  // 생각중으로 변경

        Task {
            do {
                let response: String

                // Claude 타입이면 Claude Code CLI 먼저 시도
                if hasClaudeCode {
                    response = try await claudeCodeService.sendMessage(
                        messageToSend,
                        systemPrompt: systemPrompt,
                        conversationHistory: employee.conversationHistory
                    )
                } else if let config = apiConfig, config.isConfigured {
                    // 그 외에는 직접 API 호출
                    response = try await claudeService.sendMessage(
                        messageToSend,
                        employeeId: employee.id,
                        configuration: config,
                        systemPrompt: systemPrompt
                    )
                } else {
                    throw ClaudeCodeError.notInstalled
                }

                // 응답에서 파일 추출 및 저장
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
                createdBy: employee.name,
                tags: [departmentType.rawValue, employee.name],
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
                    if canUseClaudeCode && useClaudeCode {
                        mentionResponse = try await claudeCodeService.sendMessage(
                            requestContent,
                            systemPrompt: mentionSystemPrompt
                        )
                    } else if let config = apiConfig, config.isConfigured {
                        mentionResponse = try await claudeService.sendMessage(
                            requestContent,
                            employeeId: targetEmployee.id,
                            configuration: config,
                            systemPrompt: mentionSystemPrompt
                        )
                    } else {
                        mentionResponse = "[\(departmentName) 응답 실패: API 미설정]"
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
                if canUseClaudeCode && useClaudeCode {
                    response = try await claudeCodeService.sendMessage(
                        conclusionPrompt,
                        systemPrompt: systemPrompt
                    )
                } else if let config = apiConfig, config.isConfigured {
                    response = try await claudeService.sendMessage(
                        conclusionPrompt,
                        employeeId: employee.id,
                        configuration: config,
                        systemPrompt: systemPrompt
                    )
                } else {
                    return
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
}

struct ChatHeader: View {
    let employee: Employee
    var thinkingStatus: String? = nil
    let onClose: () -> Void
    let onClearConversation: () -> Void
    let onDocumentize: () -> Void

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
}

#Preview {
    EmployeeChatView(
        employee: Employee(name: "Claude-기획", aiType: .claude)
    )
    .environmentObject(CompanyStore())
}
