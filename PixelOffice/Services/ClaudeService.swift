import Foundation

actor ClaudeService {
    private var sessions: [UUID: [Message]] = [:]
    
    // MARK: - Session Management
    
    func createSession(for employeeId: UUID) {
        sessions[employeeId] = []
    }
    
    func clearSession(for employeeId: UUID) {
        sessions[employeeId] = []
    }
    
    func getSessionHistory(for employeeId: UUID) -> [Message] {
        sessions[employeeId] ?? []
    }
    
    // MARK: - API Communication
    
    func sendMessage(
        _ content: String,
        employeeId: UUID,
        configuration: APIConfiguration,
        systemPrompt: String? = nil,
        isGreeting: Bool = false
    ) async throws -> String {
        // Initialize session if needed
        if sessions[employeeId] == nil {
            sessions[employeeId] = []
        }

        // 인사말인 경우: 임시 메시지 리스트를 만들어 요청만 하고 히스토리에 저장하지 않음
        let messagesForRequest: [Message]
        if isGreeting {
            // 인사말 요청은 히스토리에 저장하지 않음
            let tempMessage = Message.userMessage(content)
            messagesForRequest = [tempMessage]
        } else {
            // 일반 메시지는 히스토리에 추가
            let userMessage = Message.userMessage(content)
            sessions[employeeId]?.append(userMessage)
            messagesForRequest = sessions[employeeId] ?? []
        }

        // Build request based on AI type
        let response: String

        switch configuration.type {
        case .claude:
            response = try await sendClaudeRequest(
                messages: messagesForRequest,
                configuration: configuration,
                systemPrompt: systemPrompt
            )
        case .gpt:
            response = try await sendOpenAIRequest(
                messages: messagesForRequest,
                configuration: configuration,
                systemPrompt: systemPrompt
            )
        case .gemini:
            response = try await sendGeminiRequest(
                messages: messagesForRequest,
                configuration: configuration,
                systemPrompt: systemPrompt
            )
        case .local:
            response = try await sendLocalRequest(
                messages: messagesForRequest,
                configuration: configuration,
                systemPrompt: systemPrompt
            )
        }

        // Add assistant response to history (인사말도 응답은 저장)
        let assistantMessage = Message.assistantMessage(response)
        sessions[employeeId]?.append(assistantMessage)

        return response
    }
    
    // MARK: - Claude API

    private func sendClaudeRequest(
        messages: [Message],
        configuration: APIConfiguration,
        systemPrompt: String?
    ) async throws -> String {
        let url = URL(string: "\(configuration.effectiveBaseURL)/messages")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("web-search-2025-03-05", forHTTPHeaderField: "anthropic-beta")

        let claudeMessages = messages.filter { $0.role != .system }.map { message in
            [
                "role": message.role.rawValue,
                "content": message.content
            ]
        }

        // 웹 검색 도구 정의
        let webSearchTool: [String: Any] = [
            "type": "web_search_20250305",
            "name": "web_search",
            "max_uses": 5
        ]

        var body: [String: Any] = [
            "model": configuration.model,
            "max_tokens": configuration.maxTokens,
            "messages": claudeMessages,
            "tools": [webSearchTool]
        ]

        if let systemPrompt = systemPrompt {
            body["system"] = systemPrompt
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]] else {
            throw APIError.parsingError
        }

        // 응답에서 텍스트 추출 (웹 검색 결과 포함 가능)
        var resultText = ""
        for block in content {
            if let blockType = block["type"] as? String {
                if blockType == "text", let text = block["text"] as? String {
                    resultText += text
                } else if blockType == "web_search_tool_result" {
                    // 웹 검색 결과는 Claude가 자동으로 처리하여 텍스트로 반환
                    continue
                }
            }
        }

        if resultText.isEmpty {
            throw APIError.parsingError
        }

        return resultText
    }
    
    // MARK: - OpenAI API
    
    private func sendOpenAIRequest(
        messages: [Message],
        configuration: APIConfiguration,
        systemPrompt: String?
    ) async throws -> String {
        let url = URL(string: "\(configuration.effectiveBaseURL)/chat/completions")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        
        var openAIMessages: [[String: String]] = []
        
        if let systemPrompt = systemPrompt {
            openAIMessages.append(["role": "system", "content": systemPrompt])
        }
        
        for message in messages {
            openAIMessages.append([
                "role": message.role.rawValue,
                "content": message.content
            ])
        }
        
        let body: [String: Any] = [
            "model": configuration.model,
            "max_tokens": configuration.maxTokens,
            "temperature": configuration.temperature,
            "messages": openAIMessages
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw APIError.parsingError
        }
        
        return content
    }
    
    // MARK: - Gemini API
    
    private func sendGeminiRequest(
        messages: [Message],
        configuration: APIConfiguration,
        systemPrompt: String?
    ) async throws -> String {
        let url = URL(string: "\(configuration.effectiveBaseURL)/models/\(configuration.model):generateContent?key=\(configuration.apiKey)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var contents: [[String: Any]] = []
        
        if let systemPrompt = systemPrompt {
            contents.append([
                "role": "user",
                "parts": [["text": "System: \(systemPrompt)"]]
            ])
            contents.append([
                "role": "model",
                "parts": [["text": "understood."]]
            ])
        }
        
        for message in messages {
            let role = message.role == .assistant ? "model" : "user"
            contents.append([
                "role": role,
                "parts": [["text": message.content]]
            ])
        }
        
        let body: [String: Any] = [
            "contents": contents,
            "generationConfig": [
                "maxOutputTokens": configuration.maxTokens,
                "temperature": configuration.temperature
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw APIError.parsingError
        }
        
        return text
    }
    
    // MARK: - Local LLM (Ollama)
    
    private func sendLocalRequest(
        messages: [Message],
        configuration: APIConfiguration,
        systemPrompt: String?
    ) async throws -> String {
        let url = URL(string: "\(configuration.effectiveBaseURL)/chat")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var ollamaMessages: [[String: String]] = []
        
        if let systemPrompt = systemPrompt {
            ollamaMessages.append(["role": "system", "content": systemPrompt])
        }
        
        for message in messages {
            ollamaMessages.append([
                "role": message.role.rawValue,
                "content": message.content
            ])
        }
        
        let body: [String: Any] = [
            "model": configuration.model,
            "messages": ollamaMessages,
            "stream": false
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw APIError.parsingError
        }
        
        return content
    }
}

// MARK: - Errors

enum APIError: LocalizedError {
    case invalidResponse
    case serverError(statusCode: Int, message: String)
    case parsingError
    case notConfigured
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "잘못된 응답입니다."
        case .serverError(let statusCode, let message):
            return "서버 오류 (\(statusCode)): \(message)"
        case .parsingError:
            return "응답 파싱에 실패했습니다."
        case .notConfigured:
            return "API가 설정되지 않았습니다."
        case .networkError(let error):
            return "네트워크 오류: \(error.localizedDescription)"
        }
    }
}
