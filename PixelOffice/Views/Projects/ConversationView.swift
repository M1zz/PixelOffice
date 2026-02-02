import SwiftUI

struct ConversationView: View {
    let task: ProjectTask
    let projectId: UUID
    let onClose: () -> Void
    
    @EnvironmentObject var companyStore: CompanyStore
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var scrollToBottom = false
    
    private let claudeService = ClaudeService()
    
    var assignee: Employee? {
        guard let id = task.assigneeId else { return nil }
        return companyStore.getEmployee(byId: id)
    }
    
    var apiConfig: APIConfiguration? {
        guard let employee = assignee else { return nil }
        return companyStore.getAPIConfiguration(for: employee.aiType)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            ConversationHeader(
                task: task,
                assignee: assignee,
                onClose: onClose
            )
            
            Divider()
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // Initial prompt if exists
                        if !task.prompt.isEmpty && task.conversation.isEmpty {
                            PromptBubble(prompt: task.prompt)
                        }
                        
                        // Conversation messages
                        ForEach(task.conversation) { message in
                            MessageBubble(message: message, aiType: assignee?.aiType ?? .claude)
                        }
                        
                        // Loading indicator
                        if isLoading {
                            LoadingBubble(aiType: assignee?.aiType ?? .claude)
                        }
                        
                        // Error message
                        if let error = errorMessage {
                            ErrorBubble(message: error) {
                                errorMessage = nil
                            }
                        }
                        
                        // Scroll anchor
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding()
                }
                .onChange(of: task.conversation.count) { _, _ in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .onChange(of: isLoading) { _, _ in
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            
            Divider()
            
            // Input area
            ConversationInput(
                text: $inputText,
                isLoading: isLoading,
                isConfigured: apiConfig?.isConfigured ?? false,
                onSend: sendMessage,
                onSendWithPrompt: sendInitialPrompt
            )
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let content = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        inputText = ""
        
        Task {
            await sendToAI(content: content)
        }
    }
    
    private func sendInitialPrompt() {
        guard !task.prompt.isEmpty else { return }
        
        Task {
            await sendToAI(content: task.prompt, isInitialPrompt: true)
        }
    }
    
    private func sendToAI(content: String, isInitialPrompt: Bool = false) async {
        guard let employee = assignee,
              let config = apiConfig,
              config.isConfigured else {
            await MainActor.run {
                errorMessage = "API가 설정되지 않았습니다. 설정에서 API 키를 입력하세요."
            }
            return
        }
        
        // Add user message
        let userMessage = Message.userMessage(content)
        await MainActor.run {
            companyStore.addMessageToTask(message: userMessage, taskId: task.id, projectId: projectId)
            isLoading = true
            errorMessage = nil
            
            // Update employee status
            companyStore.updateEmployeeStatus(employee.id, status: .working)
        }
        
        // Build system prompt
        let systemPrompt = buildSystemPrompt()
        
        do {
            let response = try await claudeService.sendMessage(
                content,
                employeeId: employee.id,
                configuration: config,
                systemPrompt: systemPrompt
            )
            
            await MainActor.run {
                let assistantMessage = Message.assistantMessage(response)
                companyStore.addMessageToTask(message: assistantMessage, taskId: task.id, projectId: projectId)
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    private func buildSystemPrompt() -> String {
        var prompt = """
        당신은 \(assignee?.name ?? "AI 직원")입니다.
        부서: \(task.departmentType.rawValue)
        담당 업무: \(task.title)
        
        """
        
        if !task.description.isEmpty {
            prompt += "작업 설명: \(task.description)\n\n"
        }
        
        prompt += """
        전문적이고 친절하게 응대하되, 주어진 태스크에 집중해서 도움을 제공하세요.
        필요한 경우 코드, 문서, 기획안 등을 작성해주세요.
        """
        
        return prompt
    }
}

struct ConversationHeader: View {
    let task: ProjectTask
    let assignee: Employee?
    let onClose: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Employee avatar
            if let employee = assignee {
                ZStack {
                    Circle()
                        .fill(employee.aiType.color.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    PixelCharacter(
                        appearance: employee.characterAppearance,
                        status: employee.status,
                        aiType: employee.aiType
                    )
                    .scaleEffect(0.6)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(employee.name)
                        .font(.headline)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(employee.status.color)
                            .frame(width: 6, height: 6)
                        Text(employee.status.rawValue)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Task info
            VStack(alignment: .trailing, spacing: 2) {
                Text(task.title)
                    .font(.subheadline)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Image(systemName: task.departmentType.icon)
                    Text(task.departmentType.rawValue)
                }
                .font(.callout)
                .foregroundStyle(task.departmentType.color)
            }
            
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}

struct ConversationInput: View {
    @Binding var text: String
    let isLoading: Bool
    let isConfigured: Bool
    let onSend: () -> Void
    let onSendWithPrompt: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            if !isConfigured {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("API 키가 설정되지 않았습니다")
                        .font(.callout)
                    Spacer()
                    Button("설정 열기") {
                        // TODO: Open settings
                    }
                    .font(.callout)
                }
                .padding(.horizontal)
            }
            
            HStack(spacing: 12) {
                // Text input
                TextField("메시지를 입력하세요...", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .padding(10)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .disabled(isLoading || !isConfigured)
                    .onSubmit {
                        if !text.isEmpty {
                            onSend()
                        }
                    }
                
                // Send button
                Button {
                    onSend()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.title3)
                }
                .buttonStyle(.borderedProminent)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading || !isConfigured)
            }
            .padding()
        }
    }
}

struct MessageBubble: View {
    let message: Message
    let aiType: AIType
    
    var isUser: Bool {
        message.role == .user
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if !isUser {
                // AI avatar
                ZStack {
                    Circle()
                        .fill(aiType.color.opacity(0.2))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: aiType.icon)
                        .foregroundStyle(aiType.color)
                        .font(.callout)
                }
            }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .textSelection(.enabled)
                    .padding(12)
                    .background(isUser ? Color.accentColor : Color(white: 0.15))
                    .foregroundStyle(isUser ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                
                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 400, alignment: isUser ? .trailing : .leading)
            
            if isUser {
                // User avatar
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.2))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "person.fill")
                        .foregroundStyle(Color.accentColor)
                        .font(.callout)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }
}

struct PromptBubble: View {
    let prompt: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.text.fill")
                Text("작업 프롬프트")
                    .font(.callout.bold())
            }
            .foregroundStyle(.secondary)
            
            Text(prompt)
                .font(.callout)
                .padding()
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct LoadingBubble: View {
    let aiType: AIType
    @State private var dotCount = 0
    
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ZStack {
                Circle()
                    .fill(aiType.color.opacity(0.2))
                    .frame(width: 32, height: 32)
                
                Image(systemName: aiType.icon)
                    .foregroundStyle(aiType.color)
                    .font(.callout)
            }
            
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(aiType.color)
                        .frame(width: 8, height: 8)
                        .opacity(dotCount % 3 == i ? 1 : 0.3)
                }
            }
            .padding(16)
            .background(Color(white: 0.15))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            Spacer()
        }
        .onReceive(timer) { _ in
            dotCount += 1
        }
    }
}

struct ErrorBubble: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            
            Text(message)
                .font(.callout)
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ConversationView(
        task: ProjectTask(
            title: "앱 기획서 작성",
            description: "새로운 iOS 앱의 기획서 작성",
            status: .inProgress,
            departmentType: .planning,
            prompt: "iOS 앱의 기획서를 작성해주세요. 주요 기능과 타겟 사용자를 정의하고, 경쟁 앱 분석도 포함해주세요."
        ),
        projectId: UUID(),
        onClose: {}
    )
    .environmentObject(CompanyStore())
    .frame(width: 500, height: 600)
}
