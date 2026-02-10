import Foundation
import SwiftUI

/// 데이터 저장 경로 관리 서비스
/// 모든 데이터는 프로젝트 디렉토리 내 datas/ 폴더에 저장됨
class DataPathService {
    static let shared = DataPathService()

    /// 캐시된 프로젝트 루트 경로
    private var cachedProjectRoot: String?

    /// 기본 데이터 저장 경로 (프로젝트 디렉토리 내)
    var basePath: String {
        let fileManager = FileManager.default

        // 프로젝트 루트 찾기
        if let projectRoot = findProjectRoot() {
            let datasPath = "\(projectRoot)/datas"
            // datas 폴더가 없으면 생성
            if !fileManager.fileExists(atPath: datasPath) {
                try? fileManager.createDirectory(atPath: datasPath, withIntermediateDirectories: true)
            }
            return datasPath
        }

        // Fallback: 앱 지원 디렉토리 사용
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let fallbackPath = appSupport.appendingPathComponent("PixelOffice/datas").path

        if !fileManager.fileExists(atPath: fallbackPath) {
            try? fileManager.createDirectory(atPath: fallbackPath, withIntermediateDirectories: true)
        }
        print("⚠️ [DataPathService] 프로젝트 루트를 찾지 못해 fallback 경로 사용: \(fallbackPath)")
        return fallbackPath
    }

    /// 프로젝트 루트 디렉토리 찾기
    private func findProjectRoot() -> String? {
        // 캐시된 경로가 있으면 반환
        if let cached = cachedProjectRoot {
            return cached
        }

        let fileManager = FileManager.default

        // 1. 실행 파일 위치에서 상위로 탐색 (최우선)
        let executablePath = Bundle.main.bundlePath
        var currentPath = (executablePath as NSString).deletingLastPathComponent

        for _ in 0..<15 {
            // PixelOffice.xcodeproj 또는 Project.swift(Tuist) 확인
            let xcodeprojPath = "\(currentPath)/PixelOffice.xcodeproj"
            let tuistPath = "\(currentPath)/Project.swift"
            let datasPath = "\(currentPath)/datas"

            if fileManager.fileExists(atPath: xcodeprojPath) ||
               fileManager.fileExists(atPath: tuistPath) ||
               fileManager.fileExists(atPath: datasPath) {
                cachedProjectRoot = currentPath
                return currentPath
            }

            let parentPath = (currentPath as NSString).deletingLastPathComponent
            if parentPath == currentPath {
                break
            }
            currentPath = parentPath
        }

        // 2. DerivedData에서 실행 중이면 소스 디렉토리 찾기
        if let bundlePath = Bundle.main.resourcePath {
            var checkPath = (bundlePath as NSString).deletingLastPathComponent
            // .app 번들 밖으로 나가기
            while checkPath.hasSuffix(".app") || checkPath.contains(".app/") {
                checkPath = (checkPath as NSString).deletingLastPathComponent
            }

            if checkPath.contains("DerivedData") {
                if let sourceRoot = findSourceProjectFromDerivedData(checkPath) {
                    cachedProjectRoot = sourceRoot
                    return sourceRoot
                }
            }
        }

        // 3. 환경변수에서 프로젝트 경로 확인
        if let envPath = ProcessInfo.processInfo.environment["PIXELOFFICE_PROJECT_ROOT"] {
            if fileManager.fileExists(atPath: envPath) {
                cachedProjectRoot = envPath
                return envPath
            }
        }

        // 4. 일반적인 개발 경로 패턴 탐색
        let homePath = NSHomeDirectory()
        let commonPaths = [
            "\(homePath)/Documents/workspace/code/PixelOffice",
            "\(homePath)/Documents/code/PixelOffice",
            "\(homePath)/Developer/PixelOffice",
            "\(homePath)/Projects/PixelOffice",
            "\(homePath)/Code/PixelOffice"
        ]

        for path in commonPaths {
            let datasPath = "\(path)/datas"
            if fileManager.fileExists(atPath: datasPath) {
                cachedProjectRoot = path
                return path
            }
        }

        return nil
    }

    /// DerivedData 경로에서 소스 프로젝트 경로 찾기
    private func findSourceProjectFromDerivedData(_ derivedDataPath: String) -> String? {
        // DerivedData/PixelOffice-xxx/ 형태에서 프로젝트명 추출
        let components = derivedDataPath.components(separatedBy: "/")

        guard let derivedDataIndex = components.firstIndex(of: "DerivedData"),
              derivedDataIndex + 1 < components.count else {
            return nil
        }

        let projectFolder = components[derivedDataIndex + 1]
        // PixelOffice-gpojubmxexpovxbfrzofqltohtpo -> PixelOffice
        let projectName = projectFolder.components(separatedBy: "-").first ?? projectFolder

        // 일반적인 소스 경로 패턴 확인
        let homePath = NSHomeDirectory()
        let possiblePaths = [
            "\(homePath)/Documents/workspace/code/\(projectName)",
            "\(homePath)/Documents/code/\(projectName)",
            "\(homePath)/Developer/\(projectName)",
            "\(homePath)/Projects/\(projectName)"
        ]

        let fileManager = FileManager.default
        for path in possiblePaths {
            if fileManager.fileExists(atPath: "\(path)/datas") ||
               fileManager.fileExists(atPath: "\(path)/Project.swift") ||
               fileManager.fileExists(atPath: "\(path)/\(projectName).xcodeproj") {
                return path
            }
        }

        return nil
    }

    private init() {
        // 기본 디렉토리 생성
        createBaseDirectories()
    }

    // MARK: - 디렉토리 생성

    /// 기본 디렉토리 구조 생성
    private func createBaseDirectories() {
        var sharedDirs = [
            "\(basePath)/_shared/documents",
            "\(basePath)/_shared/wiki",
            "\(basePath)/_shared/collaboration",
            "\(basePath)/_shared/people"
        ]

        // 부서별 공용 문서 폴더 생성
        for dept in DepartmentType.allCases where dept != .general {
            sharedDirs.append("\(basePath)/_shared/\(dept.directoryName)/documents")
            sharedDirs.append("\(basePath)/_shared/\(dept.directoryName)/people")
        }

        for dir in sharedDirs {
            createDirectoryIfNeeded(at: dir)
        }
    }

    /// 프로젝트 디렉토리 구조 생성
    func createProjectDirectories(projectName: String) {
        let sanitizedName = sanitizeName(projectName)

        // 프로젝트 공용
        createDirectoryIfNeeded(at: "\(basePath)/\(sanitizedName)/_shared/documents")
        createDirectoryIfNeeded(at: "\(basePath)/\(sanitizedName)/_shared/meetings")

        // 부서별
        for dept in DepartmentType.allCases where dept != .general {
            let deptPath = departmentPath(sanitizedName, department: dept)
            createDirectoryIfNeeded(at: "\(deptPath)/documents")
            createDirectoryIfNeeded(at: "\(deptPath)/people")
            createDirectoryIfNeeded(at: "\(deptPath)/tasks")
        }

        // 프로젝트 README 생성
        createProjectReadme(projectName: projectName, sanitizedName: sanitizedName)

        // PIPELINE_CONTEXT.md 자동 생성
        createPipelineContext(projectName: projectName, sanitizedName: sanitizedName)

        // PROJECT.md 자동 생성
        createProjectMd(projectName: projectName, sanitizedName: sanitizedName)
    }

    /// PIPELINE_CONTEXT.md 자동 생성 (파이프라인 실행에 필요)
    private func createPipelineContext(projectName: String, sanitizedName: String) {
        let contextPath = "\(basePath)/\(sanitizedName)/PIPELINE_CONTEXT.md"
        let fileManager = FileManager.default

        guard !fileManager.fileExists(atPath: contextPath) else { return }

        // 프로젝트 루트 (datas의 상위 디렉토리)
        let projectRoot = (basePath as NSString).deletingLastPathComponent

        let content = """
        # \(projectName) - 파이프라인 컨텍스트

        > **파이프라인 실행 전 필수 설정 정보**

        ---

        ## 🔴 필수 정보

        ### 프로젝트 소스 경로

        > ⚠️ **절대경로를 사용하지 마세요!** 여러 컴퓨터에서 작업합니다.

        ```
        ../..
        ```

        **프로젝트 루트 탐색 방법:**
        1. 이 파일(`PIPELINE_CONTEXT.md`) 기준 상대경로 `../..`
        2. 또는 `*.xcodeproj` / `Project.swift` 파일이 있는 폴더 자동 탐색

        ### 빌드 명령

        ```bash
        # 프로젝트 루트에서 실행 (프로젝트에 맞게 수정하세요)
        xcodebuild -project [프로젝트명].xcodeproj -scheme [스킴명] -configuration Debug build
        ```

        ---

        ## 📋 기술 스택

        ### 언어 및 프레임워크

        - **언어**: Swift
        - **프레임워크**: SwiftUI
        - **최소 지원 버전**: macOS 14.0 / iOS 17.0

        ### 빌드 도구

        - **빌드 시스템**: Xcode
        - **패키지 매니저**: SPM (Swift Package Manager)

        ---

        ## 📁 프로젝트 구조

        > 프로젝트 구조를 여기에 작성하세요.

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

        ## 📚 참고 문서 (상대경로, 프로젝트 루트 기준)

        - **claude.md**: `./claude.md`
        - **PROJECT.md**: `./datas/\(sanitizedName)/PROJECT.md`

        ---

        *이 파일은 PixelOffice에서 자동 생성되었습니다.*
        """

        try? content.write(toFile: contextPath, atomically: true, encoding: .utf8)
    }

    /// PROJECT.md 자동 생성
    private func createProjectMd(projectName: String, sanitizedName: String) {
        let projectMdPath = "\(basePath)/\(sanitizedName)/PROJECT.md"
        let fileManager = FileManager.default

        guard !fileManager.fileExists(atPath: projectMdPath) else { return }

        let content = """
        # \(projectName)

        ## 프로젝트 경로

        - **상대경로**: `../..` (이 파일 기준 → 프로젝트 루트)
        - **프로젝트 루트 탐색**: `*.xcodeproj` 또는 `Project.swift` 있는 폴더

        > ⚠️ 절대경로를 사용하지 마세요. 여러 컴퓨터에서 작업합니다.

        ## 기술 스택

        - **프레임워크**: SwiftUI
        - **플랫폼**: macOS / iOS
        - **빌드 도구**: Xcode

        ## 제품 정보

        ### 비전/목표

        > 프로젝트의 비전과 목표를 작성하세요.

        ### 타겟 사용자

        > 타겟 사용자를 정의하세요.

        ### 핵심 기능

        > 핵심 기능을 나열하세요.

        ---

        *이 파일은 PixelOffice에서 자동 생성되었습니다.*
        """

        try? content.write(toFile: projectMdPath, atomically: true, encoding: .utf8)
    }

    /// 프로젝트 README 파일 생성
    private func createProjectReadme(projectName: String, sanitizedName: String) {
        let readmePath = "\(basePath)/\(sanitizedName)/README.md"
        let fileManager = FileManager.default

        guard !fileManager.fileExists(atPath: readmePath) else { return }

        let content = """
        # 📁 \(projectName) 프로젝트 문서 구조

        이 폴더는 **\(projectName)** 프로젝트의 모든 문서를 관리합니다.

        ## 📂 디렉토리 구조

        ```
        \(sanitizedName)/
        ├── _shared/              # 프로젝트 공용 문서
        │   ├── documents/        # 공용 문서 (회의록, 전체 기획 등)
        │   └── meetings/         # 회의록
        │
        ├── 기획/                  # 기획팀 문서
        │   ├── documents/        # PRD, 기획서, 요구사항 정의서
        │   ├── people/           # 기획팀 직원 프로필 및 업무 기록
        │   └── tasks/            # 기획팀 태스크
        │
        ├── 디자인/                # 디자인팀 문서
        │   ├── documents/        # 디자인 가이드, UI/UX 명세서
        │   ├── people/           # 디자인팀 직원 프로필 및 업무 기록
        │   └── tasks/            # 디자인팀 태스크
        │
        ├── 개발/                  # 개발팀 문서
        │   ├── documents/        # 기술 명세서, API 문서, 아키텍처 설계서
        │   ├── people/           # 개발팀 직원 프로필 및 업무 기록
        │   └── tasks/            # 개발팀 태스크
        │
        ├── QA/                    # QA팀 문서
        │   ├── documents/        # 테스트 계획서, QA 리포트
        │   ├── people/           # QA팀 직원 프로필 및 업무 기록
        │   └── tasks/            # QA팀 태스크
        │
        └── 마케팅/                # 마케팅팀 문서
            ├── documents/        # 마케팅 전략, 캠페인 기획서
            ├── people/           # 마케팅팀 직원 프로필 및 업무 기록
            └── tasks/            # 마케팅팀 태스크
        ```

        ## 📝 문서 작성 가이드

        ### 부서별 문서 형식

        | 부서 | 주요 문서 형식 |
        |------|---------------|
        | 기획팀 | PRD, 기획서, 요구사항 정의서, 로드맵 |
        | 디자인팀 | 디자인 가이드, UI/UX 명세서, 스타일 가이드 |
        | 개발팀 | 기술 명세서, API 문서, 아키텍처 설계서 |
        | QA팀 | 테스트 계획서, QA 리포트, 버그 리포트 |
        | 마케팅팀 | 마케팅 전략, 캠페인 기획서, 콘텐츠 가이드 |

        ### 문서 명명 규칙

        - 날짜 포함: `YYYY-MM-DD-제목.md`
        - 버전 포함: `제목-v1.0.md`
        - 영문/한글 혼용 가능

        ## 🔗 협업 가이드

        - 다른 부서의 문서를 참고할 때는 해당 부서의 `documents/` 폴더를 확인하세요.
        - 부서 간 협업 시 `@부서명` 멘션을 사용하면 해당 부서 직원에게 요청됩니다.
        - 회의록은 `_shared/meetings/` 폴더에 저장됩니다.

        ---
        *이 문서는 PixelOffice에서 자동 생성되었습니다.*
        """

        try? content.write(toFile: readmePath, atomically: true, encoding: .utf8)
    }

    /// 디렉토리 생성 (없으면)
    func createDirectoryIfNeeded(at path: String) {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: path) {
            try? fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
        }
    }

    // MARK: - 경로 생성

    /// 전사 공용 경로
    var sharedPath: String {
        "\(basePath)/_shared"
    }

    /// 로그 저장 경로
    var logsPath: String {
        let path = "\(basePath)/_logs"
        createDirectoryIfNeeded(at: path)
        return path
    }

    /// 전사 위키 경로
    var wikiPath: String {
        "\(sharedPath)/wiki"
    }

    /// 프로젝트 위키 경로
    func projectWikiPath(_ projectName: String) -> String {
        let path = "\(projectPath(projectName))/wiki"
        createDirectoryIfNeeded(at: path)
        return path
    }

    /// 전사 협업 기록 경로
    var collaborationPath: String {
        "\(sharedPath)/collaboration"
    }

    /// 프로젝트 경로
    func projectPath(_ projectName: String) -> String {
        "\(basePath)/\(sanitizeName(projectName))"
    }

    /// 프로젝트 공용 경로
    func projectSharedPath(_ projectName: String) -> String {
        "\(projectPath(projectName))/_shared"
    }

    /// 부서 경로
    func departmentPath(_ projectName: String, department: DepartmentType) -> String {
        "\(projectPath(projectName))/\(department.directoryName)"
    }

    /// 부서 문서 경로
    func documentsPath(_ projectName: String, department: DepartmentType) -> String {
        "\(departmentPath(projectName, department: department))/documents"
    }

    /// 부서 직원 기록 경로
    func peoplePath(_ projectName: String, department: DepartmentType) -> String {
        "\(departmentPath(projectName, department: department))/people"
    }

    /// 부서 태스크 경로
    func tasksPath(_ projectName: String, department: DepartmentType) -> String {
        "\(departmentPath(projectName, department: department))/tasks"
    }

    /// 회의록 경로
    func meetingsPath(_ projectName: String) -> String {
        "\(projectSharedPath(projectName))/meetings"
    }

    // MARK: - 파일 경로

    /// 직원 업무 기록 파일 경로
    func employeeWorkLogPath(projectName: String, department: DepartmentType, employeeName: String) -> String {
        let path = peoplePath(projectName, department: department)
        createDirectoryIfNeeded(at: path)
        return "\(path)/\(sanitizeName(employeeName)).md"
    }

    /// 전사 직원 업무 기록 파일 경로 (프로젝트 무관)
    func globalEmployeeWorkLogPath(employeeName: String, employeeId: UUID) -> String {
        let path = "\(sharedPath)/people"
        createDirectoryIfNeeded(at: path)
        let sanitizedName = sanitizeName(employeeName)
        return "\(path)/\(sanitizedName)-\(employeeId.uuidString.prefix(8)).md"
    }

    /// 문서 파일 경로
    func documentPath(projectName: String, department: DepartmentType, fileName: String) -> String {
        let path = documentsPath(projectName, department: department)
        createDirectoryIfNeeded(at: path)
        return "\(path)/\(fileName)"
    }

    /// 태스크 파일 경로
    func taskPath(projectName: String, department: DepartmentType, taskId: String, title: String) -> String {
        let path = tasksPath(projectName, department: department)
        createDirectoryIfNeeded(at: path)
        let sanitizedTitle = sanitizeName(title)
        return "\(path)/\(taskId)-\(sanitizedTitle).md"
    }

    /// 회의록 파일 경로
    func meetingPath(projectName: String, date: Date, title: String) -> String {
        let path = meetingsPath(projectName)
        createDirectoryIfNeeded(at: path)
        let dateStr = formatDate(date)
        let sanitizedTitle = sanitizeName(title)
        return "\(path)/\(dateStr)-\(sanitizedTitle).md"
    }

    /// 협업 기록 파일 경로
    func collaborationRecordPath(date: Date, requesterId: UUID) -> String {
        createDirectoryIfNeeded(at: collaborationPath)
        let dateStr = formatDate(date)
        return "\(collaborationPath)/\(dateStr)-\(requesterId.uuidString.prefix(8)).md"
    }

    // MARK: - 유틸리티

    /// 파일명에 사용할 수 없는 문자 제거
    func sanitizeName(_ name: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return name
            .components(separatedBy: invalidChars)
            .joined()
            .replacingOccurrences(of: " ", with: "-")
    }

    /// 날짜 포맷
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// 날짜+시간 포맷
    func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter.string(from: date)
    }
}

// MARK: - DepartmentType 확장

extension DepartmentType {
    /// 디렉토리명
    var directoryName: String {
        switch self {
        case .planning: return "기획"
        case .design: return "디자인"
        case .development: return "개발"
        case .qa: return "QA"
        case .marketing: return "마케팅"
        case .general: return "일반"
        }
    }
}
