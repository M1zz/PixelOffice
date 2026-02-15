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

    // MARK: - Simulator Launch

    /// 프로젝트 플랫폼 감지
    func detectPlatform(projectPath: String) async -> AppLaunchResult.AppPlatform {
        // xcodeproj 또는 xcworkspace에서 플랫폼 정보 추출
        let fileManager = FileManager.default

        // Package.swift가 있으면 macOS로 추정
        let packagePath = (projectPath as NSString).appendingPathComponent("Package.swift")
        if fileManager.fileExists(atPath: packagePath) {
            // Package.swift 내용 확인
            if let content = try? String(contentsOfFile: packagePath, encoding: .utf8) {
                if content.contains(".iOS") { return .iOS }
                if content.contains(".watchOS") { return .watchOS }
                if content.contains(".tvOS") { return .tvOS }
            }
            return .macOS
        }

        // xcodeproj 내 project.pbxproj 분석
        if let contents = try? fileManager.contentsOfDirectory(atPath: projectPath) {
            for item in contents {
                if item.hasSuffix(".xcodeproj") {
                    let pbxprojPath = (projectPath as NSString)
                        .appendingPathComponent(item)
                        .appending("/project.pbxproj")

                    if let content = try? String(contentsOfFile: pbxprojPath, encoding: .utf8) {
                        if content.contains("SDKROOT = iphoneos") { return .iOS }
                        if content.contains("SDKROOT = watchos") { return .watchOS }
                        if content.contains("SDKROOT = appletvos") { return .tvOS }
                        if content.contains("SDKROOT = macosx") { return .macOS }
                    }
                }
            }
        }

        return .macOS  // 기본값
    }

    /// 사용 가능한 시뮬레이터 목록 가져오기
    func listSimulators() async -> [SimulatorInfo] {
        var simulators: [SimulatorInfo] = []

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "list", "devices", "-j"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let devices = json["devices"] as? [String: [[String: Any]]] {
                for (runtime, deviceList) in devices {
                    for device in deviceList {
                        if let udid = device["udid"] as? String,
                           let name = device["name"] as? String,
                           let state = device["state"] as? String,
                           let isAvailable = device["isAvailable"] as? Bool,
                           isAvailable {
                            simulators.append(SimulatorInfo(
                                udid: udid,
                                name: name,
                                state: state,
                                runtime: runtime
                            ))
                        }
                    }
                }
            }
        } catch {
            print("[BuildService] Failed to list simulators: \(error)")
        }

        return simulators
    }

    /// 시뮬레이터 부팅
    func bootSimulator(udid: String) async -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "boot", udid]

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            print("[BuildService] Failed to boot simulator: \(error)")
            return false
        }
    }

    /// 앱 설치
    func installApp(simulatorId: String, appPath: String) async -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "install", simulatorId, appPath]

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            print("[BuildService] Failed to install app: \(error)")
            return false
        }
    }

    /// 앱 실행
    func launchApp(simulatorId: String, bundleId: String) async -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "launch", simulatorId, bundleId]

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            print("[BuildService] Failed to launch app: \(error)")
            return false
        }
    }

    /// 빌드 후 자동 실행 (통합)
    func buildAndLaunch(
        projectPath: String,
        scheme: String? = nil
    ) async throws -> AppLaunchResult {
        var logs: [String] = []

        // 1. 플랫폼 감지
        let platform = await detectPlatform(projectPath: projectPath)
        logs.append("📱 플랫폼 감지: \(platform.rawValue)")

        // 2. macOS인 경우 바로 빌드 후 실행
        if platform == .macOS {
            logs.append("🖥️ macOS 앱 빌드 중...")
            let buildAttempt = try await build(projectPath: projectPath, scheme: scheme)

            if buildAttempt.success {
                logs.append("✅ 빌드 성공")

                // DerivedData에서 앱 찾기 및 실행
                if let appPath = findBuiltApp(projectPath: projectPath, scheme: scheme) {
                    logs.append("🚀 앱 실행 중: \(appPath)")
                    let launchSuccess = await launchMacApp(appPath: appPath)
                    logs.append(launchSuccess ? "✅ 앱 실행 성공" : "❌ 앱 실행 실패")

                    return AppLaunchResult(
                        success: launchSuccess,
                        platform: .macOS,
                        appBundleId: extractBundleId(from: appPath),
                        logs: logs
                    )
                }
            }

            return AppLaunchResult(
                success: false,
                platform: .macOS,
                logs: logs + ["❌ 빌드 실패"]
            )
        }

        // 3. iOS/watchOS/tvOS인 경우 시뮬레이터 사용
        logs.append("📱 \(platform.rawValue) 시뮬레이터 준비 중...")

        // 적합한 시뮬레이터 찾기
        let simulators = await listSimulators()
        let targetRuntime: String
        switch platform {
        case .iOS: targetRuntime = "iOS"
        case .watchOS: targetRuntime = "watchOS"
        case .tvOS: targetRuntime = "tvOS"
        default: targetRuntime = "iOS"
        }

        guard let simulator = simulators.first(where: { $0.runtime.contains(targetRuntime) }) else {
            logs.append("❌ \(targetRuntime) 시뮬레이터를 찾을 수 없습니다")
            return AppLaunchResult(success: false, platform: platform, logs: logs)
        }

        logs.append("📱 시뮬레이터 선택: \(simulator.name) (\(simulator.udid))")

        // 시뮬레이터 부팅
        if simulator.state != "Booted" {
            logs.append("🔄 시뮬레이터 부팅 중...")
            let bootSuccess = await bootSimulator(udid: simulator.udid)
            if !bootSuccess {
                logs.append("❌ 시뮬레이터 부팅 실패")
                return AppLaunchResult(success: false, platform: platform, simulatorId: simulator.udid, simulatorName: simulator.name, logs: logs)
            }
            logs.append("✅ 시뮬레이터 부팅 완료")
        }

        // 빌드 (시뮬레이터 타겟)
        logs.append("🔨 빌드 중...")
        let config = BuildConfiguration(
            projectPath: projectPath,
            scheme: scheme,
            destination: "platform=\(targetRuntime) Simulator,id=\(simulator.udid)"
        )
        let buildAttempt = try await build(config: config)

        if !buildAttempt.success {
            logs.append("❌ 빌드 실패: \(buildAttempt.errors.count)개 에러")
            return AppLaunchResult(success: false, platform: platform, simulatorId: simulator.udid, simulatorName: simulator.name, logs: logs)
        }

        logs.append("✅ 빌드 성공")

        // 앱 설치 및 실행
        if let appPath = findBuiltApp(projectPath: projectPath, scheme: scheme) {
            logs.append("📲 앱 설치 중...")
            let installSuccess = await installApp(simulatorId: simulator.udid, appPath: appPath)
            if !installSuccess {
                logs.append("❌ 앱 설치 실패")
                return AppLaunchResult(success: false, platform: platform, simulatorId: simulator.udid, simulatorName: simulator.name, logs: logs)
            }

            let bundleId = extractBundleId(from: appPath) ?? ""
            logs.append("🚀 앱 실행 중 (Bundle ID: \(bundleId))...")
            let launchSuccess = await launchApp(simulatorId: simulator.udid, bundleId: bundleId)

            return AppLaunchResult(
                success: launchSuccess,
                platform: platform,
                simulatorId: simulator.udid,
                simulatorName: simulator.name,
                appBundleId: bundleId,
                logs: logs + [launchSuccess ? "✅ 앱 실행 성공" : "❌ 앱 실행 실패"]
            )
        }

        logs.append("❌ 빌드된 앱을 찾을 수 없습니다")
        return AppLaunchResult(success: false, platform: platform, simulatorId: simulator.udid, simulatorName: simulator.name, logs: logs)
    }

    /// 빌드된 앱 경로 찾기
    private func findBuiltApp(projectPath: String, scheme: String?) -> String? {
        let derivedDataPath = NSHomeDirectory() + "/Library/Developer/Xcode/DerivedData"
        let fileManager = FileManager.default

        guard let contents = try? fileManager.contentsOfDirectory(atPath: derivedDataPath) else {
            return nil
        }

        // 프로젝트 이름과 일치하는 DerivedData 폴더 찾기
        let projectName = (projectPath as NSString).lastPathComponent
            .replacingOccurrences(of: ".xcodeproj", with: "")
            .replacingOccurrences(of: ".xcworkspace", with: "")

        for folder in contents {
            if folder.hasPrefix(projectName) {
                let buildPath = "\(derivedDataPath)/\(folder)/Build/Products/Debug"
                // macOS 앱
                let macAppPath = "\(buildPath)/\(scheme ?? projectName).app"
                if fileManager.fileExists(atPath: macAppPath) {
                    return macAppPath
                }
                // iOS 앱
                let iosAppPath = "\(buildPath)-iphonesimulator/\(scheme ?? projectName).app"
                if fileManager.fileExists(atPath: iosAppPath) {
                    return iosAppPath
                }
            }
        }

        return nil
    }

    /// Bundle ID 추출
    private func extractBundleId(from appPath: String) -> String? {
        let plistPath = (appPath as NSString).appendingPathComponent("Contents/Info.plist")
        let iosPlistPath = (appPath as NSString).appendingPathComponent("Info.plist")

        let pathToUse = FileManager.default.fileExists(atPath: plistPath) ? plistPath : iosPlistPath

        guard let plistData = try? Data(contentsOf: URL(fileURLWithPath: pathToUse)),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
              let bundleId = plist["CFBundleIdentifier"] as? String else {
            return nil
        }

        return bundleId
    }

    /// macOS 앱 실행
    private func launchMacApp(appPath: String) async -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [appPath]

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            print("[BuildService] Failed to launch macOS app: \(error)")
            return false
        }
    }
}

// MARK: - Simulator Info

struct SimulatorInfo {
    let udid: String
    let name: String
    let state: String
    let runtime: String

    var isBooted: Bool {
        state == "Booted"
    }
}
