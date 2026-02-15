import Foundation

/// 스킬 등록/조회를 관리하는 레지스트리
class SkillRegistry: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = SkillRegistry()
    
    // MARK: - Published Properties
    
    @Published private(set) var skills: [String: Skill] = [:]
    @Published private(set) var customSkills: [String: Skill] = [:]
    
    // MARK: - Private Properties
    
    private let customSkillsPath: String
    
    // MARK: - Init
    
    private init() {
        // 커스텀 스킬 경로 설정
        let basePath = DataPathService.shared.basePath
        self.customSkillsPath = "\(basePath)/_shared/skills"
        
        // 기본 스킬 등록
        registerBuiltInSkills()
        
        // 커스텀 스킬 로드
        loadCustomSkills()
    }
    
    // MARK: - Public Methods
    
    /// 스킬 조회
    func getSkill(_ id: String) -> Skill? {
        skills[id] ?? customSkills[id]
    }
    
    /// 모든 스킬 조회
    func getAllSkills() -> [Skill] {
        Array(skills.values) + Array(customSkills.values)
    }
    
    /// 카테고리별 스킬 조회
    func getSkills(byCategory category: SkillCategory) -> [Skill] {
        getAllSkills().filter { $0.category == category }
    }
    
    /// 태그로 스킬 검색
    func searchSkills(byTag tag: String) -> [Skill] {
        getAllSkills().filter { $0.tags.contains(tag.lowercased()) }
    }
    
    /// 키워드로 스킬 검색
    func searchSkills(keyword: String) -> [Skill] {
        let lowercased = keyword.lowercased()
        return getAllSkills().filter {
            $0.name.lowercased().contains(lowercased) ||
            $0.description.lowercased().contains(lowercased) ||
            $0.tags.contains { $0.contains(lowercased) }
        }
    }
    
    /// 커스텀 스킬 등록
    func registerCustomSkill(_ skill: Skill) {
        var mutableSkill = skill
        mutableSkill.isCustom = true
        mutableSkill.updatedAt = Date()
        customSkills[skill.id] = mutableSkill
        
        // 파일로 저장
        saveCustomSkill(mutableSkill)
        
        print("[SkillRegistry] 커스텀 스킬 등록됨: \(skill.id)")
    }
    
    /// 커스텀 스킬 삭제
    func removeCustomSkill(_ id: String) {
        customSkills.removeValue(forKey: id)
        
        // 파일 삭제
        let filePath = "\(customSkillsPath)/\(id).json"
        try? FileManager.default.removeItem(atPath: filePath)
        
        print("[SkillRegistry] 커스텀 스킬 삭제됨: \(id)")
    }
    
    /// 커스텀 스킬 새로고침
    func reloadCustomSkills() {
        customSkills.removeAll()
        loadCustomSkills()
    }
    
    /// 스킬 존재 여부 확인
    func hasSkill(_ id: String) -> Bool {
        skills[id] != nil || customSkills[id] != nil
    }
    
    // MARK: - Private Methods
    
    /// 기본 스킬 등록
    private func registerBuiltInSkills() {
        for skill in BuiltInSkills.all {
            skills[skill.id] = skill
        }
        print("[SkillRegistry] 기본 스킬 \(skills.count)개 등록됨")
    }
    
    /// 커스텀 스킬 로드
    private func loadCustomSkills() {
        let fileManager = FileManager.default
        
        // 디렉토리가 없으면 생성
        if !fileManager.fileExists(atPath: customSkillsPath) {
            try? fileManager.createDirectory(atPath: customSkillsPath, withIntermediateDirectories: true)
            print("[SkillRegistry] 커스텀 스킬 디렉토리 생성됨: \(customSkillsPath)")
            return
        }
        
        // JSON 파일들 읽기
        guard let files = try? fileManager.contentsOfDirectory(atPath: customSkillsPath) else {
            return
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        for file in files where file.hasSuffix(".json") {
            let filePath = "\(customSkillsPath)/\(file)"
            
            if let data = fileManager.contents(atPath: filePath),
               let skill = try? decoder.decode(Skill.self, from: data) {
                customSkills[skill.id] = skill
                print("[SkillRegistry] 커스텀 스킬 로드됨: \(skill.id)")
            }
        }
        
        // 마크다운 파일도 지원
        for file in files where file.hasSuffix(".md") {
            let filePath = "\(customSkillsPath)/\(file)"
            
            if let content = try? String(contentsOfFile: filePath, encoding: .utf8),
               let skill = parseSkillFromMarkdown(content, filename: file) {
                customSkills[skill.id] = skill
                print("[SkillRegistry] 커스텀 스킬 로드됨 (MD): \(skill.id)")
            }
        }
        
        print("[SkillRegistry] 커스텀 스킬 \(customSkills.count)개 로드됨")
    }
    
    /// 커스텀 스킬 저장
    private func saveCustomSkill(_ skill: Skill) {
        let fileManager = FileManager.default
        
        // 디렉토리가 없으면 생성
        if !fileManager.fileExists(atPath: customSkillsPath) {
            try? fileManager.createDirectory(atPath: customSkillsPath, withIntermediateDirectories: true)
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        if let data = try? encoder.encode(skill) {
            let filePath = "\(customSkillsPath)/\(skill.id).json"
            fileManager.createFile(atPath: filePath, contents: data)
            print("[SkillRegistry] 커스텀 스킬 저장됨: \(filePath)")
        }
    }
    
    /// 마크다운에서 스킬 파싱
    private func parseSkillFromMarkdown(_ content: String, filename: String) -> Skill? {
        let lines = content.components(separatedBy: "\n")
        
        var id = filename.replacingOccurrences(of: ".md", with: "")
        var name = id
        var description = ""
        var categoryStr = "custom"
        var promptTemplate = ""
        var systemPrompt: String?
        var tags: [String] = []
        
        var currentSection = ""
        var sectionContent = ""
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // 헤더 파싱
            if trimmed.hasPrefix("# ") {
                name = String(trimmed.dropFirst(2))
            } else if trimmed.hasPrefix("## ") {
                // 이전 섹션 저장
                saveSection(currentSection, content: sectionContent, 
                           id: &id, description: &description, categoryStr: &categoryStr,
                           promptTemplate: &promptTemplate, systemPrompt: &systemPrompt, tags: &tags)
                
                currentSection = String(trimmed.dropFirst(3)).lowercased()
                sectionContent = ""
            } else if !currentSection.isEmpty {
                sectionContent += line + "\n"
            }
        }
        
        // 마지막 섹션 저장
        saveSection(currentSection, content: sectionContent,
                   id: &id, description: &description, categoryStr: &categoryStr,
                   promptTemplate: &promptTemplate, systemPrompt: &systemPrompt, tags: &tags)
        
        // 필수 필드 확인
        guard !promptTemplate.isEmpty else {
            print("[SkillRegistry] 프롬프트 템플릿 없음, 스킬 무시: \(filename)")
            return nil
        }
        
        let category = SkillCategory(rawValue: categoryStr) ?? .custom
        
        return Skill(
            id: id,
            name: name,
            description: description,
            category: category,
            promptTemplate: promptTemplate.trimmingCharacters(in: .whitespacesAndNewlines),
            systemPrompt: systemPrompt?.trimmingCharacters(in: .whitespacesAndNewlines),
            tags: tags,
            isCustom: true
        )
    }
    
    /// 섹션 내용 저장 헬퍼
    private func saveSection(
        _ section: String,
        content: String,
        id: inout String,
        description: inout String,
        categoryStr: inout String,
        promptTemplate: inout String,
        systemPrompt: inout String?,
        tags: inout [String]
    ) {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch section {
        case "id":
            id = trimmedContent
        case "description", "설명":
            description = trimmedContent
        case "category", "카테고리":
            categoryStr = trimmedContent.lowercased()
        case "prompt", "프롬프트", "prompt template":
            promptTemplate = trimmedContent
        case "system prompt", "시스템 프롬프트":
            systemPrompt = trimmedContent
        case "tags", "태그":
            tags = trimmedContent
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
                .filter { !$0.isEmpty }
        default:
            break
        }
    }
}

// MARK: - Employee + Skills

extension ProjectEmployee {
    /// 직원에게 장착된 스킬 ID들
    var equippedSkillIds: [String] {
        // 부서 기반 기본 스킬
        var skillIds: [String] = []
        
        switch departmentType {
        case .development:
            skillIds = ["code-analysis", "refactor", "doc-gen"]
        case .design:
            skillIds = ["design-to-html"]
        case .qa:
            skillIds = ["test-gen", "code-analysis"]
        case .planning:
            skillIds = ["doc-gen"]
        case .marketing:
            skillIds = ["doc-gen"]
        case .general:
            skillIds = ["code-analysis"]
        }
        
        return skillIds
    }
    
    /// 장착된 스킬 목록
    var equippedSkills: [Skill] {
        equippedSkillIds.compactMap { SkillRegistry.shared.getSkill($0) }
    }
}
