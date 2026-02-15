import Foundation

/// 프로젝트 자동 스캔 서비스
/// Xcode 프로젝트의 scheme, target, 구조를 자동으로 탐지
class ProjectScanner {
    static let shared = ProjectScanner()
    
    private init() {}
    
    // MARK: - Scan Result
    
    struct ScanResult {
        let projectPath: String
        let projectType: ProjectType
        let projectName: String
        let schemes: [String]
        let targets: [String]
        let buildCommand: String
        let language: String
        let framework: String
        let structure: ProjectStructure
        let mainFiles: [String]  // 주요 View/Model 파일
        
        enum ProjectType: String {
            case xcodeproj = "Xcode Project"
            case xcworkspace = "Xcode Workspace"
            case swiftPackage = "Swift Package"
            case tuist = "Tuist Project"
        }
        
        struct ProjectStructure {
            let directories: [String]
            let swiftFiles: [String]
            let viewFiles: [String]
            let modelFiles: [String]
            let serviceFiles: [String]
            let totalLines: Int
        }
    }
    
    // MARK: - Scan
    
    /// 프로젝트 경로에서 정보 자동 스캔
    func scan(projectPath: String) async -> ScanResult? {
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: projectPath) else {
            print("[ProjectScanner] 경로 없음: \(projectPath)")
            return nil
        }
        
        // 프로젝트 타입 감지
        let projectType = detectProjectType(at: projectPath)
        let projectName = detectProjectName(at: projectPath, type: projectType)
        
        // xcodebuild -list로 scheme/target 가져오기
        let (schemes, targets) = await fetchSchemesAndTargets(at: projectPath, type: projectType)
        
        // 빌드 명령 생성
        let buildCommand = generateBuildCommand(
            projectPath: projectPath,
            projectType: projectType,
            projectName: projectName,
            scheme: schemes.first
        )
        
        // 프로젝트 구조 분석
        let structure = analyzeStructure(at: projectPath)
        
        // 주요 파일 탐지
        let mainFiles = detectMainFiles(at: projectPath, structure: structure)
        
        // 언어/프레임워크 감지
        let (language, framework) = detectTechStack(structure: structure, projectPath: projectPath)
        
        return ScanResult(
            projectPath: projectPath,
            projectType: projectType,
            projectName: projectName,
            schemes: schemes,
            targets: targets,
            buildCommand: buildCommand,
            language: language,
            framework: framework,
            structure: structure,
            mainFiles: mainFiles
        )
    }
    
    // MARK: - Project Type Detection
    
    private func detectProjectType(at path: String) -> ScanResult.ProjectType {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else {
            return .xcodeproj
        }
        
        // 우선순위: workspace > tuist > xcodeproj > package
        if contents.contains(where: { $0.hasSuffix(".xcworkspace") }) {
            return .xcworkspace
        }
        if contents.contains("Project.swift") {
            return .tuist
        }
        if contents.contains(where: { $0.hasSuffix(".xcodeproj") }) {
            return .xcodeproj
        }
        if contents.contains("Package.swift") {
            return .swiftPackage
        }
        
        return .xcodeproj
    }
    
    private func detectProjectName(at path: String, type: ScanResult.ProjectType) -> String {
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else {
            return (path as NSString).lastPathComponent
        }
        
        switch type {
        case .xcworkspace:
            if let workspace = contents.first(where: { $0.hasSuffix(".xcworkspace") }) {
                return (workspace as NSString).deletingPathExtension
            }
        case .xcodeproj:
            if let project = contents.first(where: { $0.hasSuffix(".xcodeproj") }) {
                return (project as NSString).deletingPathExtension
            }
        case .tuist, .swiftPackage:
            return (path as NSString).lastPathComponent
        }
        
        return (path as NSString).lastPathComponent
    }
    
    // MARK: - Schemes & Targets
    
    private func fetchSchemesAndTargets(at path: String, type: ScanResult.ProjectType) async -> ([String], [String]) {
        var schemes: [String] = []
        var targets: [String] = []
        
        // xcodebuild -list 실행
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcodebuild")
        process.currentDirectoryURL = URL(fileURLWithPath: path)
        process.arguments = ["-list", "-json"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // workspace 또는 project 키 확인
                if let workspace = json["workspace"] as? [String: Any] {
                    schemes = workspace["schemes"] as? [String] ?? []
                } else if let project = json["project"] as? [String: Any] {
                    schemes = project["schemes"] as? [String] ?? []
                    targets = project["targets"] as? [String] ?? []
                }
            }
        } catch {
            print("[ProjectScanner] xcodebuild -list 실패: \(error)")
        }
        
        return (schemes, targets)
    }
    
    // MARK: - Build Command
    
    private func generateBuildCommand(
        projectPath: String,
        projectType: ScanResult.ProjectType,
        projectName: String,
        scheme: String?
    ) -> String {
        let schemePart = scheme ?? projectName
        
        switch projectType {
        case .xcworkspace:
            return "xcodebuild -workspace \(projectName).xcworkspace -scheme \(schemePart) -configuration Debug build"
        case .xcodeproj:
            return "xcodebuild -project \(projectName).xcodeproj -scheme \(schemePart) -configuration Debug build"
        case .tuist:
            return "tuist generate && xcodebuild -project \(projectName).xcodeproj -scheme \(schemePart) -configuration Debug build"
        case .swiftPackage:
            return "swift build"
        }
    }
    
    // MARK: - Structure Analysis
    
    private func analyzeStructure(at path: String) -> ScanResult.ProjectStructure {
        let fileManager = FileManager.default
        var directories: [String] = []
        var swiftFiles: [String] = []
        var viewFiles: [String] = []
        var modelFiles: [String] = []
        var serviceFiles: [String] = []
        var totalLines = 0
        
        // 재귀적으로 파일 탐색
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return ScanResult.ProjectStructure(
                directories: [], swiftFiles: [], viewFiles: [],
                modelFiles: [], serviceFiles: [], totalLines: 0
            )
        }
        
        let excludedDirs = ["DerivedData", "Derived", ".build", "Pods", "Carthage", ".git", "xcuserdata"]
        
        for case let url as URL in enumerator {
            let relativePath = url.path.replacingOccurrences(of: path + "/", with: "")
            
            // 제외 디렉토리 스킵
            if excludedDirs.contains(where: { relativePath.contains($0) }) {
                continue
            }
            
            if let values = try? url.resourceValues(forKeys: [.isDirectoryKey]),
               let isDirectory = values.isDirectory {
                
                if isDirectory {
                    // 주요 디렉토리만 추가
                    let dirName = url.lastPathComponent
                    if !excludedDirs.contains(dirName) && !dirName.hasSuffix(".xcodeproj") && !dirName.hasSuffix(".xcworkspace") {
                        directories.append(relativePath)
                    }
                } else if url.pathExtension == "swift" {
                    swiftFiles.append(relativePath)
                    
                    // 파일 분류
                    let fileName = url.lastPathComponent.lowercased()
                    if fileName.contains("view") || relativePath.lowercased().contains("/views/") {
                        viewFiles.append(relativePath)
                    } else if fileName.contains("model") || relativePath.lowercased().contains("/models/") {
                        modelFiles.append(relativePath)
                    } else if fileName.contains("service") || fileName.contains("store") || relativePath.lowercased().contains("/services/") {
                        serviceFiles.append(relativePath)
                    }
                    
                    // 라인 수 계산
                    if let content = try? String(contentsOf: url, encoding: .utf8) {
                        totalLines += content.components(separatedBy: "\n").count
                    }
                }
            }
        }
        
        return ScanResult.ProjectStructure(
            directories: directories.sorted(),
            swiftFiles: swiftFiles.sorted(),
            viewFiles: viewFiles.sorted(),
            modelFiles: modelFiles.sorted(),
            serviceFiles: serviceFiles.sorted(),
            totalLines: totalLines
        )
    }
    
    // MARK: - Main Files Detection
    
    private func detectMainFiles(at path: String, structure: ScanResult.ProjectStructure) -> [String] {
        var mainFiles: [String] = []
        
        // ContentView, AppDelegate, MainView 등 주요 파일 찾기
        let importantPatterns = [
            "ContentView.swift",
            "MainView.swift",
            "AppDelegate.swift",
            "SceneDelegate.swift",
            "App.swift"  // SwiftUI App
        ]
        
        for file in structure.swiftFiles {
            let fileName = (file as NSString).lastPathComponent
            if importantPatterns.contains(where: { fileName.contains($0.replacingOccurrences(of: ".swift", with: "")) }) {
                mainFiles.append(file)
            }
        }
        
        // View 파일 중 가장 큰 파일들 (주요 화면일 가능성)
        let viewFilesWithSize = structure.viewFiles.compactMap { file -> (String, Int)? in
            let fullPath = (path as NSString).appendingPathComponent(file)
            if let content = try? String(contentsOfFile: fullPath, encoding: .utf8) {
                return (file, content.components(separatedBy: "\n").count)
            }
            return nil
        }.sorted { $0.1 > $1.1 }
        
        // 상위 5개 View 파일
        for (file, _) in viewFilesWithSize.prefix(5) {
            if !mainFiles.contains(file) {
                mainFiles.append(file)
            }
        }
        
        return mainFiles
    }
    
    // MARK: - Tech Stack Detection
    
    private func detectTechStack(structure: ScanResult.ProjectStructure, projectPath: String) -> (String, String) {
        var language = "Swift"
        var framework = "SwiftUI"
        
        // 몇 개의 파일 샘플링해서 import 확인
        let sampleFiles = Array(structure.swiftFiles.prefix(10))
        var hasSwiftUI = false
        var hasUIKit = false
        var hasAppKit = false
        
        for file in sampleFiles {
            let fullPath = (projectPath as NSString).appendingPathComponent(file)
            if let content = try? String(contentsOfFile: fullPath, encoding: .utf8) {
                if content.contains("import SwiftUI") {
                    hasSwiftUI = true
                }
                if content.contains("import UIKit") {
                    hasUIKit = true
                }
                if content.contains("import AppKit") || content.contains("import Cocoa") {
                    hasAppKit = true
                }
            }
        }
        
        if hasSwiftUI {
            framework = "SwiftUI"
        } else if hasUIKit {
            framework = "UIKit"
        } else if hasAppKit {
            framework = "AppKit"
        }
        
        return (language, framework)
    }
    
    // MARK: - Generate Context
    
    /// 스캔 결과를 PIPELINE_CONTEXT.md 형식으로 변환
    func generatePipelineContext(from result: ScanResult, projectName: String) -> String {
        let structureSummary = """
        ### 주요 디렉토리
        \(result.structure.directories.prefix(10).map { "- `\($0)`" }.joined(separator: "\n"))
        
        ### 주요 파일 (\(result.structure.swiftFiles.count)개 Swift 파일, 총 \(result.structure.totalLines)줄)
        
        **엔트리 포인트**
        \(result.mainFiles.map { "- `\($0)`" }.joined(separator: "\n"))
        
        **View 파일** (\(result.structure.viewFiles.count)개)
        \(result.structure.viewFiles.prefix(5).map { "- `\($0)`" }.joined(separator: "\n"))
        
        **Model 파일** (\(result.structure.modelFiles.count)개)
        \(result.structure.modelFiles.prefix(5).map { "- `\($0)`" }.joined(separator: "\n"))
        
        **Service 파일** (\(result.structure.serviceFiles.count)개)
        \(result.structure.serviceFiles.prefix(5).map { "- `\($0)`" }.joined(separator: "\n"))
        """
        
        return """
        # \(projectName) - 파이프라인 컨텍스트
        
        > **⚡ 자동 생성됨** - ProjectScanner가 프로젝트를 분석하여 생성
        > 마지막 스캔: \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))
        
        ---
        
        ## 🔴 필수 정보
        
        ### 프로젝트 소스 경로
        
        > ⚠️ **절대경로를 사용하지 마세요!** 여러 컴퓨터에서 작업합니다.
        
        ```
        \(result.projectPath)
        ```
        
        ### 빌드 명령
        
        ```bash
        \(result.buildCommand)
        ```
        
        ---
        
        ## 📋 기술 스택
        
        | 항목 | 값 |
        |------|-----|
        | **프로젝트 타입** | \(result.projectType.rawValue) |
        | **언어** | \(result.language) |
        | **프레임워크** | \(result.framework) |
        | **스킴** | \(result.schemes.joined(separator: ", ").isEmpty ? "자동 탐지" : result.schemes.joined(separator: ", ")) |
        | **타겟** | \(result.targets.joined(separator: ", ").isEmpty ? "자동 탐지" : result.targets.joined(separator: ", ")) |
        
        ---
        
        ## 📁 프로젝트 구조
        
        \(structureSummary)
        
        ---
        
        ## 🎯 코딩 컨벤션
        
        - **타입**: PascalCase
        - **변수/함수**: camelCase
        - **아키텍처**: MVVM
        
        ---
        
        ## ⚠️ 주의사항
        
        - 프로젝트 루트 외부에 파일 생성 금지
        - 모든 데이터는 `datas/` 폴더에 저장
        
        ---
        
        *이 파일은 PixelOffice ProjectScanner가 자동 생성했습니다.*
        """
    }
    
    /// 스캔 결과를 PROJECT.md 형식으로 변환
    func generateProjectMd(from result: ScanResult, projectName: String) -> String {
        return """
        # \(projectName)
        
        > **⚡ 자동 생성됨** - ProjectScanner가 프로젝트를 분석하여 생성
        
        ## 프로젝트 경로
        
        - **절대경로**: `\(result.projectPath)`
        - **프로젝트 타입**: \(result.projectType.rawValue)
        
        > ⚠️ 파이프라인 실행 시 상대경로를 사용하세요.
        
        ## 기술 스택
        
        | 항목 | 값 |
        |------|-----|
        | **언어** | \(result.language) |
        | **프레임워크** | \(result.framework) |
        | **빌드 도구** | Xcode |
        | **스킴** | \(result.schemes.first ?? projectName) |
        
        ## 제품 정보
        
        ### 비전/목표
        
        > 🔴 **필수 입력** - 프로젝트의 비전과 목표를 작성하세요.
        > AI가 요구사항을 이해하는 데 중요합니다.
        
        ### 타겟 사용자
        
        > 🔴 **필수 입력** - 타겟 사용자를 정의하세요.
        
        ### 핵심 기능
        
        > 🔴 **필수 입력** - 핵심 기능을 나열하세요.
        
        ---
        
        ## 📁 코드 구조
        
        ### 주요 파일
        
        | 파일 | 역할 |
        |------|------|
        \(result.mainFiles.prefix(10).map { "| `\($0)` | - |" }.joined(separator: "\n"))
        
        ### 통계
        
        - **총 Swift 파일**: \(result.structure.swiftFiles.count)개
        - **총 코드 라인**: \(result.structure.totalLines)줄
        - **View 파일**: \(result.structure.viewFiles.count)개
        - **Model 파일**: \(result.structure.modelFiles.count)개
        - **Service 파일**: \(result.structure.serviceFiles.count)개
        
        ---
        
        *이 파일은 PixelOffice ProjectScanner가 자동 생성했습니다.*
        *생성일: \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))*
        """
    }
}
