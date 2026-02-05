import Foundation
import AppKit

/// 회사 위키 파일 관리 서비스
class WikiService {
    static let shared = WikiService()

    private let fileManager = FileManager.default

    /// 기본 위키 경로 (프로젝트 디렉토리 내)
    var defaultWikiPath: String {
        DataPathService.shared.wikiPath
    }

    /// 위키 폴더 초기화
    func initializeWiki(at path: String) throws {
        // 메인 폴더 생성
        if !fileManager.fileExists(atPath: path) {
            try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true)
        }

        // 카테고리별 하위 폴더 생성
        for category in WikiCategory.allCases {
            let categoryPath = (path as NSString).appendingPathComponent(category.folderName)
            if !fileManager.fileExists(atPath: categoryPath) {
                try fileManager.createDirectory(atPath: categoryPath, withIntermediateDirectories: true)
            }
        }

        // README.md 생성
        let readmePath = (path as NSString).appendingPathComponent("README.md")
        if !fileManager.fileExists(atPath: readmePath) {
            let readme = """
            # 🏢 회사 위키

            PixelOffice에서 자동 생성된 회사 문서입니다.

            ## 📁 폴더 구조

            - `company/` - 회사 정보 (비전, 미션, 조직 구조 등)
            - `projects/` - 프로젝트 문서 (기획서, 명세서 등)
            - `guidelines/` - 가이드라인 (코딩 컨벤션, 디자인 가이드 등)
            - `onboarding/` - 온보딩 문서 (신규 직원 정보)
            - `meetings/` - 회의록
            - `reference/` - 참고 자료

            ## 🔗 빠른 링크

            - [회사 정보](./company/)
            - [프로젝트](./projects/)
            - [가이드라인](./guidelines/)

            ---
            *이 위키는 PixelOffice에서 자동 관리됩니다.*
            """
            try readme.write(toFile: readmePath, atomically: true, encoding: .utf8)
        }
    }

    /// 문서 저장
    func saveDocument(_ document: WikiDocument, at wikiPath: String) throws {
        let categoryPath = (wikiPath as NSString).appendingPathComponent(document.category.folderName)
        let filePath = (categoryPath as NSString).appendingPathComponent(document.fileName)

        let content = document.toMarkdown()
        try content.write(toFile: filePath, atomically: true, encoding: .utf8)
    }

    /// 문서 삭제
    func deleteDocument(_ document: WikiDocument, at wikiPath: String) throws {
        let categoryPath = (wikiPath as NSString).appendingPathComponent(document.category.folderName)
        let filePath = (categoryPath as NSString).appendingPathComponent(document.fileName)

        if fileManager.fileExists(atPath: filePath) {
            try fileManager.removeItem(atPath: filePath)
        }
    }

    /// 온보딩 결과를 문서로 저장
    func saveOnboardingDocument(
        employeeName: String,
        departmentType: DepartmentType,
        questions: [OnboardingQuestion],
        at wikiPath: String
    ) throws -> WikiDocument {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())

        var content = """
        ## 👤 직원 정보

        - **이름**: \(employeeName)
        - **부서**: \(departmentType.rawValue)팀
        - **입사일**: \(dateString)

        ## 📋 온보딩 Q&A

        """

        // 카테고리별로 그룹화
        let groupedQuestions = Dictionary(grouping: questions) { $0.category }

        for category in OnboardingCategory.allCases {
            if let categoryQuestions = groupedQuestions[category], !categoryQuestions.isEmpty {
                content += "\n### \(category.rawValue)\n\n"

                for question in categoryQuestions {
                    content += "**Q: \(question.question)**\n\n"
                    if let answer = question.answer, !answer.isEmpty {
                        content += "> \(answer)\n\n"
                    } else {
                        content += "> *(미답변)*\n\n"
                    }
                }
            }
        }

        let document = WikiDocument(
            title: "\(employeeName) 온보딩",
            content: content,
            category: .onboarding,
            createdBy: "CEO",
            tags: [departmentType.rawValue, "온보딩", dateString]
        )

        try saveDocument(document, at: wikiPath)
        return document
    }

    /// 회사 정보 문서 생성
    func createCompanyInfoDocument(from onboardings: [EmployeeOnboarding], employees: [Employee], at wikiPath: String) throws {
        var visionMission = ""
        var targetCustomers = ""
        var techStack = ""
        var designStyle = ""

        // 온보딩 답변에서 정보 추출
        for onboarding in onboardings {
            for question in onboarding.questions {
                guard let answer = question.answer, !answer.isEmpty else { continue }

                if question.question.contains("비전") || question.question.contains("미션") {
                    visionMission = answer
                } else if question.question.contains("타겟") || question.question.contains("고객") {
                    targetCustomers = answer
                } else if question.question.contains("기술 스택") {
                    techStack = answer
                } else if question.question.contains("디자인 스타일") {
                    designStyle = answer
                }
            }
        }

        let content = """
        ## 🎯 비전 & 미션

        \(visionMission.isEmpty ? "*아직 정의되지 않았습니다*" : visionMission)

        ## 👥 타겟 고객

        \(targetCustomers.isEmpty ? "*아직 정의되지 않았습니다*" : targetCustomers)

        ## 💻 기술 스택

        \(techStack.isEmpty ? "*아직 정의되지 않았습니다*" : techStack)

        ## 🎨 디자인 방향

        \(designStyle.isEmpty ? "*아직 정의되지 않았습니다*" : designStyle)

        ## 👔 조직 현황

        현재 직원 수: \(employees.count)명

        ### 부서별 현황

        | 부서 | 인원 |
        |------|------|
        \(DepartmentType.allCases.filter { $0 != .general }.map { type in
            let count = employees.filter { $0.aiType.rawValue == type.rawValue }.count
            return "| \(type.rawValue) | \(count)명 |"
        }.joined(separator: "\n"))

        ---
        *이 문서는 온보딩 답변을 기반으로 자동 생성되었습니다.*
        """

        let document = WikiDocument(
            title: "회사 정보",
            content: content,
            category: .companyInfo,
            createdBy: "시스템",
            tags: ["회사", "정보", "자동생성"],
            fileName: "company-info.md"
        )

        try saveDocument(document, at: wikiPath)
    }

    /// 위키 폴더에서 기존 .md 파일 스캔
    func scanExistingDocuments(at wikiPath: String) -> [WikiDocument] {
        var documents: [WikiDocument] = []

        // 각 카테고리 폴더 스캔
        for category in WikiCategory.allCases {
            let categoryPath = (wikiPath as NSString).appendingPathComponent(category.folderName)

            guard let files = try? fileManager.contentsOfDirectory(atPath: categoryPath) else { continue }

            for fileName in files where fileName.hasSuffix(".md") || fileName.hasSuffix(".html") {
                let filePath = (categoryPath as NSString).appendingPathComponent(fileName)

                if let content = try? String(contentsOfFile: filePath, encoding: .utf8) {
                    // 파일명에서 제목 추출 (확장자 제거)
                    let title = (fileName as NSString).deletingPathExtension
                        .replacingOccurrences(of: "-", with: " ")
                        .replacingOccurrences(of: "_", with: " ")

                    let fileType: WikiDocumentType = fileName.hasSuffix(".html") ? .html : .markdown

                    let document = WikiDocument(
                        title: title,
                        content: content,
                        category: category,
                        createdBy: "외부 파일",
                        tags: [],
                        fileName: fileName,
                        fileType: fileType
                    )
                    documents.append(document)
                }
            }
        }

        // 루트 폴더의 .md 파일도 스캔 (README.md 제외)
        if let rootFiles = try? fileManager.contentsOfDirectory(atPath: wikiPath) {
            for fileName in rootFiles where (fileName.hasSuffix(".md") || fileName.hasSuffix(".html")) && fileName != "README.md" {
                let filePath = (wikiPath as NSString).appendingPathComponent(fileName)

                if let content = try? String(contentsOfFile: filePath, encoding: .utf8) {
                    let title = (fileName as NSString).deletingPathExtension
                        .replacingOccurrences(of: "-", with: " ")
                        .replacingOccurrences(of: "_", with: " ")

                    let fileType: WikiDocumentType = fileName.hasSuffix(".html") ? .html : .markdown

                    let document = WikiDocument(
                        title: title,
                        content: content,
                        category: .reference,  // 루트 파일은 참고자료로 분류
                        createdBy: "외부 파일",
                        tags: [],
                        fileName: fileName,
                        fileType: fileType
                    )
                    documents.append(document)
                }
            }
        }

        return documents
    }

    /// 프로젝트 전체에서 모든 .md 문서 스캔
    func scanAllDocuments() -> [WikiDocument] {
        print("📚 [WikiService] 전체 문서 스캔 시작")
        var allDocuments: [WikiDocument] = []
        let basePath = DataPathService.shared.basePath

        // 1. _shared/wiki 스캔
        let sharedWikiPath = "\(DataPathService.shared.sharedPath)/wiki"
        print("📂 [WikiService] _shared/wiki 스캔: \(sharedWikiPath)")
        let sharedWikiDocs = scanDirectory(at: sharedWikiPath, category: .reference, source: "전사 공용", departmentName: nil, projectName: nil)
        allDocuments.append(contentsOf: sharedWikiDocs)
        print("   ✅ 발견: \(sharedWikiDocs.count)개")

        // 2. _shared/documents 스캔
        let sharedDocsPath = "\(DataPathService.shared.sharedPath)/documents"
        print("📂 [WikiService] _shared/documents 스캔: \(sharedDocsPath)")
        let sharedDocs = scanDirectory(at: sharedDocsPath, category: .companyInfo, source: "전사 공용", departmentName: nil, projectName: nil)
        allDocuments.append(contentsOf: sharedDocs)
        print("   ✅ 발견: \(sharedDocs.count)개")

        // 3. 각 프로젝트의 wiki와 documents 스캔
        guard let projectDirs = try? fileManager.contentsOfDirectory(atPath: basePath) else {
            print("❌ [WikiService] basePath 읽기 실패: \(basePath)")
            return allDocuments
        }

        for projectDir in projectDirs {
            // _shared는 이미 스캔했으므로 스킵
            if projectDir.hasPrefix("_") || projectDir.hasPrefix(".") {
                continue
            }

            let projectPath = "\(basePath)/\(projectDir)"

            // 프로젝트가 디렉토리인지 확인
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: projectPath, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                continue
            }

            print("📁 [WikiService] 프로젝트 스캔: \(projectDir)")

            // 3-1. 프로젝트/wiki 스캔
            let projectWikiPath = "\(projectPath)/wiki"
            let projectWikiDocs = scanDirectory(at: projectWikiPath, category: .projectDocs, source: projectDir, departmentName: nil, projectName: projectDir)
            allDocuments.append(contentsOf: projectWikiDocs)
            if !projectWikiDocs.isEmpty {
                print("   📄 wiki: \(projectWikiDocs.count)개")
            }

            // 3-2. 프로젝트/[부서]/documents 스캔
            guard let deptDirs = try? fileManager.contentsOfDirectory(atPath: projectPath) else {
                continue
            }

            for deptDir in deptDirs {
                // wiki, _shared 등 특수 디렉토리 스킵
                if deptDir.hasPrefix("_") || deptDir.hasPrefix(".") || deptDir == "wiki" {
                    continue
                }

                let deptPath = "\(projectPath)/\(deptDir)"
                var isDeptDirectory: ObjCBool = false
                guard fileManager.fileExists(atPath: deptPath, isDirectory: &isDeptDirectory),
                      isDeptDirectory.boolValue else {
                    continue
                }

                // 부서명을 한글로 변환 (기획, 디자인, 개발 등)
                let departmentName = deptDir

                // 부서/documents 스캔
                let deptDocsPath = "\(deptPath)/documents"
                let deptDocs = scanDirectory(at: deptDocsPath, category: .guidelines, source: "\(departmentName)팀", departmentName: departmentName, projectName: projectDir)
                allDocuments.append(contentsOf: deptDocs)
                if !deptDocs.isEmpty {
                    print("   📄 \(deptDir)/documents: \(deptDocs.count)개")
                }
            }
        }

        print("📊 [WikiService] 전체 문서 스캔 완료: 총 \(allDocuments.count)개")
        return allDocuments
    }

    /// 특정 디렉토리의 .md 및 .html 파일 스캔
    private func scanDirectory(at path: String, category: WikiCategory, source: String, departmentName: String?, projectName: String?) -> [WikiDocument] {
        var documents: [WikiDocument] = []

        guard fileManager.fileExists(atPath: path) else {
            return documents
        }

        // 재귀적으로 하위 디렉토리도 스캔
        guard let enumerator = fileManager.enumerator(atPath: path) else {
            return documents
        }

        while let fileName = enumerator.nextObject() as? String {
            // .md 또는 .html 파일만 처리
            let isMarkdown = fileName.hasSuffix(".md")
            let isHTML = fileName.hasSuffix(".html")
            guard isMarkdown || isHTML else { continue }

            // README.md는 스킵
            if fileName.contains("README.md") {
                continue
            }

            let filePath = "\(path)/\(fileName)"

            if let content = try? String(contentsOfFile: filePath, encoding: .utf8) {
                // 파일명에서 제목 추출
                let baseName = (fileName as NSString).lastPathComponent
                let title = (baseName as NSString).deletingPathExtension
                    .replacingOccurrences(of: "-", with: " ")
                    .replacingOccurrences(of: "_", with: " ")

                // 태그 구성: [프로젝트명, 부서명] (있는 경우만)
                var tags: [String] = []
                if let proj = projectName {
                    tags.append(proj)
                }
                if let dept = departmentName {
                    tags.append("\(dept)팀")
                }

                let fileType: WikiDocumentType = isHTML ? .html : .markdown

                let document = WikiDocument(
                    title: title,
                    content: content,
                    category: category,
                    createdBy: source,  // "기획팀", "개발팀", "전사 공용" 등
                    tags: tags,
                    fileName: baseName,
                    filePath: filePath,  // 전체 경로 저장
                    fileType: fileType
                )
                documents.append(document)
            }
        }

        return documents
    }

    /// Finder에서 위키 폴더 열기
    func openWikiInFinder(at path: String) {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
    }

    /// 특정 문서를 기본 앱으로 열기
    func openDocument(_ document: WikiDocument, at wikiPath: String) {
        let categoryPath = (wikiPath as NSString).appendingPathComponent(document.category.folderName)
        let filePath = (categoryPath as NSString).appendingPathComponent(document.fileName)
        let url = URL(fileURLWithPath: filePath)

        NSWorkspace.shared.open(url)
    }

    /// 에디터로 문서 열기 (VSCode, Typora 등)
    func openDocumentInEditor(_ document: WikiDocument, at wikiPath: String, editor: String) {
        let categoryPath = (wikiPath as NSString).appendingPathComponent(document.category.folderName)
        let filePath = (categoryPath as NSString).appendingPathComponent(document.fileName)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", editor, filePath]

        try? process.run()
    }
}
