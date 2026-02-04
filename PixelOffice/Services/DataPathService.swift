import Foundation

/// 데이터 저장 경로 관리 서비스
/// 모든 데이터는 프로젝트 디렉토리 내 datas/ 폴더에 저장됨
class DataPathService {
    static let shared = DataPathService()

    /// 기본 데이터 저장 경로 (프로젝트 디렉토리 내)
    var basePath: String {
        let fileManager = FileManager.default
        let homePath = NSHomeDirectory()

        // 프로젝트의 예상 경로 (사용자 홈 기준)
        let projectPath = "\(homePath)/Documents/workspace/code/PixelOffice/datas"

        // 경로가 존재하면 사용
        if fileManager.fileExists(atPath: projectPath) {
            return projectPath
        }

        // 경로가 없으면 생성 시도
        try? fileManager.createDirectory(atPath: projectPath, withIntermediateDirectories: true)
        return projectPath
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
