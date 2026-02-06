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
        // 저장 전 직원 수 확인
        let countBefore = coordinator.company.allEmployees.count
        print("➕ [직원 추가] \(employee.name) → 부서 ID: \(departmentId)")
        print("   저장 전 직원 수: \(countBefore)명")

        coordinator.company.addEmployee(employee, toDepartment: departmentId)
        coordinator.employeeStatuses[employee.id] = employee.status
        coordinator.saveCompany()

        // 저장 후 검증
        let countAfter = coordinator.company.allEmployees.count
        if countAfter <= countBefore {
            print("⚠️ [경고] 직원 추가 후 직원 수가 증가하지 않음! \(countBefore) → \(countAfter)")
        } else {
            print("✅ [직원 추가 완료] \(employee.name), 총 직원: \(countAfter)명")
        }

        // 직원이 정상적으로 저장되었는지 확인
        if let savedEmployee = findEmployee(byId: employee.id) {
            print("   ✓ 저장 확인: \(savedEmployee.name)")
        } else {
            print("   ⚠️ 저장 확인 실패: 직원을 찾을 수 없음")
        }

        // 직원 프로필 파일 생성
        if let dept = coordinator.company.departments.first(where: { $0.id == departmentId }) {
            EmployeeWorkLogService.shared.createEmployeeProfile(employee: employee, departmentType: dept.type)
        }
    }

    /// 직원 제거
    func removeEmployee(_ employeeId: UUID) {
        let countBefore = coordinator.company.allEmployees.count
        let employeeName = findEmployee(byId: employeeId)?.name ?? "Unknown"

        print("➖ [직원 제거] \(employeeName) (ID: \(employeeId))")
        print("   제거 전 직원 수: \(countBefore)명")

        coordinator.company.removeEmployee(employeeId)
        coordinator.employeeStatuses.removeValue(forKey: employeeId)
        coordinator.saveCompany()

        let countAfter = coordinator.company.allEmployees.count
        print("✅ [직원 제거 완료] 남은 직원: \(countAfter)명")
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
    func updateEmployeeTokenUsage(
        _ employeeId: UUID,
        inputTokens: Int,
        outputTokens: Int,
        cacheRead: Int = 0,
        cacheCreation: Int = 0,
        costUSD: Double = 0,
        model: String = "unknown"
    ) {
        // 일반 직원에서 찾기
        for deptIndex in coordinator.company.departments.indices {
            if let empIndex = coordinator.company.departments[deptIndex].employees.firstIndex(where: { $0.id == employeeId }) {
                coordinator.company.departments[deptIndex].employees[empIndex].statistics.addTokenUsage(
                    input: inputTokens,
                    output: outputTokens,
                    cacheRead: cacheRead,
                    cacheCreation: cacheCreation,
                    costUSD: costUSD,
                    model: model
                )
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
                    coordinator.company.projects[projectIndex].departments[deptIndex].employees[empIndex].statistics.addTokenUsage(
                        input: inputTokens,
                        output: outputTokens,
                        cacheRead: cacheRead,
                        cacheCreation: cacheCreation,
                        costUSD: costUSD,
                        model: model
                    )
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
