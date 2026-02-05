import Foundation

/// 위키 문서 타입
enum WikiDocumentType: String, Codable {
    case markdown = "마크다운"
    case html = "HTML"

    var fileExtension: String {
        switch self {
        case .markdown: return ".md"
        case .html: return ".html"
        }
    }

    var icon: String {
        switch self {
        case .markdown: return "doc.text"
        case .html: return "globe"
        }
    }
}

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
    var filePath: String?  // 전체 파일 경로 (선택적)
    var fileType: WikiDocumentType  // 파일 타입 (마크다운 또는 HTML)

    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        category: WikiCategory,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        createdBy: String = "CEO",
        tags: [String] = [],
        fileName: String? = nil,
        filePath: String? = nil,
        fileType: WikiDocumentType = .markdown
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.category = category
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.createdBy = createdBy
        self.tags = tags
        self.fileType = fileType
        self.fileName = fileName ?? Self.generateFileName(from: title, type: fileType)
        self.filePath = filePath
    }

    static func generateFileName(from title: String, type: WikiDocumentType = .markdown) -> String {
        let sanitized = title
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-")).inverted)
            .joined()
        return "\(sanitized)\(type.fileExtension)"
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

    // Codable 호환성: 기존 문서는 fileType이 없을 수 있음
    enum CodingKeys: String, CodingKey {
        case id, title, content, category, createdAt, updatedAt, createdBy, tags, fileName, filePath, fileType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        category = try container.decode(WikiCategory.self, forKey: .category)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        createdBy = try container.decode(String.self, forKey: .createdBy)
        tags = try container.decode([String].self, forKey: .tags)
        fileName = try container.decode(String.self, forKey: .fileName)
        filePath = try container.decodeIfPresent(String.self, forKey: .filePath)

        // fileType은 없을 수 있으므로 fileName으로 추론
        if let type = try? container.decode(WikiDocumentType.self, forKey: .fileType) {
            fileType = type
        } else {
            // 기존 문서: 파일 확장자로 판단
            fileType = fileName.hasSuffix(".html") ? .html : .markdown
        }
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
