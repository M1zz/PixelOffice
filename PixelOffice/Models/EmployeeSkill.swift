//
//  EmployeeSkill.swift
//  PixelOffice
//
//  Created by Pipeline on 2026-02-15.
//
//  직원 스킬 관리 - 스킬 기반 업무 라우팅
//

import Foundation
import SwiftUI

/// 직원 스킬
struct EmployeeSkill: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String                         // 스킬 이름
    var category: EmployeeSkillCategory      // 카테고리
    var level: SkillLevel                    // 숙련도
    var yearsOfExperience: Double?           // 경력 연수
    var certifications: [String] = []        // 관련 자격증
    var description: String = ""             // 설명
    
    /// 스킬 점수 (라우팅용)
    var score: Int {
        level.score
    }
}

/// 직원 스킬 카테고리 (Skill.swift의 SkillCategory와 구분)
enum EmployeeSkillCategory: String, Codable, CaseIterable {
    // 기획
    case productPlanning = "제품 기획"
    case marketResearch = "시장 조사"
    case userResearch = "사용자 조사"
    case requirements = "요구사항 분석"
    case projectManagement = "프로젝트 관리"
    
    // 디자인
    case uiDesign = "UI 디자인"
    case uxDesign = "UX 디자인"
    case graphicDesign = "그래픽 디자인"
    case prototyping = "프로토타이핑"
    case designSystem = "디자인 시스템"
    
    // 개발
    case ios = "iOS 개발"
    case android = "Android 개발"
    case web = "웹 개발"
    case backend = "백엔드 개발"
    case database = "데이터베이스"
    case devops = "DevOps"
    case macOS = "macOS 개발"
    
    // QA
    case manualTesting = "수동 테스트"
    case automationTesting = "자동화 테스트"
    case performanceTesting = "성능 테스트"
    case securityTesting = "보안 테스트"
    
    // 마케팅
    case contentMarketing = "콘텐츠 마케팅"
    case socialMedia = "소셜 미디어"
    case seo = "SEO"
    case analytics = "분석"
    
    // 공통
    case communication = "커뮤니케이션"
    case documentation = "문서화"
    case leadership = "리더십"
    
    var icon: String {
        switch self {
        case .productPlanning, .requirements, .projectManagement: return "doc.text"
        case .marketResearch, .userResearch: return "magnifyingglass"
        case .uiDesign, .uxDesign, .graphicDesign: return "paintbrush"
        case .prototyping, .designSystem: return "square.stack.3d.up"
        case .ios, .macOS: return "apple.logo"
        case .android: return "antenna.radiowaves.left.and.right"
        case .web: return "globe"
        case .backend, .database: return "server.rack"
        case .devops: return "gearshape.2"
        case .manualTesting, .automationTesting: return "checkmark.shield"
        case .performanceTesting: return "speedometer"
        case .securityTesting: return "lock.shield"
        case .contentMarketing, .socialMedia: return "bubble.left.and.bubble.right"
        case .seo, .analytics: return "chart.bar"
        case .communication: return "person.wave.2"
        case .documentation: return "doc.richtext"
        case .leadership: return "star"
        }
    }
    
    var color: Color {
        switch self {
        case .productPlanning, .marketResearch, .userResearch, .requirements, .projectManagement:
            return .blue
        case .uiDesign, .uxDesign, .graphicDesign, .prototyping, .designSystem:
            return .purple
        case .ios, .android, .web, .backend, .database, .devops, .macOS:
            return .green
        case .manualTesting, .automationTesting, .performanceTesting, .securityTesting:
            return .orange
        case .contentMarketing, .socialMedia, .seo, .analytics:
            return .pink
        case .communication, .documentation, .leadership:
            return .gray
        }
    }
    
    /// 해당 부서와 관련된 스킬 카테고리들
    static func categories(for department: DepartmentType) -> [EmployeeSkillCategory] {
        switch department {
        case .planning:
            return [.productPlanning, .marketResearch, .userResearch, .requirements, .projectManagement]
        case .design:
            return [.uiDesign, .uxDesign, .graphicDesign, .prototyping, .designSystem]
        case .development:
            return [.ios, .macOS, .android, .web, .backend, .database, .devops]
        case .qa:
            return [.manualTesting, .automationTesting, .performanceTesting, .securityTesting]
        case .marketing:
            return [.contentMarketing, .socialMedia, .seo, .analytics]
        case .general:
            return [.communication, .documentation, .leadership]
        }
    }
}

/// 스킬 숙련도
enum SkillLevel: String, Codable, CaseIterable {
    case beginner = "입문"
    case intermediate = "중급"
    case advanced = "고급"
    case expert = "전문가"
    case master = "마스터"
    
    var score: Int {
        switch self {
        case .beginner: return 1
        case .intermediate: return 2
        case .advanced: return 3
        case .expert: return 4
        case .master: return 5
        }
    }
    
    var color: Color {
        switch self {
        case .beginner: return .gray
        case .intermediate: return .blue
        case .advanced: return .green
        case .expert: return .orange
        case .master: return .purple
        }
    }
    
    var stars: String {
        String(repeating: "★", count: score) + String(repeating: "☆", count: 5 - score)
    }
}

// MARK: - Skill Matching

/// 스킬 매칭 서비스
class SkillMatchingService {
    static let shared = SkillMatchingService()
    
    private init() {}
    
    /// 태스크에 가장 적합한 직원 찾기
    func findBestEmployee(
        for task: ProjectTask,
        in project: Project,
        requiredSkills: [EmployeeSkillCategory] = []
    ) -> ProjectEmployee? {
        let candidates = project.allEmployees.filter { $0.departmentType == task.departmentType }
        
        if requiredSkills.isEmpty {
            // 스킬 요구사항 없으면 첫 번째 직원 반환
            return candidates.first
        }
        
        // 스킬 점수로 정렬
        let scored = candidates.map { employee -> (ProjectEmployee, Int) in
            let score = calculateSkillScore(employee: employee, requiredSkills: requiredSkills)
            return (employee, score)
        }.sorted { $0.1 > $1.1 }
        
        return scored.first?.0
    }
    
    /// 직원의 스킬 점수 계산
    func calculateSkillScore(employee: ProjectEmployee, requiredSkills: [EmployeeSkillCategory]) -> Int {
        var totalScore = 0
        
        for required in requiredSkills {
            if let skill = employee.skills.first(where: { $0.category == required }) {
                totalScore += skill.score
            }
        }
        
        return totalScore
    }
    
    /// 특정 스킬을 가진 직원들 찾기
    func findEmployeesWithSkill(
        category: EmployeeSkillCategory,
        minLevel: SkillLevel = .beginner,
        in project: Project
    ) -> [ProjectEmployee] {
        project.allEmployees.filter { employee in
            employee.skills.contains { skill in
                skill.category == category && skill.level.score >= minLevel.score
            }
        }
    }
    
    /// 부서 간 핸드오프 시 다음 담당자 추천
    func recommendNextAssignee(
        currentTask: ProjectTask,
        nextDepartment: DepartmentType,
        project: Project
    ) -> ProjectEmployee? {
        let candidates = project.allEmployees.filter { $0.departmentType == nextDepartment }
        
        // 업무량이 적은 직원 우선 (간단히 구현)
        // 실제로는 현재 진행 중인 태스크 수 등을 고려
        return candidates.first
    }
}
