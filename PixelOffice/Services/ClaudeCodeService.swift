import Foundation

/// Claude Code CLI를 사용하여 대화하는 서비스
/// Claude Code가 이미 인증되어 있으면 별도 API 키 없이 사용 가능
actor ClaudeCodeService {

    /// 현재 실행 중인 프로세스 (취소용)
    private var runningProcess: Process?

    /// 전역 프로세스 관리자 (모든 실행 중인 프로세스 추적)
    static let processManager = ClaudeProcessManager()

    /// 현재 프로세스 취소
    func cancelCurrentProcess() {
        if let process = runningProcess, process.isRunning {
            process.terminate()
            runningProcess = nil
            log("프로세스 취소됨")
        }
    }

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

    /// 허용된 도구 목록 타입
    enum AllowedTools: String {
        case all = "all"  // 모든 도구 (dangerously-skip-permissions)
        case readOnly = "Read,Glob,Grep"  // 읽기만 가능
        case webOnly = "WebSearch,WebFetch,Read,Glob,Grep"  // 웹 + 읽기
        case none = ""  // 도구 없음 (--print만)

        var commandArgs: [String] {
            switch self {
            case .all:
                return ["--dangerously-skip-permissions"]
            case .none:
                return []  // 도구 없음
            case .readOnly, .webOnly:
                return ["--allowedTools", self.rawValue]
            }
        }
    }

    /// Claude Code를 사용하여 메시지 전송 (실제 토큰 사용량 반환)
    /// - Parameters:
    ///   - content: 현재 사용자 메시지
    ///   - systemPrompt: 시스템 프롬프트
    ///   - conversationHistory: 이전 대화 히스토리 (Message 배열)
    ///   - autoApprove: true면 모든 도구 허용, false면 제한된 도구만
    ///   - allowedTools: 직접 허용 도구 지정 (autoApprove보다 우선)
    /// - Returns: TokenUsage (응답 + 실제 토큰 사용량)
    func sendMessageWithTokens(
        _ content: String,
        systemPrompt: String? = nil,
        conversationHistory: [Message] = [],
        autoApprove: Bool = false,
        allowedTools: AllowedTools? = nil
    ) async throws -> TokenUsage {
        let tools = allowedTools ?? (autoApprove ? .all : .webOnly)
        let jsonResponse = try await sendMessageJSON(
            content,
            systemPrompt: systemPrompt,
            conversationHistory: conversationHistory,
            allowedTools: tools
        )
        return jsonResponse
    }

    /// Claude Code를 사용하여 메시지 전송 (JSON 응답으로 토큰 사용량 포함)
    private func sendMessageJSON(
        _ content: String,
        systemPrompt: String? = nil,
        conversationHistory: [Message] = [],
        allowedTools: AllowedTools = .webOnly
    ) async throws -> TokenUsage {
        log("=== 새 요청 시작 (JSON 모드) ===")
        log("사용자 메시지: \(content)")
        log("도구 모드: \(allowedTools.rawValue.isEmpty ? "none" : allowedTools.rawValue)")

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
        args.append(contentsOf: allowedTools.commandArgs)
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

        let processId = UUID()

        return try await withCheckedThrowingContinuation { [self] continuation in
            do {
                try process.run()
                log("프로세스 시작됨 (JSON 모드)")

                // 프로세스 매니저에 등록
                ClaudeCodeService.processManager.register(process, id: processId)

                if let promptData = fullPrompt.data(using: .utf8) {
                    inputPipe.fileHandleForWriting.write(promptData)
                }
                inputPipe.fileHandleForWriting.closeFile()

                DispatchQueue.global().async { [self] in
                    process.waitUntilExit()

                    // 프로세스 매니저에서 해제
                    ClaudeCodeService.processManager.unregister(id: processId)

                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorString = String(data: errorData, encoding: .utf8) ?? ""

                    // 취소된 경우 (SIGTERM = 15)
                    if process.terminationStatus == 15 {
                        Task { await self.log("프로세스가 취소됨") }
                        continuation.resume(throwing: ClaudeCodeError.cancelled)
                        return
                    }

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

                            // 토큰 사용량 추출: modelUsage 우선, 없으면 usage 사용
                            var inputTokens = 0
                            var outputTokens = 0
                            var cacheReadTokens = 0
                            var cacheCreationTokens = 0
                            var costUSD = response.total_cost_usd ?? 0
                            var modelName = "unknown"

                            // modelUsage에서 토큰 정보 추출 (새로운 형식)
                            if let modelUsage = response.modelUsage, let firstModel = modelUsage.first {
                                modelName = firstModel.key
                                let usage = firstModel.value
                                inputTokens = usage.inputTokens ?? 0
                                outputTokens = usage.outputTokens ?? 0
                                cacheReadTokens = usage.cacheReadInputTokens ?? 0
                                cacheCreationTokens = usage.cacheCreationInputTokens ?? 0
                                if let modelCost = usage.costUSD {
                                    costUSD = modelCost
                                }
                            }
                            // 기존 usage 형식에서 추출 (폴백)
                            else if let usage = response.usage {
                                inputTokens = usage.input_tokens ?? 0
                                outputTokens = usage.output_tokens ?? 0
                                cacheReadTokens = usage.cache_read_input_tokens ?? 0
                                cacheCreationTokens = usage.cache_creation_input_tokens ?? 0
                            }

                            let tokenUsage = TokenUsage(
                                response: resultText,
                                inputTokens: inputTokens,
                                outputTokens: outputTokens,
                                cacheReadInputTokens: cacheReadTokens,
                                cacheCreationInputTokens: cacheCreationTokens,
                                totalCostUSD: costUSD,
                                model: modelName,
                                timestamp: Date()
                            )

                            Task {
                                await self.log("📊 토큰 사용량: 입력=\(tokenUsage.inputTokens), 출력=\(tokenUsage.outputTokens), 캐시읽기=\(tokenUsage.cacheReadInputTokens), 비용=$\(String(format: "%.4f", tokenUsage.totalCostUSD)), 모델=\(modelName)")
                                await self.log("=== 요청 완료 (JSON 성공) ===")
                            }

                            continuation.resume(returning: tokenUsage)
                        } catch {
                            // JSON 파싱 실패 시 원본 데이터 로깅
                            let rawOutput = String(data: outputData, encoding: .utf8) ?? "파싱 불가"
                            Task { await self.log("ERROR: JSON 파싱 실패 - \(error.localizedDescription)\n원본: \(rawOutput.prefix(500))") }
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

        let processId = UUID()

        return try await withCheckedThrowingContinuation { [self] continuation in
            do {
                try process.run()
                log("프로세스 시작됨")

                // 프로세스 매니저에 등록
                ClaudeCodeService.processManager.register(process, id: processId)

                // stdin에 프롬프트 작성 후 닫기
                if let promptData = fullPrompt.data(using: .utf8) {
                    inputPipe.fileHandleForWriting.write(promptData)
                }
                inputPipe.fileHandleForWriting.closeFile()

                // 비동기로 결과 대기
                DispatchQueue.global().async { [self] in
                    process.waitUntilExit()

                    // 프로세스 매니저에서 해제
                    ClaudeCodeService.processManager.unregister(id: processId)

                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                    let outputString = String(data: outputData, encoding: .utf8) ?? ""
                    let errorString = String(data: errorData, encoding: .utf8) ?? ""

                    // 취소된 경우 (SIGTERM = 15)
                    if process.terminationStatus == 15 {
                        Task { await self.log("프로세스가 취소됨") }
                        continuation.resume(throwing: ClaudeCodeError.cancelled)
                        return
                    }

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
    case cancelled

    var errorDescription: String? {
        switch self {
        case .notInstalled:
            return "Claude Code가 설치되어 있지 않습니다. 터미널에서 'npm install -g @anthropic-ai/claude-code'로 설치하세요."
        case .emptyResponse:
            return "Claude Code에서 응답이 없습니다."
        case .executionFailed(let message):
            return "Claude Code 실행 실패: \(message)"
        case .cancelled:
            return "작업이 취소되었습니다."
        }
    }
}

/// 전역 Claude 프로세스 관리자
/// 실행 중인 모든 Claude Code 프로세스를 추적하고 일괄 종료 가능
class ClaudeProcessManager: @unchecked Sendable {
    private var runningProcesses: [UUID: Process] = [:]
    private let lock = NSLock()

    /// 실행 중인 프로세스 수
    var runningCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return runningProcesses.count
    }

    /// 프로세스 등록
    func register(_ process: Process, id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        runningProcesses[id] = process
        print("[ProcessManager] 프로세스 등록: \(id), 총 \(runningProcesses.count)개 실행 중")
    }

    /// 프로세스 등록 해제
    func unregister(id: UUID) {
        lock.lock()
        defer { lock.unlock() }
        runningProcesses.removeValue(forKey: id)
        print("[ProcessManager] 프로세스 해제: \(id), 총 \(runningProcesses.count)개 실행 중")
    }

    /// 모든 프로세스 중지
    func stopAll() {
        lock.lock()
        let processes = runningProcesses
        runningProcesses.removeAll()
        lock.unlock()

        for (id, process) in processes {
            if process.isRunning {
                process.terminate()
                print("[ProcessManager] 프로세스 종료: \(id)")
            }
        }
        print("[ProcessManager] 모든 프로세스 중지 완료 (\(processes.count)개)")
    }

    /// 특정 프로세스 중지
    func stop(id: UUID) {
        lock.lock()
        let process = runningProcesses.removeValue(forKey: id)
        lock.unlock()

        if let process = process, process.isRunning {
            process.terminate()
            print("[ProcessManager] 프로세스 종료: \(id)")
        }
    }
}
