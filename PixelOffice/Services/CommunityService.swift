import Foundation

// MARK: - Models

/// 커뮤니티 생각 글
struct CommunityThought: Identifiable, Codable {
    let id: String
    var title: String
    var content: String
    var author: String
    var authorId: String
    var department: String
    var project: String?
    var created: Date
    var tags: [String]
    var comments: [ThoughtComment]
    
    var fileName: String {
        "\(id).md"
    }
}

/// 댓글
struct ThoughtComment: Identifiable, Codable {
    let id: String
    var author: String
    var authorId: String
    var department: String
    var content: String
    var created: Date
}

/// 회의 기록
struct CommunityConversation: Identifiable, Codable {
    let id: String
    var topic: String
    var project: String?
    var participants: [String]
    var initiator: String
    var started: Date
    var ended: Date?
    var status: ConversationStatus
    var summary: String?
    var messages: [ConversationMessage]
    
    var fileName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: started)
        let sanitizedTopic = topic
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
        return "\(dateStr)-\(sanitizedTopic).md"
    }
}

enum ConversationStatus: String, Codable {
    case inProgress = "in-progress"
    case completed = "completed"
}

/// 회의 메시지
struct ConversationMessage: Identifiable, Codable {
    let id: String
    var author: String
    var department: String
    var content: String
    var timestamp: Date
}

// MARK: - Service

/// 커뮤니티 서비스 - AI 직원 간 생각 공유 및 회의
class CommunityService {
    static let shared = CommunityService()
    
    private let fileManager = FileManager.default
    
    // MARK: - Paths
    
    /// 커뮤니티 기본 경로
    var communityPath: String {
        "\(DataPathService.shared.basePath)/_community"
    }
    
    /// 생각 글 경로
    var thoughtsPath: String {
        "\(communityPath)/thoughts"
    }
    
    /// 회의 기록 경로
    var conversationsPath: String {
        "\(communityPath)/conversations"
    }
    
    // MARK: - Initialization
    
    private init() {
        createDirectoriesIfNeeded()
    }
    
    private func createDirectoriesIfNeeded() {
        DataPathService.shared.createDirectoryIfNeeded(at: thoughtsPath)
        DataPathService.shared.createDirectoryIfNeeded(at: conversationsPath)
    }
    
    // MARK: - Thought Operations
    
    /// 새 생각 글 ID 생성
    func generateThoughtId() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: Date())
        
        // 오늘 날짜의 마지막 순번 찾기
        let existingThoughts = listThoughts()
        let todayThoughts = existingThoughts.filter { $0.id.hasPrefix(dateStr) }
        let nextNumber = todayThoughts.count + 1
        
        return String(format: "%@-%03d", dateStr, nextNumber)
    }
    
    /// 생각 글 저장
    func saveThought(_ thought: CommunityThought) throws {
        let filePath = "\(thoughtsPath)/\(thought.fileName)"
        let content = thoughtToMarkdown(thought)
        try content.write(toFile: filePath, atomically: true, encoding: .utf8)
    }
    
    /// 생각 글 목록 조회
    func listThoughts() -> [CommunityThought] {
        guard let files = try? fileManager.contentsOfDirectory(atPath: thoughtsPath) else {
            return []
        }
        
        return files
            .filter { $0.hasSuffix(".md") }
            .compactMap { fileName in
                let filePath = "\(thoughtsPath)/\(fileName)"
                return parseThoughtFromFile(at: filePath)
            }
            .sorted { $0.created > $1.created }
    }
    
    /// 생각 글 조회
    func getThought(id: String) -> CommunityThought? {
        let filePath = "\(thoughtsPath)/\(id).md"
        return parseThoughtFromFile(at: filePath)
    }
    
    /// 댓글 추가
    func addComment(to thoughtId: String, comment: ThoughtComment) throws {
        guard var thought = getThought(id: thoughtId) else {
            throw CommunityError.thoughtNotFound
        }
        
        thought.comments.append(comment)
        try saveThought(thought)
    }
    
    // MARK: - Conversation Operations
    
    /// 회의 ID 생성
    func generateConversationId() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return "conv-\(formatter.string(from: Date()))"
    }
    
    /// 회의 시작
    func startConversation(topic: String, project: String?, participants: [String], initiator: String) -> CommunityConversation {
        let conversation = CommunityConversation(
            id: generateConversationId(),
            topic: topic,
            project: project,
            participants: participants,
            initiator: initiator,
            started: Date(),
            ended: nil,
            status: .inProgress,
            summary: nil,
            messages: []
        )
        
        try? saveConversation(conversation)
        return conversation
    }
    
    /// 회의에 메시지 추가
    func addMessage(to conversationId: String, message: ConversationMessage) throws {
        guard var conversation = getConversation(id: conversationId) else {
            throw CommunityError.conversationNotFound
        }
        
        conversation.messages.append(message)
        try saveConversation(conversation)
    }
    
    /// 회의 종료
    func endConversation(id: String, summary: String?) throws {
        guard var conversation = getConversation(id: id) else {
            throw CommunityError.conversationNotFound
        }
        
        conversation.ended = Date()
        conversation.status = .completed
        conversation.summary = summary
        try saveConversation(conversation)
    }
    
    /// 회의 저장
    func saveConversation(_ conversation: CommunityConversation) throws {
        let filePath = "\(conversationsPath)/\(conversation.fileName)"
        let content = conversationToMarkdown(conversation)
        try content.write(toFile: filePath, atomically: true, encoding: .utf8)
    }
    
    /// 회의 목록 조회
    func listConversations() -> [CommunityConversation] {
        guard let files = try? fileManager.contentsOfDirectory(atPath: conversationsPath) else {
            return []
        }
        
        return files
            .filter { $0.hasSuffix(".md") }
            .compactMap { fileName in
                let filePath = "\(conversationsPath)/\(fileName)"
                return parseConversationFromFile(at: filePath)
            }
            .sorted { $0.started > $1.started }
    }
    
    /// 회의 조회
    func getConversation(id: String) -> CommunityConversation? {
        // id로 파일 찾기
        guard let files = try? fileManager.contentsOfDirectory(atPath: conversationsPath) else {
            return nil
        }
        
        for fileName in files where fileName.hasSuffix(".md") {
            let filePath = "\(conversationsPath)/\(fileName)"
            if let conversation = parseConversationFromFile(at: filePath),
               conversation.id == id {
                return conversation
            }
        }
        return nil
    }
    
    /// 진행 중인 회의 조회
    func getActiveConversations() -> [CommunityConversation] {
        listConversations().filter { $0.status == .inProgress }
    }
    
    // MARK: - Markdown Conversion
    
    private func thoughtToMarkdown(_ thought: CommunityThought) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        
        var md = """
        ---
        id: "\(thought.id)"
        title: "\(thought.title)"
        author: "\(thought.author)"
        authorId: "\(thought.authorId)"
        department: "\(thought.department)"
        project: \(thought.project.map { "\"\($0)\"" } ?? "null")
        created: "\(formatter.string(from: thought.created))"
        tags: [\(thought.tags.map { "\"\($0)\"" }.joined(separator: ", "))]
        ---
        
        # \(thought.title)
        
        \(thought.content)
        
        ---
        
        ## 💬 댓글
        
        """
        
        if thought.comments.isEmpty {
            md += "(아직 댓글이 없습니다)\n"
        } else {
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "yyyy-MM-dd HH:mm"
            
            for comment in thought.comments {
                md += """
                
                ### \(comment.author) (@\(comment.department)) | \(timeFormatter.string(from: comment.created))
                \(comment.content)
                
                """
            }
        }
        
        return md
    }
    
    private func conversationToMarkdown(_ conversation: CommunityConversation) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        
        var md = """
        ---
        id: "\(conversation.id)"
        topic: "\(conversation.topic)"
        project: \(conversation.project.map { "\"\($0)\"" } ?? "null")
        participants: [\(conversation.participants.map { "\"\($0)\"" }.joined(separator: ", "))]
        initiator: "\(conversation.initiator)"
        started: "\(formatter.string(from: conversation.started))"
        ended: \(conversation.ended.map { "\"\(formatter.string(from: $0))\"" } ?? "null")
        status: "\(conversation.status.rawValue)"
        summary: \(conversation.summary.map { "\"\($0)\"" } ?? "null")
        ---
        
        # 회의: \(conversation.topic)
        
        ## 참석자
        \(conversation.participants.map { "- \($0)" }.joined(separator: "\n"))
        
        ---
        
        ## 대화 기록
        
        """
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        
        for message in conversation.messages {
            md += """
            
            ### \(message.author) | \(timeFormatter.string(from: message.timestamp))
            \(message.content)
            
            """
        }
        
        if conversation.status == .completed {
            md += """
            
            ---
            
            ## 결론
            
            \(conversation.summary ?? "(요약 없음)")
            """
        }
        
        return md
    }
    
    // MARK: - Parsing
    
    private func parseThoughtFromFile(at path: String) -> CommunityThought? {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return nil
        }
        
        // YAML frontmatter 파싱
        guard let frontmatter = extractFrontmatter(from: content) else {
            return nil
        }
        
        let id = frontmatter["id"] ?? ""
        let title = frontmatter["title"] ?? ""
        let author = frontmatter["author"] ?? ""
        let authorId = frontmatter["authorId"] ?? ""
        let department = frontmatter["department"] ?? ""
        let project = frontmatter["project"]
        let created = parseISO8601Date(frontmatter["created"] ?? "") ?? Date()
        let tags = parseTags(frontmatter["tags"] ?? "")
        
        // 본문과 댓글 분리
        let bodyAndComments = extractBodyAndComments(from: content)
        
        return CommunityThought(
            id: id,
            title: title,
            content: bodyAndComments.body,
            author: author,
            authorId: authorId,
            department: department,
            project: project == "null" ? nil : project,
            created: created,
            tags: tags,
            comments: bodyAndComments.comments
        )
    }
    
    private func parseConversationFromFile(at path: String) -> CommunityConversation? {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return nil
        }
        
        guard let frontmatter = extractFrontmatter(from: content) else {
            return nil
        }
        
        let id = frontmatter["id"] ?? ""
        let topic = frontmatter["topic"] ?? ""
        let project = frontmatter["project"]
        let participants = parseArray(frontmatter["participants"] ?? "")
        let initiator = frontmatter["initiator"] ?? ""
        let started = parseISO8601Date(frontmatter["started"] ?? "") ?? Date()
        let ended = frontmatter["ended"].flatMap { $0 == "null" ? nil : parseISO8601Date($0) }
        let status = ConversationStatus(rawValue: frontmatter["status"] ?? "") ?? .inProgress
        let summary = frontmatter["summary"]
        
        // 메시지 파싱
        let messages = extractConversationMessages(from: content)
        
        return CommunityConversation(
            id: id,
            topic: topic,
            project: project == "null" ? nil : project,
            participants: participants,
            initiator: initiator,
            started: started,
            ended: ended,
            status: status,
            summary: summary == "null" ? nil : summary,
            messages: messages
        )
    }
    
    private func extractFrontmatter(from content: String) -> [String: String]? {
        let pattern = #"^---\n([\s\S]*?)\n---"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
              let range = Range(match.range(at: 1), in: content) else {
            return nil
        }
        
        let yaml = String(content[range])
        var result: [String: String] = [:]
        
        for line in yaml.components(separatedBy: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
                var value = String(parts[1]).trimmingCharacters(in: .whitespaces)
                // Remove quotes
                if value.hasPrefix("\"") && value.hasSuffix("\"") {
                    value = String(value.dropFirst().dropLast())
                }
                result[key] = value
            }
        }
        
        return result
    }
    
    private func extractBodyAndComments(from content: String) -> (body: String, comments: [ThoughtComment]) {
        // frontmatter 이후 내용 추출
        let parts = content.components(separatedBy: "---")
        guard parts.count >= 3 else {
            return ("", [])
        }
        
        let afterFrontmatter = parts.dropFirst(2).joined(separator: "---")
        
        // "## 💬 댓글" 기준으로 분리
        let commentSplit = afterFrontmatter.components(separatedBy: "## 💬 댓글")
        
        var body = ""
        if let titleAndBody = commentSplit.first {
            // # 제목 라인 제거
            let lines = titleAndBody.components(separatedBy: "\n")
            let bodyLines = lines.drop(while: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("#") || $0.trimmingCharacters(in: .whitespaces).isEmpty })
            body = bodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // 댓글 파싱 (간단히 ### 패턴으로)
        var comments: [ThoughtComment] = []
        if commentSplit.count > 1 {
            let commentSection = commentSplit[1]
            let commentPattern = #"### (.+?) \(@(.+?)\) \| (\d{4}-\d{2}-\d{2} \d{2}:\d{2})\n([\s\S]*?)(?=\n### |\z)"#
            
            if let regex = try? NSRegularExpression(pattern: commentPattern) {
                let matches = regex.matches(in: commentSection, range: NSRange(commentSection.startIndex..., in: commentSection))
                
                for match in matches {
                    if let authorRange = Range(match.range(at: 1), in: commentSection),
                       let deptRange = Range(match.range(at: 2), in: commentSection),
                       let dateRange = Range(match.range(at: 3), in: commentSection),
                       let contentRange = Range(match.range(at: 4), in: commentSection) {
                        
                        let author = String(commentSection[authorRange])
                        let dept = String(commentSection[deptRange])
                        let dateStr = String(commentSection[dateRange])
                        let commentContent = String(commentSection[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd HH:mm"
                        let date = formatter.date(from: dateStr) ?? Date()
                        
                        let comment = ThoughtComment(
                            id: UUID().uuidString,
                            author: author,
                            authorId: "",
                            department: dept,
                            content: commentContent,
                            created: date
                        )
                        comments.append(comment)
                    }
                }
            }
        }
        
        return (body, comments)
    }
    
    private func extractConversationMessages(from content: String) -> [ConversationMessage] {
        var messages: [ConversationMessage] = []
        
        // "## 대화 기록" 이후 파싱
        guard let recordStart = content.range(of: "## 대화 기록") else {
            return messages
        }
        
        var messageSection = String(content[recordStart.upperBound...])
        
        // "## 결론" 이전까지만
        if let conclusionRange = messageSection.range(of: "## 결론") {
            messageSection = String(messageSection[..<conclusionRange.lowerBound])
        }
        
        let messagePattern = #"### (.+?) \| (\d{2}:\d{2})\n([\s\S]*?)(?=\n### |\z)"#
        
        if let regex = try? NSRegularExpression(pattern: messagePattern) {
            let matches = regex.matches(in: messageSection, range: NSRange(messageSection.startIndex..., in: messageSection))
            
            for match in matches {
                if let authorRange = Range(match.range(at: 1), in: messageSection),
                   let timeRange = Range(match.range(at: 2), in: messageSection),
                   let contentRange = Range(match.range(at: 3), in: messageSection) {
                    
                    let author = String(messageSection[authorRange])
                    let timeStr = String(messageSection[timeRange])
                    let msgContent = String(messageSection[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // 시간 파싱 (오늘 날짜 + 시간)
                    let formatter = DateFormatter()
                    formatter.dateFormat = "HH:mm"
                    let time = formatter.date(from: timeStr) ?? Date()
                    
                    let message = ConversationMessage(
                        id: UUID().uuidString,
                        author: author,
                        department: "",
                        content: msgContent,
                        timestamp: time
                    )
                    messages.append(message)
                }
            }
        }
        
        return messages
    }
    
    private func parseISO8601Date(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
    
    private func parseTags(_ string: String) -> [String] {
        // ["tag1", "tag2"] 형태 파싱
        let cleaned = string
            .replacingOccurrences(of: "[", with: "")
            .replacingOccurrences(of: "]", with: "")
            .replacingOccurrences(of: "\"", with: "")
        
        return cleaned.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
    
    private func parseArray(_ string: String) -> [String] {
        parseTags(string)
    }
}

// MARK: - Errors

enum CommunityError: Error {
    case thoughtNotFound
    case conversationNotFound
    case invalidData
}
