import Foundation

/// Claude Code CLI를 사용하여 대화하는 서비스
/// Claude Code가 이미 인증되어 있으면 별도 API 키 없이 사용 가능
actor ClaudeCodeService {

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

    /// Claude Code를 사용하여 메시지 전송
    func sendMessage(
        _ content: String,
        systemPrompt: String? = nil
    ) async throws -> String {
        guard let claudePath = findClaudeCodePath() else {
            throw ClaudeCodeError.notInstalled
        }

        // 전체 프롬프트 구성
        var fullPrompt = ""
        if let system = systemPrompt {
            fullPrompt = "System: \(system)\n\nUser: \(content)"
        } else {
            fullPrompt = content
        }

        // Claude Code CLI 실행 (--print 옵션으로 결과만 출력)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: claudePath)
        process.arguments = ["--print", fullPrompt]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // 환경 변수 설정 (터미널 환경 상속)
        var environment = ProcessInfo.processInfo.environment
        environment["HOME"] = NSHomeDirectory()
        environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:\(NSHomeDirectory())/.local/bin"
        process.environment = environment

        return try await withCheckedThrowingContinuation { continuation in
            do {
                try process.run()

                // 비동기로 결과 대기
                DispatchQueue.global().async {
                    process.waitUntilExit()

                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                    if process.terminationStatus == 0 {
                        if let output = String(data: outputData, encoding: .utf8)?
                            .trimmingCharacters(in: .whitespacesAndNewlines),
                           !output.isEmpty {
                            continuation.resume(returning: output)
                        } else {
                            continuation.resume(throwing: ClaudeCodeError.emptyResponse)
                        }
                    } else {
                        let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                        continuation.resume(throwing: ClaudeCodeError.executionFailed(errorMessage))
                    }
                }
            } catch {
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
