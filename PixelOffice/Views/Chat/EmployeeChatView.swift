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

    /// 위키 폴더 경로
    var wikiPath: String {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("PixelOffice-Wiki").path
    }

    /// 부서별 전문가 역할이 반영된 시스템 프롬프트
    var systemPrompt: String {
        """
        당신의 이름은 \(employee.name)입니다.
        당신은 \(departmentType.rawValue)팀 소속입니다.

        \(departmentType.expertRolePrompt)

        중요한 규칙:
        - 한국어로 대화합니다
        - 전문적이지만 친근하게 대화합니다
        - 질문할 때는 구체적이고 실무적인 질문을 합니다
        - 답변할 때는 10년 경력의 전문가답게 깊이 있는 인사이트를 제공합니다

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
        """
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
                        systemPrompt: systemPrompt
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

                await MainActor.run {
                    // 응답에서 파일 추출 및 저장
                    let (cleanedResponse, savedFiles) = extractAndSaveFiles(from: response)

                    let assistantMessage = ChatMessage(role: .assistant, content: cleanedResponse)
                    messages.append(assistantMessage)
                    isLoading = false
                    companyStore.updateEmployeeStatus(employee.id, status: .idle)  // 휴식중으로 변경

                    // 저장된 파일이 있으면 알림
                    if !savedFiles.isEmpty {
                        let fileNames = savedFiles.joined(separator: ", ")
                        let fileMessage = ChatMessage(role: .assistant, content: "📄 문서가 저장되었습니다: \(fileNames)\n위치: ~/Documents/PixelOffice-Wiki/")
                        messages.append(fileMessage)
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
                createdBy: employee.name,
                tags: [departmentType.rawValue, employee.name],
                fileName: fileName
            )

            // WikiService를 통해 저장 (카테고리 폴더에 저장됨)
            do {
                try WikiService.shared.saveDocument(document, at: wikiPath)
                savedFiles.append(fileName)

                // CompanyStore에 등록
                companyStore.addWikiDocument(document)
            } catch {
                print("파일 저장 실패: \(error)")
            }

            // 응답에서 파일 블록 제거
            cleanedResponse = (cleanedResponse as NSString).replacingCharacters(in: fullRange, with: "")
        }

        return (cleanedResponse.trimmingCharacters(in: .whitespacesAndNewlines), savedFiles)
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
    let onSend: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TextField(isConfigured ? "메시지를 입력하세요..." : "API 설정이 필요합니다", text: $text)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color(NSColor.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .disabled(!isConfigured || isLoading)
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
