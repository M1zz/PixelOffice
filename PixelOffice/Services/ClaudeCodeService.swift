import Foundation

/// Claude Code CLI를 사용하여 대화하는 서비스
/// Claude Code가 이미 인증되어 있으면 별도 API 키 없이 사용 가능
actor ClaudeCodeService {

    /// 로그 파일 경로 (프로젝트 디렉토리 내)
    private var logFilePath: String {
        let logsDir = DataPathService.shared.logsPath

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let fileName = "claude-\(dateFormatter.string(from: Date())).log"

        return (logsDir as NSString).appendingPathComponent(fileName)
    }

    /// 로그 기록
    private func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logMessage = "[\(timestamp)] \(message)\n"

        if let data = logMessage.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFilePath) {
                if let fileHandle = FileHandle(forWritingAtPath: logFilePath) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                FileManager.default.createFile(atPath: logFilePath, contents: data)
            }
        }

        // 콘솔에도 출력
        print("[ClaudeCode] \(message)")
    }

    /// Claude Code CLI 경로 찾기
    private func findClaudeCodePath() -> String? {
        // 사용자 홈 디렉토리
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        // 일반적인 설치 경로들
        let possiblePaths = [
            "\(home)/.local/bin/claude",  // 가장 일반적인 경로
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
            "\(home)/.npm-global/bin/claude",
            "/usr/bin/claude"
        ]

        for path in possiblePaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        return nil
    }

    /// Claude Code CLI가 설치되어 있는지 확인
    func isClaudeCodeAvailable() -> Bool {
        return findClaudeCodePath() != nil
    }

    /// 실제 토큰 사용량 결과
    struct TokenUsage: Codable {
        let response: String
        let inputTokens: Int
        let outputTokens: Int
        let cacheReadInputTokens: Int
        let cacheCreationInputTokens: Int
        let totalCostUSD: Double
        let model: String
        let timestamp: Date

        /// 총 입력 토큰 (캐시 포함)
        var totalInputTokens: Int {
            inputTokens + cacheReadInputTokens + cacheCreationInputTokens
        }
    }

    /// Claude Code JSON 응답 파싱용 구조체
    private struct ClaudeCodeResponse: Codable {
        let type: String
        let result: String?
        let is_error: Bool
        let total_cost_usd: Double?
        let usage: Usage?
        let modelUsage: [String: ModelUsage]?

        struct Usage: Codable {
            let input_tokens: Int?
            let output_tokens: Int?
            let cache_read_input_tokens: Int?
            let cache_creation_input_tokens: Int?
        }

        struct ModelUsage: Codable {
            let inputTokens: Int?
            let outputTokens: Int?
            let cacheReadInputTokens: Int?
            let cacheCreationInputTokens: Int?
            let costUSD: Double?
        }
    }

    /// Claude Code를 사용하여 메시지 전송 (실제 토큰 사용량 반환)
    /// - Parameters:
    ///   - content: 현재 사용자 메시지
    ///   - systemPrompt: 시스템 프롬프트
    ///   - conversationHistory: 이전 대화 히스토리 (Message 배열)
    /// - Returns: TokenUsage (응답 + 실제 토큰 사용량)
    func sendMessageWithTokens(
        _ content: String,
        systemPrompt: String? = nil,
        conversationHistory: [Message] = [],
        autoApprove: Bool = false
    ) async throws -> TokenUsage {
        let jsonResponse = try await sendMessageJSON(content, systemPrompt: systemPrompt, conversationHistory: conversationHistory, autoApprove: autoApprove)
        return jsonResponse
    }

    /// Claude Code를 사용하여 메시지 전송 (JSON 응답으로 토큰 사용량 포함)
    private func sendMessageJSON(
        _ content: String,
        systemPrompt: String? = nil,
        conversationHistory: [Message] = [],
        autoApprove: Bool = false
    ) async throws -> TokenUsage {
        log("=== 새 요청 시작 (JSON 모드) ===")
        log("사용자 메시지: \(content)")

        guard let claudePath = findClaudeCodePath() else {
            log("ERROR: Claude Code가 설치되어 있지 않음")
            throw ClaudeCodeError.notInstalled
        }

        // 전체 프롬프트 구성
        var fullPrompt = ""
        if let system = systemPrompt {
            fullPrompt = "System: \(system)\n\n"
        }
        if !conversationHistory.isEmpty {
            fullPrompt += "=== 이전 대화 내용 ===\n"
            for message in conversationHistory {
                let role = message.role == .user ? "User" : "Assistant"
                let content = message.content.count > 500
                    ? String(message.content.prefix(500)) + "..."
                    : message.content
                fullPrompt += "\(role): \(content)\n\n"
            }
            fullPrompt += "=== 현재 대화 ===\n"
        }
        fullPrompt += "User: \(content)"

        // Claude Code CLI 실행 (--output-format json)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: claudePath)

        var args = ["--print", "--output-format", "json"]
        if autoApprove {
            args.append("--dangerously-skip-permissions")
        } else {
            args.append(contentsOf: ["--allowedTools", "WebSearch,WebFetch,Read,Glob,Grep"])
        }
        process.arguments = args

        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        var environment = ProcessInfo.processInfo.environment
        environment["HOME"] = NSHomeDirectory()
        environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:\(NSHomeDirectory())/.local/bin"
        process.environment = environment

        return try await withCheckedThrowingContinuation { [self] continuation in
            do {
                try process.run()
                log("프로세스 시작됨 (JSON 모드)")

                if let promptData = fullPrompt.data(using: .utf8) {
                    inputPipe.fileHandleForWriting.write(promptData)
                }
                inputPipe.fileHandleForWriting.closeFile()

                DispatchQueue.global().async { [self] in
                    process.waitUntilExit()

                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorString = String(data: errorData, encoding: .utf8) ?? ""

                    Task {
                        await self.log("종료 코드: \(process.terminationStatus)")
                        if !errorString.isEmpty {
                            await self.log("STDERR: \(errorString)")
                        }
                    }

                    if process.terminationStatus == 0 {
                        do {
                            let decoder = JSONDecoder()
                            let response = try decoder.decode(ClaudeCodeResponse.self, from: outputData)

                            let resultText = response.result ?? ""
                            let usage = response.usage
                            let modelName = response.modelUsage?.keys.first ?? "unknown"

                            let tokenUsage = TokenUsage(
                                response: resultText,
                                inputTokens: usage?.input_tokens ?? 0,
                                outputTokens: usage?.output_tokens ?? 0,
                                cacheReadInputTokens: usage?.cache_read_input_tokens ?? 0,
                                cacheCreationInputTokens: usage?.cache_creation_input_tokens ?? 0,
                                totalCostUSD: response.total_cost_usd ?? 0,
                                model: modelName,
                                timestamp: Date()
                            )

                            Task {
                                await self.log("📊 토큰 사용량: 입력=\(tokenUsage.inputTokens), 출력=\(tokenUsage.outputTokens), 캐시읽기=\(tokenUsage.cacheReadInputTokens), 비용=$\(String(format: "%.4f", tokenUsage.totalCostUSD))")
                                await self.log("=== 요청 완료 (JSON 성공) ===")
                            }

                            continuation.resume(returning: tokenUsage)
                        } catch {
                            Task { await self.log("ERROR: JSON 파싱 실패 - \(error.localizedDescription)") }
                            continuation.resume(throwing: ClaudeCodeError.executionFailed("JSON 파싱 실패: \(error.localizedDescription)"))
                        }
                    } else {
                        Task { await self.log("ERROR: 실행 실패 - \(errorString)") }
                        continuation.resume(throwing: ClaudeCodeError.executionFailed(errorString))
                    }
                }
            } catch {
                Task { await self.log("ERROR: 프로세스 시작 실패 - \(error.localizedDescription)") }
                continuation.resume(throwing: ClaudeCodeError.executionFailed(error.localizedDescription))
            }
        }
    }

    /// Claude Code를 사용하여 메시지 전송 (텍스트 응답만)
    /// - Parameters:
    ///   - content: 현재 사용자 메시지
    ///   - systemPrompt: 시스템 프롬프트
    ///   - conversationHistory: 이전 대화 히스토리 (Message 배열)
    ///   - autoApprove: true면 모든 권한을 자동 허용 (파이프라인용)
    func sendMessage(
        _ content: String,
        systemPrompt: String? = nil,
        conversationHistory: [Message] = [],
        autoApprove: Bool = false
    ) async throws -> String {
        log("=== 새 요청 시작 ===")
        log("사용자 메시지: \(content)")
        log("대화 히스토리 수: \(conversationHistory.count)개")
        if let system = systemPrompt {
            log("시스템 프롬프트: \(system.prefix(200))...")
        }

        guard let claudePath = findClaudeCodePath() else {
            log("ERROR: Claude Code가 설치되어 있지 않음")
            throw ClaudeCodeError.notInstalled
        }
        log("Claude Code 경로: \(claudePath)")

        // 전체 프롬프트 구성 (히스토리 포함)
        var fullPrompt = ""

        // 시스템 프롬프트
        if let system = systemPrompt {
            fullPrompt = "System: \(system)\n\n"
        }

        // 이전 대화 히스토리 추가
        if !conversationHistory.isEmpty {
            fullPrompt += "=== 이전 대화 내용 ===\n"
            for message in conversationHistory {
                let role = message.role == .user ? "User" : "Assistant"
                // 너무 긴 메시지는 요약
                let content = message.content.count > 500
                    ? String(message.content.prefix(500)) + "..."
                    : message.content
                fullPrompt += "\(role): \(content)\n\n"
            }
            fullPrompt += "=== 현재 대화 ===\n"
        }

        // 현재 사용자 메시지
        fullPrompt += "User: \(content)"

        // Claude Code CLI 실행 (--print 옵션으로 결과만 출력)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: claudePath)

        // 기본 인자
        var args = ["--print"]

        // autoApprove가 true면 모든 권한 자동 허용 (파이프라인용)
        if autoApprove {
            args.append("--dangerously-skip-permissions")
        } else {
            // 제한된 도구만 허용
            args.append(contentsOf: ["--allowedTools", "WebSearch,WebFetch,Read,Glob,Grep"])
        }

        process.arguments = args
        log("실행 인자: \(process.arguments ?? [])")

        // 프롬프트를 stdin으로 전달
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // 환경 변수 설정 (터미널 환경 상속)
        var environment = ProcessInfo.processInfo.environment
        environment["HOME"] = NSHomeDirectory()
        environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:\(NSHomeDirectory())/.local/bin"
        process.environment = environment

        return try await withCheckedThrowingContinuation { [self] continuation in
            do {
                try process.run()
                log("프로세스 시작됨")

                // stdin에 프롬프트 작성 후 닫기
                if let promptData = fullPrompt.data(using: .utf8) {
                    inputPipe.fileHandleForWriting.write(promptData)
                }
                inputPipe.fileHandleForWriting.closeFile()

                // 비동기로 결과 대기
                DispatchQueue.global().async { [self] in
                    process.waitUntilExit()

                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                    let outputString = String(data: outputData, encoding: .utf8) ?? ""
                    let errorString = String(data: errorData, encoding: .utf8) ?? ""

                    Task {
                        await self.log("종료 코드: \(process.terminationStatus)")
                        await self.log("STDOUT: \(outputString)")
                        if !errorString.isEmpty {
                            await self.log("STDERR: \(errorString)")
                        }
                    }

                    if process.terminationStatus == 0 {
                        let output = outputString.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !output.isEmpty {
                            Task { await self.log("=== 요청 완료 (성공) ===") }
                            continuation.resume(returning: output)
                        } else {
                            Task { await self.log("ERROR: 빈 응답") }
                            continuation.resume(throwing: ClaudeCodeError.emptyResponse)
                        }
                    } else {
                        Task { await self.log("ERROR: 실행 실패 - \(errorString)") }
                        continuation.resume(throwing: ClaudeCodeError.executionFailed(errorString))
                    }
                }
            } catch {
                Task { await self.log("ERROR: 프로세스 시작 실패 - \(error.localizedDescription)") }
                continuation.resume(throwing: ClaudeCodeError.executionFailed(error.localizedDescription))
            }
        }
    }
}

enum ClaudeCodeError: LocalizedError {
    case notInstalled
    case emptyResponse
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case .notInstalled:
            return "Claude Code가 설치되어 있지 않습니다. 터미널에서 'npm install -g @anthropic-ai/claude-code'로 설치하세요."
        case .emptyResponse:
            return "Claude Code에서 응답이 없습니다."
        case .executionFailed(let message):
            return "Claude Code 실행 실패: \(message)"
        }
    }
}
