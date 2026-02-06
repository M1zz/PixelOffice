import Foundation

/// 커스텀 필드 (사용자 정의)
struct CustomField: Codable, Equatable, Identifiable {
    var id: UUID
    var title: String       // 필드 제목 (예: "디자인 참고 링크")
    var content: String     // 필드 내용
    var createdAt: Date

    init(id: UUID = UUID(), title: String, content: String = "", createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
    }
}

/// 프로젝트 정보 (PROJECT.md로 저장되어 git 추적)
struct ProjectInfo: Codable, Equatable {
    // MARK: - 프로젝트 경로
    var relativePath: String  // 상대경로 (예: ../ClipKeyboard)
    var absolutePath: String  // 절대경로 (로컬 참조용)

    // MARK: - 기술 스택
    var language: String      // 주 언어 (예: Swift 5.9)
    var framework: String     // 프레임워크 (예: SwiftUI, AppKit)
    var buildTool: String     // 빌드 도구 (예: Tuist, SPM, CocoaPods)
    var dependencies: [String] // 주요 의존성

    // MARK: - 제품 정보
    var vision: String        // 제품 비전/목표
    var targetUsers: String   // 타겟 사용자
    var coreFeatures: [String] // 핵심 기능 목록

    // MARK: - 개발 가이드
    var branchStrategy: String  // 브랜치 전략 (예: main, feature/*, fix/*)
    var commitConvention: String // 커밋 규칙 (예: Conventional Commits)
    var codeStyle: String       // 코드 스타일 (예: SwiftLint 기본)

    // MARK: - 외부 연동
    var apiEndpoints: [String]  // API 엔드포인트
    var externalServices: [String] // 외부 서비스 (Firebase, AWS 등)

    // MARK: - 기타
    var notes: String           // 추가 메모

    // MARK: - 커스텀 필드
    var customFields: [CustomField]  // 사용자 정의 필드

    init(
        relativePath: String = "",
        absolutePath: String = "",
        language: String = "",
        framework: String = "",
        buildTool: String = "",
        dependencies: [String] = [],
        vision: String = "",
        targetUsers: String = "",
        coreFeatures: [String] = [],
        branchStrategy: String = "",
        commitConvention: String = "",
        codeStyle: String = "",
        apiEndpoints: [String] = [],
        externalServices: [String] = [],
        notes: String = "",
        customFields: [CustomField] = []
    ) {
        self.relativePath = relativePath
        self.absolutePath = absolutePath
        self.language = language
        self.framework = framework
        self.buildTool = buildTool
        self.dependencies = dependencies
        self.vision = vision
        self.targetUsers = targetUsers
        self.coreFeatures = coreFeatures
        self.branchStrategy = branchStrategy
        self.commitConvention = commitConvention
        self.codeStyle = codeStyle
        self.apiEndpoints = apiEndpoints
        self.externalServices = externalServices
        self.notes = notes
        self.customFields = customFields
    }

    // MARK: - Markdown 변환

    /// PROJECT.md 형식으로 변환
    func toMarkdown() -> String {
        var md = ""

        // 프로젝트 경로
        md += "## 프로젝트 경로\n\n"
        if !relativePath.isEmpty {
            md += "- **상대경로**: `\(relativePath)`\n"
        }
        if !absolutePath.isEmpty {
            md += "- **절대경로**: `\(absolutePath)`\n"
        }
        md += "\n"

        // 기술 스택
        md += "## 기술 스택\n\n"
        if !language.isEmpty {
            md += "- **언어**: \(language)\n"
        }
        if !framework.isEmpty {
            md += "- **프레임워크**: \(framework)\n"
        }
        if !buildTool.isEmpty {
            md += "- **빌드 도구**: \(buildTool)\n"
        }
        if !dependencies.isEmpty {
            md += "- **의존성**:\n"
            for dep in dependencies {
                md += "  - \(dep)\n"
            }
        }
        md += "\n"

        // 제품 정보
        md += "## 제품 정보\n\n"
        if !vision.isEmpty {
            md += "### 비전/목표\n\n\(vision)\n\n"
        }
        if !targetUsers.isEmpty {
            md += "### 타겟 사용자\n\n\(targetUsers)\n\n"
        }
        if !coreFeatures.isEmpty {
            md += "### 핵심 기능\n\n"
            for feature in coreFeatures {
                md += "- \(feature)\n"
            }
            md += "\n"
        }

        // 개발 가이드
        md += "## 개발 가이드\n\n"
        if !branchStrategy.isEmpty {
            md += "- **브랜치 전략**: \(branchStrategy)\n"
        }
        if !commitConvention.isEmpty {
            md += "- **커밋 규칙**: \(commitConvention)\n"
        }
        if !codeStyle.isEmpty {
            md += "- **코드 스타일**: \(codeStyle)\n"
        }
        md += "\n"

        // 외부 연동
        if !apiEndpoints.isEmpty || !externalServices.isEmpty {
            md += "## 외부 연동\n\n"
            if !apiEndpoints.isEmpty {
                md += "### API 엔드포인트\n\n"
                for endpoint in apiEndpoints {
                    md += "- \(endpoint)\n"
                }
                md += "\n"
            }
            if !externalServices.isEmpty {
                md += "### 외부 서비스\n\n"
                for service in externalServices {
                    md += "- \(service)\n"
                }
                md += "\n"
            }
        }

        // 기타 메모
        if !notes.isEmpty {
            md += "## 메모\n\n\(notes)\n\n"
        }

        // 커스텀 필드
        if !customFields.isEmpty {
            md += "## 추가 정보\n\n"
            for field in customFields {
                md += "### \(field.title)\n\n"
                if !field.content.isEmpty {
                    md += "\(field.content)\n\n"
                }
            }
        }

        return md
    }

    /// Markdown에서 파싱
    static func fromMarkdown(_ markdown: String) -> ProjectInfo {
        var info = ProjectInfo()

        let lines = markdown.components(separatedBy: "\n")
        var currentSection = ""
        var currentSubsection = ""
        var multilineBuffer = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // 섹션 헤더 감지
            if trimmed.hasPrefix("## ") {
                // 이전 멀티라인 버퍼 처리
                if !multilineBuffer.isEmpty {
                    applyMultilineContent(&info, section: currentSection, subsection: currentSubsection, content: multilineBuffer.trimmingCharacters(in: .whitespacesAndNewlines))
                    multilineBuffer = ""
                }
                currentSection = String(trimmed.dropFirst(3))
                currentSubsection = ""
                continue
            }

            // 서브섹션 헤더 감지
            if trimmed.hasPrefix("### ") {
                if !multilineBuffer.isEmpty {
                    applyMultilineContent(&info, section: currentSection, subsection: currentSubsection, content: multilineBuffer.trimmingCharacters(in: .whitespacesAndNewlines))
                    multilineBuffer = ""
                }
                currentSubsection = String(trimmed.dropFirst(4))
                continue
            }

            // 키-값 파싱 (- **키**: 값)
            if trimmed.hasPrefix("- **") {
                if let colonRange = trimmed.range(of: "**: ") {
                    let key = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: 4)..<colonRange.lowerBound])
                    var value = String(trimmed[colonRange.upperBound...])

                    // 백틱 제거
                    if value.hasPrefix("`") && value.hasSuffix("`") {
                        value = String(value.dropFirst().dropLast())
                    }

                    applyKeyValue(&info, section: currentSection, key: key, value: value)
                } else if trimmed.hasPrefix("- **") && trimmed.hasSuffix("**:") {
                    // 리스트 헤더 (예: - **의존성**:)
                    continue
                }
                continue
            }

            // 리스트 아이템 파싱 (  - 값 또는 - 값)
            if (trimmed.hasPrefix("- ") || line.hasPrefix("  - ")) && !trimmed.hasPrefix("- **") {
                let value = trimmed.hasPrefix("- ") ? String(trimmed.dropFirst(2)) : String(trimmed.dropFirst(2))
                applyListItem(&info, section: currentSection, subsection: currentSubsection, value: value)
                continue
            }

            // 멀티라인 콘텐츠
            if !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                multilineBuffer += line + "\n"
            }
        }

        // 마지막 멀티라인 버퍼 처리
        if !multilineBuffer.isEmpty {
            applyMultilineContent(&info, section: currentSection, subsection: currentSubsection, content: multilineBuffer.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return info
    }

    private static func applyKeyValue(_ info: inout ProjectInfo, section: String, key: String, value: String) {
        switch section {
        case "프로젝트 경로":
            switch key {
            case "상대경로": info.relativePath = value
            case "절대경로": info.absolutePath = value
            default: break
            }
        case "기술 스택":
            switch key {
            case "언어": info.language = value
            case "프레임워크": info.framework = value
            case "빌드 도구": info.buildTool = value
            default: break
            }
        case "개발 가이드":
            switch key {
            case "브랜치 전략": info.branchStrategy = value
            case "커밋 규칙": info.commitConvention = value
            case "코드 스타일": info.codeStyle = value
            default: break
            }
        default: break
        }
    }

    private static func applyListItem(_ info: inout ProjectInfo, section: String, subsection: String, value: String) {
        switch section {
        case "기술 스택":
            info.dependencies.append(value)
        case "제품 정보":
            if subsection == "핵심 기능" {
                info.coreFeatures.append(value)
            }
        case "외부 연동":
            if subsection == "API 엔드포인트" {
                info.apiEndpoints.append(value)
            } else if subsection == "외부 서비스" {
                info.externalServices.append(value)
            }
        default: break
        }
    }

    private static func applyMultilineContent(_ info: inout ProjectInfo, section: String, subsection: String, content: String) {
        switch section {
        case "제품 정보":
            switch subsection {
            case "비전/목표": info.vision = content
            case "타겟 사용자": info.targetUsers = content
            default: break
            }
        case "메모":
            info.notes = content
        case "추가 정보":
            // 커스텀 필드 (subsection이 필드 제목)
            if !subsection.isEmpty {
                let field = CustomField(title: subsection, content: content)
                info.customFields.append(field)
            }
        default: break
        }
    }
}
