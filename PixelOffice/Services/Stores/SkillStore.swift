import Foundation
import SwiftUI

/// 스킬 관리 스토어
@MainActor
class SkillStore: ObservableObject {
    static let shared = SkillStore()
    
    /// 모든 스킬 (빌트인 + 커스텀)
    @Published var skills: [Skill] = []
    
    /// 즐겨찾기 스킬 ID들
    @Published var favoriteSkillIds: Set<String> = []
    
    /// 로딩 상태
    @Published var isLoading = false
    
    /// 에러 메시지
    @Published var errorMessage: String?
    
    private let fileManager = FileManager.default
    private var skillsDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("PixelOffice/Skills", isDirectory: true)
    }
    
    private var customSkillsFile: URL {
        skillsDirectory.appendingPathComponent("custom_skills.json")
    }
    
    private var favoritesFile: URL {
        skillsDirectory.appendingPathComponent("favorites.json")
    }
    
    // MARK: - Init
    
    init() {
        ensureDirectoryExists()
        loadSkills()
    }
    
    // MARK: - Load/Save
    
    private func ensureDirectoryExists() {
        try? fileManager.createDirectory(at: skillsDirectory, withIntermediateDirectories: true)
    }
    
    func loadSkills() {
        isLoading = true
        defer { isLoading = false }
        
        // 빌트인 스킬 로드
        var allSkills = BuiltInSkills.all
        
        // 커스텀 스킬 로드
        if let data = try? Data(contentsOf: customSkillsFile),
           let customSkills = try? JSONDecoder().decode([Skill].self, from: data) {
            allSkills.append(contentsOf: customSkills)
        }
        
        skills = allSkills
        
        // 즐겨찾기 로드
        if let data = try? Data(contentsOf: favoritesFile),
           let favorites = try? JSONDecoder().decode(Set<String>.self, from: data) {
            favoriteSkillIds = favorites
        }
    }
    
    func saveCustomSkills() {
        let customSkills = skills.filter { $0.isCustom }
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(customSkills)
            try data.write(to: customSkillsFile)
        } catch {
            errorMessage = "스킬 저장 실패: \(error.localizedDescription)"
        }
    }
    
    func saveFavorites() {
        do {
            let data = try JSONEncoder().encode(favoriteSkillIds)
            try data.write(to: favoritesFile)
        } catch {
            errorMessage = "즐겨찾기 저장 실패: \(error.localizedDescription)"
        }
    }
    
    // MARK: - CRUD
    
    /// 커스텀 스킬 추가
    func addSkill(_ skill: Skill) {
        var newSkill = skill
        newSkill.isCustom = true
        newSkill.createdAt = Date()
        newSkill.updatedAt = Date()
        
        skills.append(newSkill)
        saveCustomSkills()
    }
    
    /// 스킬 업데이트
    func updateSkill(_ skill: Skill) {
        guard let index = skills.firstIndex(where: { $0.id == skill.id }) else { return }
        
        var updated = skill
        updated.updatedAt = Date()
        skills[index] = updated
        
        if skill.isCustom {
            saveCustomSkills()
        }
    }
    
    /// 스킬 삭제 (커스텀만 가능)
    func deleteSkill(_ skill: Skill) {
        guard skill.isCustom else { return }
        
        skills.removeAll { $0.id == skill.id }
        favoriteSkillIds.remove(skill.id)
        saveCustomSkills()
        saveFavorites()
    }
    
    /// 스킬 복제
    func duplicateSkill(_ skill: Skill) -> Skill {
        var duplicate = skill
        duplicate.id = "\(skill.id)-copy-\(UUID().uuidString.prefix(8))"
        duplicate.name = "\(skill.name) (복사본)"
        duplicate.isCustom = true
        duplicate.createdAt = Date()
        duplicate.updatedAt = Date()
        
        skills.append(duplicate)
        saveCustomSkills()
        
        return duplicate
    }
    
    // MARK: - Favorites
    
    func toggleFavorite(_ skillId: String) {
        if favoriteSkillIds.contains(skillId) {
            favoriteSkillIds.remove(skillId)
        } else {
            favoriteSkillIds.insert(skillId)
        }
        saveFavorites()
    }
    
    func isFavorite(_ skillId: String) -> Bool {
        favoriteSkillIds.contains(skillId)
    }
    
    // MARK: - Import/Export
    
    /// JSON 파일에서 스킬 가져오기
    func importSkills(from url: URL) throws -> [Skill] {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        
        // 단일 스킬 또는 배열 시도
        if let single = try? decoder.decode(Skill.self, from: data) {
            var imported = single
            imported.isCustom = true
            addSkill(imported)
            return [imported]
        } else if var multiple = try? decoder.decode([Skill].self, from: data) {
            for i in 0..<multiple.count {
                multiple[i].isCustom = true
                addSkill(multiple[i])
            }
            return multiple
        }
        
        throw SkillImportError.invalidFormat
    }
    
    /// 스킬을 JSON으로 내보내기
    func exportSkills(_ skills: [Skill]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(skills)
    }
    
    /// URL에서 스킬 import (원격)
    func importFromURL(_ urlString: String) async throws -> [Skill] {
        guard let url = URL(string: urlString) else {
            throw SkillImportError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoder = JSONDecoder()
        
        if let single = try? decoder.decode(Skill.self, from: data) {
            var imported = single
            imported.isCustom = true
            await MainActor.run { addSkill(imported) }
            return [imported]
        } else if var multiple = try? decoder.decode([Skill].self, from: data) {
            await MainActor.run {
                for i in 0..<multiple.count {
                    multiple[i].isCustom = true
                    addSkill(multiple[i])
                }
            }
            return multiple
        }
        
        throw SkillImportError.invalidFormat
    }
    
    // MARK: - Query
    
    /// 카테고리별 스킬 필터링
    func skills(for category: SkillCategory) -> [Skill] {
        skills.filter { $0.category == category }
    }
    
    /// 검색
    func search(_ query: String) -> [Skill] {
        guard !query.isEmpty else { return skills }
        let lowercased = query.lowercased()
        return skills.filter {
            $0.name.lowercased().contains(lowercased) ||
            $0.description.lowercased().contains(lowercased) ||
            $0.tags.contains { $0.lowercased().contains(lowercased) }
        }
    }
    
    /// 즐겨찾기 스킬
    var favoriteSkills: [Skill] {
        skills.filter { favoriteSkillIds.contains($0.id) }
    }
    
    /// 빌트인 스킬
    var builtInSkills: [Skill] {
        skills.filter { !$0.isCustom }
    }
    
    /// 커스텀 스킬
    var customSkills: [Skill] {
        skills.filter { $0.isCustom }
    }
}

// MARK: - Errors

enum SkillImportError: LocalizedError {
    case invalidFormat
    case invalidURL
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat: return "스킬 파일 형식이 올바르지 않습니다"
        case .invalidURL: return "올바르지 않은 URL입니다"
        case .networkError: return "네트워크 오류가 발생했습니다"
        }
    }
}
