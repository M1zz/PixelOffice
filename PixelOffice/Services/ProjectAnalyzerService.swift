import Foundation

/// 프로젝트 폴더를 분석하여 정보를 추출하는 서비스
class ProjectAnalyzerService {
    static let shared = ProjectAnalyzerService()
    
    struct AnalysisResult {
        var name: String
        var description: String
        var tags: [String]
        var projectContext: String
        var techStack: [String]
    }
    
    /// 프로젝트 폴더 분석 (CLI 사용)
    func analyzeProject(at path: String) async throws -> AnalysisResult {
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: path) else {
            throw AnalysisError.pathNotFound
        }
        
        // 1. 프로젝트 구조 수집
        let projectInfo = collectProjectInfo(at: path)
        
        // 2. CLI로 분석 요청
        let result = try await analyzeWithCLI(projectInfo: projectInfo)
        
        return result
    }
    
    /// 프로젝트 정보 수집
    private func collectProjectInfo(at path: String) -> ProjectInfo {
        let fileManager = FileManager.default
        var info = ProjectInfo()
        
        // 프로젝트 이름 추출 (폴더명)
        info.folderName = (path as NSString).lastPathComponent
        
        // README 파일 찾기
        let readmeNames = ["README.md", "README.txt", "README", "readme.md"]
        for readmeName in readmeNames {
            let readmePath = (path as NSString).appendingPathComponent(readmeName)
            if let content = try? String(contentsOfFile: readmePath, encoding: .utf8) {
                info.readme = String(content.prefix(3000)) // 최대 3000자
                break
            }
        }
        
        // 프로젝트 파일 확인
        if let contents = try? fileManager.contentsOfDirectory(atPath: path) {
            for item in contents {
                let itemPath = (path as NSString).appendingPathComponent(item)
                
                if item.hasSuffix(".xcodeproj") {
                    info.projectType = .xcode
                    info.projectFileName = item
                } else if item == "Package.swift" {
                    info.projectType = .swiftPackage
                    if let content = try? String(contentsOfFile: itemPath, encoding: .utf8) {
                        info.packageSwift = String(content.prefix(2000))
                    }
                } else if item == "Project.swift" {
                    info.projectType = .tuist
                } else if item == "package.json" {
                    info.projectType = .node
                    if let content = try? String(contentsOfFile: itemPath, encoding: .utf8) {
                        info.packageJson = String(content.prefix(2000))
                    }
                } else if item == "Cargo.toml" {
                    info.projectType = .rust
                } else if item == "go.mod" {
                    info.projectType = .go
                } else if item == "pubspec.yaml" {
                    info.projectType = .flutter
                }
            }
        }
        
        // 주요 소스 파일 샘플 수집
        info.sourceFileSamples = collectSourceSamples(at: path)
        
        // 디렉토리 구조 수집
        info.directoryStructure = collectDirectoryStructure(at: path, depth: 3)
        
        return info
    }
    
    /// 소스 파일 샘플 수집
    private func collectSourceSamples(at path: String, maxFiles: Int = 5, maxCharsPerFile: Int = 1500) -> [String: String] {
        var samples: [String: String] = [:]
        let fileManager = FileManager.default
        
        // 주요 파일 패턴
        let importantPatterns = [
            "App.swift", "AppDelegate.swift", "ContentView.swift",
            "Main.swift", "index.ts", "index.js", "main.py", "main.go",
            "lib.rs", "main.dart"
        ]
        
        func findFiles(in dir: String, depth: Int = 0) {
            guard depth < 4, samples.count < maxFiles else { return }
            
            guard let contents = try? fileManager.contentsOfDirectory(atPath: dir) else { return }
            
            for item in contents {
                guard samples.count < maxFiles else { return }
                
                // 숨김 파일, node_modules, build 폴더 등 제외
                if item.hasPrefix(".") || ["node_modules", "build", "DerivedData", "Pods", ".build"].contains(item) {
                    continue
                }
                
                let itemPath = (dir as NSString).appendingPathComponent(item)
                var isDirectory: ObjCBool = false
                
                if fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory) {
                    if isDirectory.boolValue {
                        findFiles(in: itemPath, depth: depth + 1)
                    } else if importantPatterns.contains(item) || 
                              (item.hasSuffix(".swift") && samples.count < maxFiles) {
                        if let content = try? String(contentsOfFile: itemPath, encoding: .utf8) {
                            let relativePath = String(itemPath.dropFirst(path.count + 1))
                            samples[relativePath] = String(content.prefix(maxCharsPerFile))
                        }
                    }
                }
            }
        }
        
        findFiles(in: path)
        return samples
    }
    
    /// 디렉토리 구조 수집
    private func collectDirectoryStructure(at path: String, depth: Int) -> String {
        var result = ""
        let fileManager = FileManager.default
        
        func traverse(dir: String, currentDepth: Int, prefix: String) {
            guard currentDepth < depth else { return }
            
            guard let contents = try? fileManager.contentsOfDirectory(atPath: dir).sorted() else { return }
            
            for (index, item) in contents.enumerated() {
                // 숨김 파일, 빌드 폴더 등 제외
                if item.hasPrefix(".") || ["node_modules", "build", "DerivedData", "Pods", ".build", "__pycache__"].contains(item) {
                    continue
                }
                
                let isLast = index == contents.count - 1
                let itemPath = (dir as NSString).appendingPathComponent(item)
                var isDirectory: ObjCBool = false
                
                if fileManager.fileExists(atPath: itemPath, isDirectory: &isDirectory) {
                    let connector = isLast ? "└── " : "├── "
                    let icon = isDirectory.boolValue ? "📁" : "📄"
                    result += "\(prefix)\(connector)\(icon) \(item)\n"
                    
                    if isDirectory.boolValue {
                        let newPrefix = prefix + (isLast ? "    " : "│   ")
                        traverse(dir: itemPath, currentDepth: currentDepth + 1, prefix: newPrefix)
                    }
                }
            }
        }
        
        result = "📁 \((path as NSString).lastPathComponent)\n"
        traverse(dir: path, currentDepth: 0, prefix: "")
        
        return String(result.prefix(2000))
    }
    
    /// CLI로 프로젝트 분석 (Claude Code 사용)
    func analyzeWithCLI(projectInfo: ProjectInfo) async throws -> AnalysisResult {
        let prompt = buildAnalysisPrompt(projectInfo: projectInfo)
        
        // Claude CLI 경로 찾기
        let claudePath = findClaudeCLI()
        guard let claudePath = claudePath else {
            throw AnalysisError.cliNotFound
        }
        
        // Claude CLI 실행
        let process = Process()
        process.executableURL = URL(fileURLWithPath: claudePath)
        process.arguments = ["-p", prompt]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        
        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw AnalysisError.cliError(errorOutput)
        }
        
        return parseAnalysisResponse(output, folderName: projectInfo.folderName)
    }
    
    /// 분석 프롬프트 생성
    private func buildAnalysisPrompt(projectInfo: ProjectInfo) -> String {
        var prompt = """
        다음 프로젝트 정보를 분석하여 JSON 형식으로 응답해주세요.
        
        ## 프로젝트 폴더명
        \(projectInfo.folderName)
        
        ## 프로젝트 타입
        \(projectInfo.projectType?.rawValue ?? "unknown")
        
        """
        
        if let readme = projectInfo.readme {
            prompt += """
            
            ## README
            \(readme)
            
            """
        }
        
        prompt += """
        
        ## 디렉토리 구조
        \(projectInfo.directoryStructure)
        
        """
        
        if !projectInfo.sourceFileSamples.isEmpty {
            prompt += "\n## 주요 소스 파일\n"
            for (fileName, content) in projectInfo.sourceFileSamples {
                prompt += """
                
                ### \(fileName)
                ```
                \(content)
                ```
                
                """
            }
        }
        
        if let packageSwift = projectInfo.packageSwift {
            prompt += """
            
            ## Package.swift
            ```swift
            \(packageSwift)
            ```
            
            """
        }
        
        if let packageJson = projectInfo.packageJson {
            prompt += """
            
            ## package.json
            ```json
            \(packageJson)
            ```
            
            """
        }
        
        prompt += """
        
        ---
        
        위 정보를 바탕으로 다음 JSON 형식으로 프로젝트 정보를 추출해주세요:
        
        ```json
        {
            "name": "프로젝트 이름 (한글 가능)",
            "description": "프로젝트에 대한 간단한 설명 (1-2문장, 한글)",
            "tags": ["태그1", "태그2", "태그3"],
            "techStack": ["SwiftUI", "iOS", "등 사용 기술"],
            "projectContext": "프로젝트의 목적, 주요 기능, 아키텍처 등 상세 설명 (한글, 3-5문장)"
        }
        ```
        
        JSON만 응답해주세요. 다른 텍스트 없이 JSON 블록만 출력하세요.
        """
        
        return prompt
    }
    
    /// AI 응답 파싱
    private func parseAnalysisResponse(_ response: String, folderName: String) -> AnalysisResult {
        // JSON 블록 추출
        var jsonString = response
        
        if let startRange = response.range(of: "```json") {
            jsonString = String(response[startRange.upperBound...])
            if let endRange = jsonString.range(of: "```") {
                jsonString = String(jsonString[..<endRange.lowerBound])
            }
        } else if let startRange = response.range(of: "{"),
                  let endRange = response.range(of: "}", options: .backwards) {
            jsonString = String(response[startRange.lowerBound...endRange.upperBound])
        }
        
        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // JSON 파싱
        if let data = jsonString.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return AnalysisResult(
                name: json["name"] as? String ?? folderName,
                description: json["description"] as? String ?? "",
                tags: json["tags"] as? [String] ?? [],
                projectContext: json["projectContext"] as? String ?? "",
                techStack: json["techStack"] as? [String] ?? []
            )
        }
        
        // 파싱 실패 시 기본값
        return AnalysisResult(
            name: folderName,
            description: "",
            tags: [],
            projectContext: "",
            techStack: []
        )
    }
    
    // MARK: - Helper Types
    
    struct ProjectInfo {
        var folderName: String = ""
        var projectType: ProjectType?
        var projectFileName: String?
        var readme: String?
        var packageSwift: String?
        var packageJson: String?
        var sourceFileSamples: [String: String] = [:]
        var directoryStructure: String = ""
    }
    
    enum ProjectType: String {
        case xcode = "Xcode"
        case swiftPackage = "Swift Package"
        case tuist = "Tuist"
        case node = "Node.js"
        case rust = "Rust"
        case go = "Go"
        case flutter = "Flutter"
    }
    
    enum AnalysisError: LocalizedError {
        case pathNotFound
        case cliNotFound
        case cliError(String)
        case analysisFailed
        
        var errorDescription: String? {
            switch self {
            case .pathNotFound: return "프로젝트 경로를 찾을 수 없습니다"
            case .cliNotFound: return "Claude CLI를 찾을 수 없습니다. 'claude' 명령어가 설치되어 있는지 확인하세요."
            case .cliError(let message): return "CLI 오류: \(message)"
            case .analysisFailed: return "프로젝트 분석에 실패했습니다"
            }
        }
    }
    
    /// Claude CLI 경로 찾기
    private func findClaudeCLI() -> String? {
        let possiblePaths = [
            // 사용자 로컬 설치
            NSHomeDirectory() + "/.local/bin/claude",
            // Homebrew (Apple Silicon)
            "/opt/homebrew/bin/claude",
            // Homebrew (Intel)
            "/usr/local/bin/claude",
            // npm global
            "/usr/local/lib/node_modules/@anthropic-ai/claude-code/bin/claude",
            NSHomeDirectory() + "/.npm-global/bin/claude",
            // 시스템
            "/usr/bin/claude"
        ]
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        // which 명령으로 찾기 시도
        let whichProcess = Process()
        whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        whichProcess.arguments = ["claude"]
        
        let pipe = Pipe()
        whichProcess.standardOutput = pipe
        whichProcess.standardError = FileHandle.nullDevice
        
        // PATH 환경변수에 일반적인 경로 추가
        var env = ProcessInfo.processInfo.environment
        let additionalPaths = [
            NSHomeDirectory() + "/.local/bin",
            "/opt/homebrew/bin",
            "/usr/local/bin"
        ]
        if let existingPath = env["PATH"] {
            env["PATH"] = additionalPaths.joined(separator: ":") + ":" + existingPath
        } else {
            env["PATH"] = additionalPaths.joined(separator: ":")
        }
        whichProcess.environment = env
        
        do {
            try whichProcess.run()
            whichProcess.waitUntilExit()
            
            if whichProcess.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    return path
                }
            }
        } catch {
            print("which claude 실행 실패: \(error)")
        }
        
        return nil
    }
}
