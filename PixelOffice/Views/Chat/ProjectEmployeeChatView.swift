import SwiftUI

/// 프로젝트 직원과의 대화 화면
struct ProjectEmployeeChatView: View {
    let projectId: UUID
    let employeeId: UUID
    @EnvironmentObject var companyStore: CompanyStore
    @Environment(\.dismiss) private var dismiss

    @State private var inputText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var messages: [ChatMessage] = []
    @State private var useClaudeCode = true

    private let claudeService = ClaudeService()
    private let claudeCodeService = ClaudeCodeService()

    var project: Project? {
        companyStore.company.projects.first { $0.id == projectId }
    }

    var employee: ProjectEmployee? {
        companyStore.getProjectEmployee(byId: employeeId, inProject: projectId)
    }

    var apiConfig: APIConfiguration? {
        guard let emp = employee else { return nil }
        return companyStore.getAPIConfiguration(for: emp.aiType)
    }

    var canUseClaudeCode: Bool {
        employee?.aiType == .claude
    }

    /// 부서별 문서 폴더 경로
    var departmentDocumentsPath: String? {
        guard let proj = project, let emp = employee else { return nil }
        return DataPathService.shared.documentsPath(proj.name, department: emp.departmentType)
    }

    /// 부서별 커스텀 스킬
    var customSkills: DepartmentSkillSet {
        guard let emp = employee else {
            return DepartmentSkillSet.defaultSkills(for: .general)
        }
        return companyStore.getDepartmentSkills(for: emp.departmentType)
    }

    /// 이전 업무 기록 요약
    var workLogSummary: String {
        guard let emp = employee else { return "" }
        return EmployeeWorkLogService.shared.getWorkLogSummary(for: emp.id, employeeName: emp.name)
    }

    /// 프로젝트 문서 경로 정보
    var projectDocumentsInfo: String {
        guard let proj = project, let emp = employee else { return "" }
        let basePath = "datas/\(DataPathService.shared.sanitizeName(proj.name))"
        let deptPath = "\(basePath)/\(emp.departmentType.directoryName)"

        return """
        ## 📁 프로젝트 문서 경로
        당신이 작성한 문서는 다음 경로에 자동 저장됩니다:
        - 부서 문서: \(deptPath)/documents/
        - 직원 프로필: \(deptPath)/people/
        - 태스크: \(deptPath)/tasks/

        ## 📚 참고할 수 있는 문서
        다른 부서의 문서도 참고할 수 있습니다:
        - 기획팀: \(basePath)/기획/documents/
        - 디자인팀: \(basePath)/디자인/documents/
        - 개발팀: \(basePath)/개발/documents/
        - QA팀: \(basePath)/QA/documents/
        - 마케팅팀: \(basePath)/마케팅/documents/

        ## ⚠️ 중요: 문서 작성 전 필수 확인
        문서를 작성하기 전에 반드시 프로젝트 루트의 README.md 파일을 읽어주세요.
        경로: \(basePath)/README.md
        README.md에는 문서 구조, 명명 규칙, 부서별 문서 형식이 정의되어 있습니다.
        이 가이드를 따라야 팀 전체가 일관된 문서 체계를 유지할 수 있습니다.
        """
    }

    /// 프로젝트 컨텍스트가 포함된 시스템 프롬프트
    var systemPrompt: String {
        guard let emp = employee, let proj = project else { return "" }

        return """
        당신의 이름은 \(emp.name)입니다.
        당신은 "\(proj.name)" 프로젝트의 \(emp.departmentType.rawValue)팀 소속입니다.

        ## 프로젝트 정보
        - 프로젝트명: \(proj.name)
        - 설명: \(proj.description.isEmpty ? "없음" : proj.description)
        - 상태: \(proj.status.rawValue)
        - 우선순위: \(proj.priority.rawValue)

        \(projectDocumentsInfo)

        \(customSkills.fullPrompt)

        중요한 규칙:
        - 한국어로 대화합니다
        - 전문적이지만 친근하게 대화합니다
        - 질문할 때는 구체적이고 실무적인 질문을 합니다
        - 답변할 때는 10년 경력의 전문가답게 깊이 있는 인사이트를 제공합니다
        - 이 프로젝트의 맥락을 항상 고려하여 답변합니다
        - 다른 부서의 문서를 참고하여 협업에 활용합니다

        \(AIActionGuide.guide)

        📄 문서 작성 기능:
        문서를 작성해달라는 요청을 받으면, 다음 형식으로 마크다운 문서를 작성하세요:

        <<<FILE:파일명.md>>>
        (여기에 마크다운 내용)
        <<<END_FILE>>>

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

        🤝 프로젝트 내 다른 부서에 협업 요청:
        같은 프로젝트 내 다른 부서의 도움이 필요하면 멘션을 사용하세요:
        - @기획팀, @디자인팀, @개발팀, @QA팀, @마케팅팀

        멘션 형식:
        <<<MENTION:@부서명>>>
        [요청 내용을 구체적으로 작성]
        <<<END_MENTION>>>

        \(workLogSummary)
        """
    }

    var greetingQuestion: String {
        guard let emp = employee else { return "무엇을 도와드릴까요?" }
        let questions = emp.departmentType.onboardingQuestions
        let index = abs(emp.id.hashValue) % questions.count
        return questions[index]
    }

    /// 프로젝트 내 멘션 가능한 부서 목록
    var availableDepartments: [DepartmentType] {
        project?.departments.map { $0.type } ?? []
    }

    var body: some View {
        if let emp = employee {
            VStack(spacing: 0) {
                // Header
                ProjectChatHeader(
                    employee: emp,
                    projectName: project?.name ?? "프로젝트",
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
                                ChatBubble(message: message, aiType: emp.aiType)
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
                loadConversation()
                if messages.isEmpty {
                    sendGreeting()
                }
            }
        } else {
            Text("직원을 찾을 수 없습니다")
                .frame(width: 400, height: 300)
        }
    }

    private func loadConversation() {
        guard let emp = employee else { return }
        messages = emp.conversationHistory.map { msg in
            ChatMessage(
                role: msg.role == .user ? .user : .assistant,
                content: msg.content
            )
        }
    }

    private func sendGreeting() {
        guard let emp = employee else { return }
        isLoading = true
        companyStore.updateProjectEmployeeStatus(emp.id, inProject: projectId, status: .thinking)

        let greetingPrompt = """
        당신은 방금 "\(project?.name ?? "프로젝트")" 프로젝트에 배정되었고, PM/상사가 대화창을 열었습니다.

        다음 형식으로 인사하세요:
        1. 짧은 자기소개 (이름, 역할, 1문장)
        2. 프로젝트에 대한 기대감 표현 (1문장)
        3. 업무 시작을 위해 꼭 알아야 할 질문 하나

        반드시 다음 질문을 포함하세요:
        "\(greetingQuestion)"

        전체 4-5문장으로 짧고 전문적으로 작성하세요.
        """

        Task {
            do {
                let response: String

                if canUseClaudeCode && useClaudeCode {
                    response = try await claudeCodeService.sendMessage(
                        greetingPrompt,
                        systemPrompt: systemPrompt
                    )
                } else if let config = apiConfig, config.isConfigured {
                    response = try await claudeService.sendMessage(
                        greetingPrompt,
                        employeeId: emp.id,
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
                    companyStore.updateProjectEmployeeStatus(emp.id, inProject: projectId, status: .idle)
                    saveConversation()
                }
            } catch {
                await MainActor.run {
                    let greeting = "안녕하세요! \(emp.name)입니다. \(project?.name ?? "프로젝트")에서 함께하게 되어 기쁩니다. 무엇을 도와드릴까요?"
                    messages.append(ChatMessage(role: .assistant, content: greeting))
                    errorMessage = error.localizedDescription
                    isLoading = false
                    companyStore.updateProjectEmployeeStatus(emp.id, inProject: projectId, status: .idle)
                }
            }
        }
    }

    private func sendMessage() {
        guard let emp = employee else { return }
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

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
        companyStore.updateProjectEmployeeStatus(emp.id, inProject: projectId, status: .thinking)

        Task {
            do {
                let response: String

                if hasClaudeCode {
                    response = try await claudeCodeService.sendMessage(
                        messageToSend,
                        systemPrompt: systemPrompt,
                        conversationHistory: employee?.conversationHistory ?? []
                    )
                } else if let config = apiConfig, config.isConfigured {
                    response = try await claudeService.sendMessage(
                        messageToSend,
                        employeeId: emp.id,
                        configuration: config,
                        systemPrompt: systemPrompt
                    )
                } else {
                    throw ClaudeCodeError.notInstalled
                }

                // ✨ AI 액션 파싱 및 실행
                let actions = await AIActionParser.shared.parseActions(from: response)
                var actionResults: [String] = []

                if !actions.isEmpty {
                    await AIActionParser.shared.executeActions(
                        actions,
                        projectId: projectId,
                        employeeId: emp.id,
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

                // 응답에서 멘션 추출 및 처리 (기존 로직)
                let (cleanedResponse, mentionResponses) = await extractAndProcessMentions(from: fileCleanedResponse)

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
                    companyStore.updateProjectEmployeeStatus(emp.id, inProject: projectId, status: .idle)

                    saveConversation()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                    companyStore.updateProjectEmployeeStatus(emp.id, inProject: projectId, status: .idle)
                }
            }
        }
    }

    var wikiCategory: WikiCategory {
        guard let emp = employee else { return .reference }
        switch emp.departmentType {
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

    private func extractAndSaveFiles(from response: String) -> (cleanedResponse: String, savedFiles: [String]) {
        var cleanedResponse = response
        var savedFiles: [String] = []

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

            let document = WikiDocument(
                title: (fileName as NSString).deletingPathExtension.replacingOccurrences(of: "-", with: " "),
                content: content,
                category: wikiCategory,
                createdBy: employee?.name ?? "Unknown",
                tags: [employee?.departmentType.rawValue ?? "general", employee?.name ?? "Unknown", project?.name ?? "Project"],
                fileName: fileName
            )

            do {
                // 부서별 documents 폴더에 저장
                if let deptDocsPath = departmentDocumentsPath {
                    let filePath = (deptDocsPath as NSString).appendingPathComponent(fileName)
                    try content.write(toFile: filePath, atomically: true, encoding: .utf8)
                    savedFiles.append(fileName)

                    // CompanyStore에도 등록 (앱 내에서 문서 목록 표시용)
                    companyStore.addWikiDocument(document)
                }
            } catch {
                print("파일 저장 실패: \(error)")
            }

            cleanedResponse = (cleanedResponse as NSString).replacingCharacters(in: fullRange, with: "")
        }

        return (cleanedResponse.trimmingCharacters(in: .whitespacesAndNewlines), savedFiles)
    }

    /// AI 응답에서 멘션을 추출하고 해당 부서에 요청 (프로젝트 내)
    private func extractAndProcessMentions(from response: String) async -> (cleanedResponse: String, mentionResponses: [String]) {
        guard let proj = project, let currentEmp = employee else {
            return (response, [])
        }

        var cleanedResponse = response
        var mentionResponses: [String] = []

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

            // 프로젝트 내 해당 부서 찾기
            if let targetDept = findProjectDepartment(byName: departmentName, in: proj),
               let targetEmployee = targetDept.employees.first {

                let mentionMessage = ChatMessage(role: .assistant, content: "🔄 @\(departmentName)에 협업 요청 중...")
                await MainActor.run {
                    messages.append(mentionMessage)
                }

                do {
                    let mentionSystemPrompt = """
                    당신은 \(targetEmployee.name)입니다. "\(proj.name)" 프로젝트의 \(targetDept.type.rawValue)팀 소속입니다.
                    \(targetDept.type.expertRolePrompt)

                    같은 프로젝트의 \(currentEmp.departmentType.rawValue)팀 \(currentEmp.name)에서 협업 요청이 왔습니다.
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

                    // 협업 기록 저장 (프로젝트 정보 포함)
                    let record = CollaborationRecord(
                        requesterId: currentEmp.id,
                        requesterName: currentEmp.name,
                        requesterDepartment: currentEmp.departmentType.rawValue,
                        responderId: targetEmployee.id,
                        responderName: targetEmployee.name,
                        responderDepartment: targetDept.type.rawValue,
                        requestContent: requestContent,
                        responseContent: mentionResponse,
                        projectId: proj.id,
                        projectName: proj.name,
                        tags: [currentEmp.departmentType.rawValue, targetDept.type.rawValue, proj.name]
                    )
                    await MainActor.run {
                        companyStore.addCollaborationRecord(record)
                    }

                } catch {
                    mentionResponses.append("📨 **@\(departmentName) 응답 실패:** \(error.localizedDescription)")
                }
            } else {
                mentionResponses.append("⚠️ 프로젝트 내 '\(departmentName)' 부서를 찾을 수 없습니다.")
            }

            cleanedResponse = (cleanedResponse as NSString).replacingCharacters(in: fullRange, with: "")
        }

        return (cleanedResponse.trimmingCharacters(in: .whitespacesAndNewlines), mentionResponses)
    }

    /// 프로젝트 내 부서명으로 부서 찾기
    private func findProjectDepartment(byName name: String, in project: Project) -> ProjectDepartment? {
        let normalizedName = name.replacingOccurrences(of: "팀", with: "").trimmingCharacters(in: .whitespaces)

        return project.departments.first { dept in
            let deptName = dept.type.rawValue.replacingOccurrences(of: "팀", with: "")
            return deptName.contains(normalizedName) || normalizedName.contains(deptName)
        }
    }

    private func saveConversation() {
        let newMessages = messages.map { msg in
            Message(
                role: msg.role == .user ? .user : .assistant,
                content: msg.content
            )
        }
        companyStore.updateProjectEmployeeConversation(projectId: projectId, employeeId: employeeId, messages: newMessages)

        // 업무 기록 저장
        saveWorkLog()
    }

    /// 업무 기록 저장
    private func saveWorkLog() {
        guard let emp = employee else { return }

        // 최소 4개 이상의 메시지가 있을 때만 저장
        guard messages.count >= 4 else { return }

        // 마지막 대화 내용을 기반으로 업무 기록 생성
        let recentMessages = messages.suffix(4)
        let userMessages = recentMessages.filter { $0.role == .user }.map { $0.content }
        let assistantMessages = recentMessages.filter { $0.role == .assistant }.map { $0.content }

        // 대화 요약 생성
        let summary = userMessages.joined(separator: " / ")
        let keyPoints = assistantMessages.compactMap { msg -> String? in
            let firstSentence = msg.components(separatedBy: CharacterSet(charactersIn: ".!?")).first ?? ""
            return firstSentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : firstSentence.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // 업무 기록 서비스에 저장 (프로젝트별 + 전사 기록)
        if let proj = project {
            EmployeeWorkLogService.shared.addProjectConversationSummary(
                projectName: proj.name,
                department: emp.departmentType,
                employeeId: emp.id,
                employeeName: emp.name,
                conversationSummary: summary.prefix(200).description,
                keyPoints: Array(keyPoints.prefix(3)),
                actionItems: []
            )
        } else {
            EmployeeWorkLogService.shared.addConversationSummary(
                for: emp.id,
                employeeName: emp.name,
                departmentType: emp.departmentType,
                conversationSummary: summary.prefix(200).description,
                keyPoints: Array(keyPoints.prefix(3)),
                actionItems: []
            )
        }
    }

    private func clearConversation() {
        messages.removeAll()
        companyStore.updateProjectEmployeeConversation(projectId: projectId, employeeId: employeeId, messages: [])
        sendGreeting()
    }

    /// 업무 결과 문서화 요청
    private func requestDocumentize() {
        guard messages.count >= 2 else {
            errorMessage = "문서화할 대화 내용이 충분하지 않습니다."
            return
        }

        inputText = "지금까지 논의된 내용을 정리하여 위키 문서로 작성해주세요. 핵심 내용, 결정 사항, 액션 아이템을 포함해주세요."
        sendMessage()
    }
}

struct ProjectChatHeader: View {
    let employee: ProjectEmployee
    let projectName: String
    let onClose: () -> Void
    let onClearConversation: () -> Void
    let onDocumentize: () -> Void

    var body: some View {
        HStack {
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
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text(projectName)
                            .font(.body)
                            .foregroundStyle(.secondary)
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

#Preview {
    ProjectEmployeeChatView(projectId: UUID(), employeeId: UUID())
        .environmentObject(CompanyStore())
}
