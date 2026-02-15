import Foundation
import SwiftUI

/// 파이프라인 컨텍스트 파일 관리 서비스
/// PIPELINE_CONTEXT.md 읽기/쓰기를 담당
class PipelineContextService {
    static let shared = PipelineContextService()

    private init() {}

    // MARK: - Read

    /// 프로젝트의 PIPELINE_CONTEXT.md 경로
    func contextPath(for projectName: String) -> String {
        let basePath = DataPathService.shared.basePath
        let sanitizedName = DataPathService.shared.sanitizeName(projectName)
        return "\(basePath)/\(sanitizedName)/PIPELINE_CONTEXT.md"
    }

    /// 프로젝트 소스 경로 읽기
    func getProjectPath(for projectName: String) -> String? {
        let path = contextPath(for: projectName)

        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return nil
        }

        return extractProjectPath(from: content)
    }

    /// 프로젝트 소스 경로 추출 (코드 블록에서)
    private func extractProjectPath(from content: String) -> String? {
        let lines = content.components(separatedBy: "\n")
        var inSourcePathSection = false
        var inCodeBlock = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // 섹션 시작
            if trimmed.contains("프로젝트 소스 경로") || trimmed.contains("프로젝트 경로") {
                inSourcePathSection = true
                continue
            }

            // 다른 섹션으로 이동
            if inSourcePathSection && trimmed.hasPrefix("###") {
                inSourcePathSection = false
                continue
            }

            // 코드 블록 시작/끝
            if trimmed.hasPrefix("```") {
                inCodeBlock = !inCodeBlock
                continue
            }

            // 코드 블록 내 경로 추출
            if inSourcePathSection && inCodeBlock && !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                return trimmed
            }
        }

        return nil
    }

    // MARK: - Write

    /// 프로젝트 소스 경로 저장
    /// - Parameters:
    ///   - projectName: 프로젝트 이름
    ///   - sourcePath: 소스 경로 (상대경로 또는 절대경로)
    /// - Returns: 성공 여부
    @discardableResult
    func setProjectPath(for projectName: String, sourcePath: String) -> Bool {
        let path = contextPath(for: projectName)

        // 기존 파일이 있으면 업데이트, 없으면 새로 생성
        if let existingContent = try? String(contentsOfFile: path, encoding: .utf8) {
            let updatedContent = updatePathInContent(existingContent, newPath: sourcePath)
            return (try? updatedContent.write(toFile: path, atomically: true, encoding: .utf8)) != nil
        } else {
            // 새로 생성
            let content = generateContextFile(projectName: projectName, sourcePath: sourcePath)
            return (try? content.write(toFile: path, atomically: true, encoding: .utf8)) != nil
        }
    }

    /// 기존 컨텐츠에서 경로 업데이트
    private func updatePathInContent(_ content: String, newPath: String) -> String {
        var lines = content.components(separatedBy: "\n")
        var inSourcePathSection = false
        var codeBlockStart = -1
        var codeBlockEnd = -1
        var pathLineIndex = -1

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // 섹션 시작
            if trimmed.contains("프로젝트 소스 경로") || trimmed.contains("프로젝트 경로") {
                inSourcePathSection = true
                continue
            }

            // 다른 섹션으로 이동
            if inSourcePathSection && trimmed.hasPrefix("###") {
                inSourcePathSection = false
                continue
            }

            // 코드 블록 시작
            if inSourcePathSection && trimmed.hasPrefix("```") && codeBlockStart == -1 {
                codeBlockStart = index
                continue
            }

            // 코드 블록 끝
            if inSourcePathSection && codeBlockStart != -1 && trimmed.hasPrefix("```") && codeBlockEnd == -1 {
                codeBlockEnd = index
                break
            }

            // 경로 라인
            if inSourcePathSection && codeBlockStart != -1 && codeBlockEnd == -1 && !trimmed.isEmpty {
                pathLineIndex = index
            }
        }

        // 경로 라인 업데이트
        if pathLineIndex != -1 {
            lines[pathLineIndex] = newPath
        } else if codeBlockStart != -1 && codeBlockEnd != -1 {
            // 코드 블록 안에 경로가 없으면 추가
            lines.insert(newPath, at: codeBlockStart + 1)
        }

        return lines.joined(separator: "\n")
    }

    /// 새 PIPELINE_CONTEXT.md 생성 (프로젝트 스캔 결과 활용)
    private func generateContextFile(projectName: String, sourcePath: String) -> String {
        let isRelative = !sourcePath.hasPrefix("/")
        let pathNote = isRelative ?
            "상대경로 사용 중 (여러 컴퓨터에서 작업 가능)" :
            "절대경로 사용 중"

        return """
        # \(projectName) - 파이프라인 컨텍스트

        > **파이프라인 실행 전 필수 설정 정보**
        > \(pathNote)

        ---

        ## 🔴 필수 정보

        ### 프로젝트 소스 경로

        ```
        \(sourcePath)
        ```

        ### 빌드 명령

        ```bash
        xcodebuild -project [프로젝트명].xcodeproj -scheme [스킴명] -configuration Debug build
        ```

        ---

        ## 📋 기술 스택

        - **언어**: Swift
        - **프레임워크**: SwiftUI
        - **최소 지원 버전**: macOS 14.0 / iOS 17.0

        ---

        ## 📁 프로젝트 구조

        > 프로젝트 구조를 작성하세요.

        ---

        ## 🎯 코딩 컨벤션

        - **타입**: PascalCase
        - **변수/함수**: camelCase
        - **아키텍처**: MVVM

        ---

        *이 파일은 PixelOffice에서 자동 생성되었습니다.*
        *마지막 업데이트: \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))*
        """
    }
    
    /// 프로젝트 스캔 결과로 향상된 PIPELINE_CONTEXT.md 생성
    func generateEnhancedContextFile(projectName: String, sourcePath: String) async -> String {
        // 프로젝트 스캔 시도
        if let scanResult = await ProjectScanner.shared.scan(projectPath: sourcePath) {
            return ProjectScanner.shared.generatePipelineContext(from: scanResult, projectName: projectName)
        }
        
        // 스캔 실패 시 기본 템플릿 반환
        return generateContextFile(projectName: projectName, sourcePath: sourcePath)
    }
    
    /// 프로젝트 스캔 결과로 PROJECT.md 생성
    func generateEnhancedProjectMd(projectName: String, sourcePath: String) async -> String {
        if let scanResult = await ProjectScanner.shared.scan(projectPath: sourcePath) {
            return ProjectScanner.shared.generateProjectMd(from: scanResult, projectName: projectName)
        }
        
        // 스캔 실패 시 기본 템플릿
        return """
        # \(projectName)
        
        ## 프로젝트 경로
        
        - **절대경로**: `\(sourcePath)`
        
        ## 기술 스택
        
        - **언어**: Swift
        - **프레임워크**: SwiftUI
        - **빌드 도구**: Xcode
        
        ## 제품 정보
        
        ### 비전/목표
        
        > 🔴 **필수 입력** - 프로젝트의 비전과 목표를 작성하세요.
        
        ### 타겟 사용자
        
        > 🔴 **필수 입력** - 타겟 사용자를 정의하세요.
        
        ### 핵심 기능
        
        > 🔴 **필수 입력** - 핵심 기능을 나열하세요.
        
        ---
        
        *이 파일은 PixelOffice에서 자동 생성되었습니다.*
        """
    }

    // MARK: - Validation

    /// 프로젝트 경로가 유효한지 확인
    func validateProjectPath(for projectName: String) -> ProjectPathValidation {
        guard let sourcePath = getProjectPath(for: projectName) else {
            return .notSet
        }

        // 경로가 비어있는지 확인
        if sourcePath.isEmpty {
            return .notSet
        }

        // 절대경로로 변환
        var absolutePath = sourcePath
        if !sourcePath.hasPrefix("/") {
            let basePath = DataPathService.shared.basePath
            let sanitizedName = DataPathService.shared.sanitizeName(projectName)
            let contextDir = "\(basePath)/\(sanitizedName)"
            absolutePath = (contextDir as NSString).appendingPathComponent(sourcePath)
            absolutePath = (absolutePath as NSString).standardizingPath
        }

        // 경로 존재 확인
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false

        if !fileManager.fileExists(atPath: absolutePath, isDirectory: &isDirectory) {
            return .pathNotFound(absolutePath)
        }

        if !isDirectory.boolValue {
            return .notDirectory(absolutePath)
        }

        // Xcode 프로젝트 확인
        if let contents = try? fileManager.contentsOfDirectory(atPath: absolutePath) {
            let hasXcodeProject = contents.contains(where: { $0.hasSuffix(".xcodeproj") || $0.hasSuffix(".xcworkspace") })
            let hasPackageSwift = contents.contains("Package.swift")
            let hasTuist = contents.contains("Project.swift")

            if hasXcodeProject || hasPackageSwift || hasTuist {
                return .valid(absolutePath: absolutePath)
            } else {
                return .noXcodeProject(absolutePath)
            }
        }

        return .cannotReadDirectory(absolutePath)
    }

    /// 경로 검증을 절대경로로 변환
    func resolveAbsolutePath(for projectName: String) -> String? {
        guard let sourcePath = getProjectPath(for: projectName) else {
            return nil
        }

        if sourcePath.hasPrefix("/") {
            return sourcePath
        }

        let basePath = DataPathService.shared.basePath
        let sanitizedName = DataPathService.shared.sanitizeName(projectName)
        let contextDir = "\(basePath)/\(sanitizedName)"
        let absolutePath = (contextDir as NSString).appendingPathComponent(sourcePath)
        return (absolutePath as NSString).standardizingPath
    }
}

// MARK: - Validation Result

enum ProjectPathValidation: Equatable {
    case valid(absolutePath: String)
    case notSet
    case pathNotFound(String)
    case notDirectory(String)
    case noXcodeProject(String)
    case cannotReadDirectory(String)

    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }

    var message: String {
        switch self {
        case .valid(let path):
            return "✓ 유효한 프로젝트 경로: \(path)"
        case .notSet:
            return "프로젝트 경로가 설정되지 않았습니다. PIPELINE_CONTEXT.md를 확인하세요."
        case .pathNotFound(let path):
            return "경로가 존재하지 않습니다: \(path)"
        case .notDirectory(let path):
            return "폴더가 아닙니다: \(path)"
        case .noXcodeProject(let path):
            return "Xcode 프로젝트(.xcodeproj/.xcworkspace)를 찾을 수 없습니다: \(path)"
        case .cannotReadDirectory(let path):
            return "폴더를 읽을 수 없습니다: \(path)"
        }
    }

    var icon: String {
        switch self {
        case .valid: return "checkmark.circle.fill"
        case .notSet: return "questionmark.circle.fill"
        default: return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .valid: return .green
        case .notSet: return .orange
        default: return .red
        }
    }
}
