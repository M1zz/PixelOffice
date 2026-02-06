import Foundation
import SwiftUI

/// 직원 CRUD, 상태 관리, 온보딩 담당 도메인 Store
@MainActor
final class EmployeeStore {

    // MARK: - Properties

    unowned let coordinator: StoreCoordinator

    // MARK: - Init

    init(coordinator: StoreCoordinator) {
        self.coordinator = coordinator
    }

    // MARK: - 직원 상태 관리

    /// 직원 상태 조회 (중앙 저장소 우선)
    func getEmployeeStatus(_ employeeId: UUID) -> EmployeeStatus {
        return coordinator.employeeStatuses[employeeId] ?? .idle
    }

    /// 기존 직원들의 상태를 중앙 저장소에 로드
    func loadEmployeeStatuses() {
        let company = coordinator.company

        // 일반 직원
        for dept in company.departments {
            for emp in dept.employees {
                coordinator.employeeStatuses[emp.id] = emp.status
            }
        }
        // 프로젝트 직원
        for project in company.projects {
            for dept in project.departments {
                for emp in dept.employees {
                    coordinator.employeeStatuses[emp.id] = emp.status
                }
            }
        }
    }

    // MARK: - 직원 CRUD

    /// 직원 추가
    func addEmployee(_ employee: Employee, toDepartment departmentId: UUID) {
        // 🐛 디버그: 저장 전 직원 외모 확인
        print("💾 [EmployeeStore] 저장 전 직원 \(employee.name)의 외모:")
        print("   피부색: \(employee.characterAppearance.skinTone)")
        print("   헤어스타일: \(employee.characterAppearance.hairStyle)")
        print("   헤어색: \(employee.characterAppearance.hairColor)")
        print("   셔츠색: \(employee.characterAppearance.shirtColor)")
        print("   악세서리: \(employee.characterAppearance.accessory)")
        print("   표정: \(employee.characterAppearance.expression)")

        coordinator.company.addEmployee(employee, toDepartment: departmentId)
        coordinator.employeeStatuses[employee.id] = employee.status
        coordinator.saveCompany()

        // 🐛 디버그: 저장 후 확인
        if let savedEmployee = findEmployee(byId: employee.id) {
            print("✅ [EmployeeStore] 저장 후 직원 \(savedEmployee.name)의 외모:")
            print("   피부색: \(savedEmployee.characterAppearance.skinTone)")
            print("   헤어스타일: \(savedEmployee.characterAppearance.hairStyle)")
            print("   헤어색: \(savedEmployee.characterAppearance.hairColor)")
            print("   셔츠색: \(savedEmployee.characterAppearance.shirtColor)")
            print("   악세서리: \(savedEmployee.characterAppearance.accessory)")
            print("   표정: \(savedEmployee.characterAppearance.expression)")
        }

        // 직원 프로필 파일 생성
        if let dept = coordinator.company.departments.first(where: { $0.id == departmentId }) {
            EmployeeWorkLogService.shared.createEmployeeProfile(employee: employee, departmentType: dept.type)
        }
    }

    /// 직원 제거
    func removeEmployee(_ employeeId: UUID) {
        coordinator.company.removeEmployee(employeeId)
        coordinator.saveCompany()
    }

    /// 일반 직원 검색 (부서 순회)
    func findEmployee(byId employeeId: UUID) -> Employee? {
        for dept in coordinator.company.departments {
            if let employee = dept.employees.first(where: { $0.id == employeeId }) {
                return employee
            }
        }
        return nil
    }

    /// 직원 조회 (Company 모델 위임)
    func getEmployee(byId id: UUID) -> Employee? {
        coordinator.company.getEmployee(byId: id)
    }

    /// 직원 이름 찾기 (일반 직원 + 프로젝트 직원)
    func findEmployeeName(byId employeeId: UUID) -> String {
        let company = coordinator.company

        // 일반 직원에서 찾기
        for dept in company.departments {
            if let emp = dept.employees.first(where: { $0.id == employeeId }) {
                return emp.name
            }
        }
        // 프로젝트 직원에서 찾기
        for project in company.projects {
            for dept in project.departments {
                if let emp = dept.employees.first(where: { $0.id == employeeId }) {
                    return emp.name
                }
            }
        }
        return "직원"
    }

    // MARK: - 직원 상태 업데이트

    /// 직원 상태 업데이트 (토스트 알림 포함)
    func updateEmployeeStatus(_ employeeId: UUID, status: EmployeeStatus) {
        let previousStatus = coordinator.employeeStatuses[employeeId]

        // 상태가 변경된 경우에만 처리
        guard previousStatus != status else { return }

        // 중앙 저장소 업데이트
        coordinator.employeeStatuses[employeeId] = status

        // 데이터 모델도 동기화
        coordinator.company.updateEmployeeStatus(employeeId, status: status)

        // @Published 트리거 (UI 전체 업데이트)
        let updatedCompany = coordinator.company
        coordinator.company = updatedCompany

        // 직원 이름 찾기
        let employeeName = findEmployeeName(byId: employeeId)

        // 토스트 알림
        let toastType: ToastType = status == .thinking ? .info : (status == .idle ? .success : .info)
        ToastManager.shared.show(
            title: "\(employeeName) 상태 변경",
            message: "\(previousStatus?.rawValue ?? "알 수 없음") → \(status.rawValue)",
            type: toastType
        )

        // 시스템 알림 (앱이 백그라운드일 때 유용)
        ToastManager.shared.sendNotification(
            title: "\(employeeName) 상태 변경",
            body: "\(status.rawValue)"
        )
    }

    /// 직원 토큰 사용량 업데이트
    func updateEmployeeTokenUsage(_ employeeId: UUID, inputTokens: Int, outputTokens: Int) {
        // 일반 직원에서 찾기
        for deptIndex in coordinator.company.departments.indices {
            if let empIndex = coordinator.company.departments[deptIndex].employees.firstIndex(where: { $0.id == employeeId }) {
                coordinator.company.departments[deptIndex].employees[empIndex].statistics.addTokenUsage(input: inputTokens, output: outputTokens)
                coordinator.company.departments[deptIndex].employees[empIndex].statistics.conversationCount += 1
                coordinator.company.departments[deptIndex].employees[empIndex].statistics.lastActiveDate = Date()
                coordinator.triggerObjectUpdate()
                return
            }
        }

        // 프로젝트 직원에서 찾기
        for projectIndex in coordinator.company.projects.indices {
            for deptIndex in coordinator.company.projects[projectIndex].departments.indices {
                if let empIndex = coordinator.company.projects[projectIndex].departments[deptIndex].employees.firstIndex(where: { $0.id == employeeId }) {
                    coordinator.company.projects[projectIndex].departments[deptIndex].employees[empIndex].statistics.addTokenUsage(input: inputTokens, output: outputTokens)
                    coordinator.company.projects[projectIndex].departments[deptIndex].employees[empIndex].statistics.conversationCount += 1
                    coordinator.company.projects[projectIndex].departments[deptIndex].employees[empIndex].statistics.lastActiveDate = Date()
                    coordinator.triggerObjectUpdate()
                    return
                }
            }
        }
    }

    // MARK: - 직원 프로필 관리

    /// 기존 직원들의 프로필 파일 생성 및 대화 기록 동기화
    func ensureEmployeeProfilesExist() {
        let fileManager = FileManager.default
        let company = coordinator.company

        // 일반 직원
        for dept in company.departments {
            for emp in dept.employees {
                let filePath = EmployeeWorkLogService.shared.getWorkLogFilePath(for: emp.id, employeeName: emp.name)
                if !fileManager.fileExists(atPath: filePath) {
                    EmployeeWorkLogService.shared.createEmployeeProfile(employee: emp, departmentType: dept.type)
                }
                // 대화 기록이 있으면 동기화
                if !emp.conversationHistory.isEmpty {
                    EmployeeWorkLogService.shared.syncEmployeeConversations(employee: emp, departmentType: dept.type)
                }
            }
        }

        // 프로젝트 직원
        for project in company.projects {
            for dept in project.departments {
                for emp in dept.employees {
                    let filePath = EmployeeWorkLogService.shared.getProjectWorkLogFilePath(
                        projectName: project.name,
                        department: dept.type,
                        employeeName: emp.name
                    )
                    if !fileManager.fileExists(atPath: filePath) {
                        EmployeeWorkLogService.shared.createProjectEmployeeProfile(employee: emp, projectName: project.name)
                    }
                    // 대화 기록이 있으면 동기화
                    if !emp.conversationHistory.isEmpty {
                        EmployeeWorkLogService.shared.syncProjectEmployeeConversations(employee: emp, projectName: project.name)
                    }
                }
            }
        }
    }

    // MARK: - 온보딩

    /// 온보딩 추가
    func addOnboarding(_ onboarding: EmployeeOnboarding) {
        coordinator.company.employeeOnboardings.append(onboarding)
    }

    /// 온보딩 업데이트
    func updateOnboarding(_ onboarding: EmployeeOnboarding) {
        if let index = coordinator.company.employeeOnboardings.firstIndex(where: { $0.id == onboarding.id }) {
            coordinator.company.employeeOnboardings[index] = onboarding
        }
    }

    /// 직원 온보딩 조회
    func getOnboarding(for employeeId: UUID) -> EmployeeOnboarding? {
        coordinator.company.employeeOnboardings.first { $0.employeeId == employeeId }
    }

    /// 온보딩 완료
    func completeOnboarding(employeeId: UUID, questions: [OnboardingQuestion]) {
        if let index = coordinator.company.employeeOnboardings.firstIndex(where: { $0.employeeId == employeeId }) {
            coordinator.company.employeeOnboardings[index].questions = questions
            coordinator.company.employeeOnboardings[index].isCompleted = true
            coordinator.company.employeeOnboardings[index].completedAt = Date()
        }
    }
}
