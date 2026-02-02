import Foundation

/// 회사 위키 문서
struct WikiDocument: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var content: String
    var category: WikiCategory
    var createdAt: Date
    var updatedAt: Date
    var createdBy: String  // 직원 이름 또는 "CEO"
    var tags: [String]
    var fileName: String

    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        category: WikiCategory,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        createdBy: String = "CEO",
        tags: [String] = [],
        fileName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.category = category
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.createdBy = createdBy
        self.tags = tags
        self.fileName = fileName ?? Self.generateFileName(from: title)
    }

    static func generateFileName(from title: String) -> String {
        let sanitized = title
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-")).inverted)
            .joined()
        return "\(sanitized).md"
    }

    /// 마크다운 파일 내용 생성
    func toMarkdown() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"

        var md = """
        # \(title)

        > 카테고리: \(category.rawValue)
        > 작성자: \(createdBy)
        > 작성일: \(dateFormatter.string(from: createdAt))
        > 수정일: \(dateFormatter.string(from: updatedAt))

        """

        if !tags.isEmpty {
            md += "> 태그: \(tags.joined(separator: ", "))\n"
        }

        md += "\n---\n\n"
        md += content

        return md
    }
}

enum WikiCategory: String, Codable, CaseIterable {
    case companyInfo = "회사 정보"
    case projectDocs = "프로젝트 문서"
    case guidelines = "가이드라인"
    case onboarding = "온보딩"
    case meeting = "회의록"
    case reference = "참고 자료"

    var icon: String {
        switch self {
        case .companyInfo: return "building.2.fill"
        case .projectDocs: return "folder.fill"
        case .guidelines: return "book.fill"
        case .onboarding: return "person.badge.plus"
        case .meeting: return "calendar"
        case .reference: return "link"
        }
    }

    var folderName: String {
        switch self {
        case .companyInfo: return "company"
        case .projectDocs: return "projects"
        case .guidelines: return "guidelines"
        case .onboarding: return "onboarding"
        case .meeting: return "meetings"
        case .reference: return "reference"
        }
    }
}

/// 회사 위키 설정
struct WikiSettings: Codable {
    var wikiPath: String  // 위키 파일 저장 경로
    var autoSync: Bool    // 변경 시 자동 저장
    var openInEditor: String  // 기본 에디터 (예: "Typora", "VSCode", "")

    init(
        wikiPath: String = "",
        autoSync: Bool = true,
        openInEditor: String = ""
    ) {
        self.wikiPath = wikiPath
        self.autoSync = autoSync
        self.openInEditor = openInEditor
    }

    var hasValidPath: Bool {
        !wikiPath.isEmpty && FileManager.default.fileExists(atPath: wikiPath)
    }
}
