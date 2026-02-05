import Foundation

/// API 설정 및 부서 스킬 관리 담당 도메인 Store
@MainActor
final class SettingsStore {

    // MARK: - Properties

    unowned let coordinator: StoreCoordinator

    // MARK: - Init

    init(coordinator: StoreCoordinator) {
        self.coordinator = coordinator
    }

    // MARK: - 설정 관리

    /// 설정 업데이트
    func updateSettings(_ settings: CompanySettings) {
        coordinator.company.settings = settings
    }

    /// API 설정 추가
    func addAPIConfiguration(_ config: APIConfiguration) {
        coordinator.company.settings.apiConfigurations.append(config)
    }

    /// API 설정 제거
    func removeAPIConfiguration(_ configId: UUID) {
        coordinator.company.settings.apiConfigurations.removeAll { $0.id == configId }
    }

    /// API 설정 업데이트
    func updateAPIConfiguration(_ config: APIConfiguration) {
        if let index = coordinator.company.settings.apiConfigurations.firstIndex(where: { $0.id == config.id }) {
            coordinator.company.settings.apiConfigurations[index] = config
        }
    }

    /// 특정 AI 타입의 API 설정 조회
    func getAPIConfiguration(for aiType: AIType) -> APIConfiguration? {
        coordinator.company.settings.apiConfigurations.first { $0.type == aiType && $0.isEnabled }
    }

    // MARK: - 부서 스킬 관리

    /// 부서 스킬 조회
    func getDepartmentSkills(for department: DepartmentType) -> DepartmentSkillSet {
        return coordinator.company.settings.departmentSkills.getSkills(for: department)
    }

    /// 부서 스킬 업데이트
    func updateDepartmentSkills(for department: DepartmentType, skills: DepartmentSkillSet) {
        coordinator.company.settings.departmentSkills.updateSkills(for: department, skills: skills)
        coordinator.saveCompany()
    }

    /// 부서 스킬 초기화
    func resetDepartmentSkills(for department: DepartmentType) {
        let defaultSkills = DepartmentSkillSet.defaultSkills(for: department)
        coordinator.company.settings.departmentSkills.updateSkills(for: department, skills: defaultSkills)
        coordinator.saveCompany()
    }

    /// 부서 스킬로부터 시스템 프롬프트 생성
    func getSystemPrompt(for department: DepartmentType) -> String {
        return getDepartmentSkills(for: department).fullPrompt
    }
}
