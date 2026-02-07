import Foundation

/// xcodebuild 래퍼 서비스
actor BuildService {

    /// 빌드 설정
    struct BuildConfiguration {
        var projectPath: String
        var scheme: String?
        var configuration: String = "Debug"
        var destination: String = "platform=macOS"
        var derivedDataPath: String?
        var cleanBuild: Bool = false

        init(
            projectPath: String,
            scheme: String? = nil,
            configuration: String = "Debug",
            destination: String = "platform=macOS",
            derivedDataPath: String? = nil,
            cleanBuild: Bool = false
        ) {
            self.projectPath = projectPath
            self.scheme = scheme
            self.configuration = configuration
            self.destination = destination
            self.derivedDataPath = derivedDataPath
            self.cleanBuild = cleanBuild
        }
    }

    /// 빌드 실행
    /// - Parameter config: 빌드 설정
    /// - Returns: 빌드 시도 결과
    func build(config: BuildConfiguration) async throws -> BuildAttempt {
        let startedAt = Date()

        // xcodebuild 명령어 구성
        var arguments = [String]()

        // 프로젝트/워크스페이스 경로 결정
        let projectPath = config.projectPath
        if projectPath.hasSuffix(".xcworkspace") {
            arguments.append(contentsOf: ["-workspace", projectPath])
        } else if projectPath.hasSuffix(".xcodeproj") {
            arguments.append(contentsOf: ["-project", projectPath])
        } else {
            // 디렉토리인 경우 프로젝트 파일 탐색
            if let foundPath = findXcodeProject(in: projectPath) {
                if foundPath.hasSuffix(".xcworkspace") {
                    arguments.append(contentsOf: ["-workspace", foundPath])
                } else {
                    arguments.append(contentsOf: ["-project", foundPath])
                }
            }
        }

        // 스킴 설정
        if let scheme = config.scheme {
            arguments.append(contentsOf: ["-scheme", scheme])
        }

        // 설정
        arguments.append(contentsOf: ["-configuration", config.configuration])

        // 목적지
        arguments.append(contentsOf: ["-destination", config.destination])

        // 파생 데이터 경로
        if let derivedDataPath = config.derivedDataPath {
            arguments.append(contentsOf: ["-derivedDataPath", derivedDataPath])
        }

        // 클린 빌드
        if config.cleanBuild {
            arguments.append("clean")
        }
        arguments.append("build")

        // 추가 옵션
        arguments.append(contentsOf: ["-quiet", "-hideShellScriptEnvironment"])

        print("[BuildService] Running xcodebuild with args: \(arguments.joined(separator: " "))")

        // xcodebuild 실행
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
        process.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        // 환경 변수
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin"
        process.environment = environment

        return try await withCheckedThrowingContinuation { continuation in
            do {
                try process.run()

                DispatchQueue.global().async {
                    process.waitUntilExit()

                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                    let output = String(data: outputData, encoding: .utf8) ?? ""
                    let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                    let combinedOutput = output + "\n" + errorOutput

                    let completedAt = Date()
                    let success = process.terminationStatus == 0

                    // 에러 파싱
                    let errors = self.parseErrors(from: combinedOutput)

                    let attempt = BuildAttempt(
                        success: success,
                        exitCode: process.terminationStatus,
                        output: combinedOutput,
                        errors: errors,
                        startedAt: startedAt,
                        completedAt: completedAt
                    )

                    continuation.resume(returning: attempt)
                }
            } catch {
                let attempt = BuildAttempt(
                    success: false,
                    exitCode: -1,
                    output: "Failed to start xcodebuild: \(error.localizedDescription)",
                    errors: [BuildError(message: error.localizedDescription, severity: .error)],
                    startedAt: startedAt,
                    completedAt: Date()
                )
                continuation.resume(returning: attempt)
            }
        }
    }

    /// 간단한 빌드 (경로만 지정)
    func build(
        projectPath: String,
        scheme: String? = nil,
        configuration: String = "Debug"
    ) async throws -> BuildAttempt {
        let config = BuildConfiguration(
            projectPath: projectPath,
            scheme: scheme,
            configuration: configuration
        )
        return try await build(config: config)
    }

    /// 프로젝트 디렉토리에서 Xcode 프로젝트 파일 찾기
    private func findXcodeProject(in directory: String) -> String? {
        let fileManager = FileManager.default

        // 워크스페이스 우선 탐색
        if let contents = try? fileManager.contentsOfDirectory(atPath: directory) {
            // .xcworkspace 우선
            if let workspace = contents.first(where: { $0.hasSuffix(".xcworkspace") && !$0.contains("xcuserdata") }) {
                return (directory as NSString).appendingPathComponent(workspace)
            }
            // .xcodeproj
            if let project = contents.first(where: { $0.hasSuffix(".xcodeproj") }) {
                return (directory as NSString).appendingPathComponent(project)
            }
        }

        return nil
    }

    /// 빌드 출력에서 에러 파싱
    private func parseErrors(from output: String) -> [BuildError] {
        var errors: [BuildError] = []

        let lines = output.components(separatedBy: "\n")

        // Xcode 에러 패턴: /path/to/file.swift:123:45: error: message
        let errorPattern = #"(.+?):(\d+):(\d+):\s*(error|warning|note):\s*(.+)"#
        let regex = try? NSRegularExpression(pattern: errorPattern, options: [])

        for line in lines {
            if let match = regex?.firstMatch(in: line, options: [], range: NSRange(line.startIndex..., in: line)) {
                let fileRange = Range(match.range(at: 1), in: line)
                let lineRange = Range(match.range(at: 2), in: line)
                let columnRange = Range(match.range(at: 3), in: line)
                let severityRange = Range(match.range(at: 4), in: line)
                let messageRange = Range(match.range(at: 5), in: line)

                if let fileRange, let lineRange, let columnRange, let severityRange, let messageRange {
                    let file = String(line[fileRange])
                    let lineNum = Int(line[lineRange])
                    let column = Int(line[columnRange])
                    let severityStr = String(line[severityRange])
                    let message = String(line[messageRange])

                    let severity: BuildErrorSeverity = {
                        switch severityStr.lowercased() {
                        case "error": return .error
                        case "warning": return .warning
                        default: return .note
                        }
                    }()

                    errors.append(BuildError(
                        file: file,
                        line: lineNum,
                        column: column,
                        message: message,
                        severity: severity
                    ))
                }
            }

            // 일반적인 에러 메시지 (파일 위치 없음)
            if line.contains("error:") && !errors.contains(where: { line.contains($0.message) }) {
                if let range = line.range(of: "error:") {
                    let message = String(line[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                    if !message.isEmpty {
                        errors.append(BuildError(message: message, severity: .error))
                    }
                }
            }
        }

        return errors
    }

    /// Self-Healing을 위한 프롬프트 생성
    func generateHealingPrompt(from buildAttempt: BuildAttempt, projectInfo: ProjectInfo?) -> String {
        var prompt = """
        빌드 에러가 발생했습니다. 다음 에러를 분석하고 수정해주세요.

        ## 빌드 에러 목록

        """

        for (index, error) in buildAttempt.errors.enumerated() {
            prompt += "\(index + 1). "
            if !error.location.isEmpty {
                prompt += "[\(error.location)] "
            }
            prompt += "\(error.severity.rawValue.uppercased()): \(error.message)\n"
        }

        if let projectInfo = projectInfo {
            prompt += """

            ## 프로젝트 정보
            - 언어: \(projectInfo.language)
            - 프레임워크: \(projectInfo.framework)
            - 빌드 도구: \(projectInfo.buildTool)
            """
        }

        prompt += """

        ## 수정 요청
        위 에러들을 분석하고 해결 방법을 적용해주세요.
        각 에러에 대해:
        1. 원인 분석
        2. 필요한 파일 수정
        3. 수정 사항 적용

        수정 후 빌드가 성공할 수 있도록 해주세요.
        """

        return prompt
    }

    /// 스킴 목록 가져오기
    func listSchemes(projectPath: String) async -> [String] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
        process.arguments = ["-list", "-project", projectPath, "-json"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let project = json["project"] as? [String: Any],
               let schemes = project["schemes"] as? [String] {
                return schemes
            }
        } catch {
            print("[BuildService] Failed to list schemes: \(error)")
        }

        return []
    }
}
