import Foundation
import SwiftUI

/// 프로젝트 CRUD, 태스크 관리, 프로젝트 직원 관리, 워크플로우 담당 도메인 Store
@MainActor
final class ProjectStore {

    // MARK: - Properties

    unowned let coordinator: StoreCoordinator

    // MARK: - Init

    init(coordinator: StoreCoordinator) {
        self.coordinator = coordinator
    }

    // MARK: - 프로젝트 CRUD

    /// 프로젝트 추가 (디렉토리 구조 자동 생성)
    func addProject(_ project: Project) {
        coordinator.company.addProject(project)
        // 프로젝트 디렉토리 구조 생성
        DataPathService.shared.createProjectDirectories(projectName: project.name)
    }

    /// 프로젝트 제거
    func removeProject(_ projectId: UUID) {
        // 삭제 전에 프로젝트 이름 저장
        if let project = coordinator.company.projects.first(where: { $0.id == projectId }) {
            ProjectRecoveryService.shared.markAsDeleted(projectName: project.name)
        }
        coordinator.company.removeProject(projectId)
    }

    /// 프로젝트 조회
    func getProject(byId id: UUID) -> Project? {
        coordinator.company.projects.first { $0.id == id }
    }

    /// 프로젝트 업데이트
    func updateProject(_ project: Project) {
        if let index = coordinator.company.projects.firstIndex(where: { $0.id == project.id }) {
            coordinator.company.projects[index] = project
        }
    }

    // MARK: - 태스크 Operations

    /// 태스크 추가
    func addTask(_ task: ProjectTask, toProject projectId: UUID) {
        if let index = coordinator.company.projects.firstIndex(where: { $0.id == projectId }) {
            coordinator.company.projects[index].addTask(task)
        }
    }

    /// 태스크 제거
    func removeTask(_ taskId: UUID, fromProject projectId: UUID) {
        if let index = coordinator.company.projects.firstIndex(where: { $0.id == projectId }) {
            coordinator.company.projects[index].removeTask(taskId)
        }
    }

    /// 태스크 업데이트
    func updateTask(_ task: ProjectTask, inProject projectId: UUID) {
        if let index = coordinator.company.projects.firstIndex(where: { $0.id == projectId }) {
            coordinator.company.projects[index].updateTask(task)
        }
    }

    /// 태스크에 메시지 추가
    func addMessageToTask(message: Message, taskId: UUID, projectId: UUID) {
        if let projectIndex = coordinator.company.projects.firstIndex(where: { $0.id == projectId }),
           let taskIndex = coordinator.company.projects[projectIndex].tasks.firstIndex(where: { $0.id == taskId }) {
            coordinator.company.projects[projectIndex].tasks[taskIndex].addMessage(message)
        }
    }

    /// 태스크에 출력 추가
    func addOutputToTask(output: TaskOutput, taskId: UUID, projectId: UUID) {
        if let projectIndex = coordinator.company.projects.firstIndex(where: { $0.id == projectId }),
           let taskIndex = coordinator.company.projects[projectIndex].tasks.firstIndex(where: { $0.id == taskId }) {
            coordinator.company.projects[projectIndex].tasks[taskIndex].addOutput(output)
        }
    }

    /// 태스크에 직원 할당
    func assignTaskToEmployee(taskId: UUID, employeeId: UUID, projectId: UUID) {
        guard var project = coordinator.company.projects.first(where: { $0.id == projectId }),
              var task = project.tasks.first(where: { $0.id == taskId }) else { return }

        task.assign(to: employeeId)
        project.updateTask(task)

        if let index = coordinator.company.projects.firstIndex(where: { $0.id == projectId }) {
            coordinator.company.projects[index] = project
        }
    }

    /// 태스크 시작 (직원 상태 업데이트 포함)
    func startTask(taskId: UUID, projectId: UUID) {
        guard var project = coordinator.company.projects.first(where: { $0.id == projectId }),
              var task = project.tasks.first(where: { $0.id == taskId }) else { return }

        task.start()
        project.updateTask(task)

        if let index = coordinator.company.projects.firstIndex(where: { $0.id == projectId }) {
            coordinator.company.projects[index] = project
        }

        // 직원 상태 업데이트
        if let employeeId = task.assigneeId {
            coordinator.employeeStatuses[employeeId] = .working
            coordinator.company.updateEmployeeStatus(employeeId, status: .working)

            // 직원의 현재 태스크 설정
            for i in coordinator.company.departments.indices {
                if let j = coordinator.company.departments[i].employees.firstIndex(where: { $0.id == employeeId }) {
                    coordinator.company.departments[i].employees[j].currentTaskId = taskId
                }
            }
        }
    }

    /// 태스크 완료 (직원 상태 업데이트 포함)
    func completeTask(taskId: UUID, projectId: UUID) {
        guard var project = coordinator.company.projects.first(where: { $0.id == projectId }),
              var task = project.tasks.first(where: { $0.id == taskId }) else { return }

        let employeeId = task.assigneeId

        task.complete()
        project.updateTask(task)

        if let index = coordinator.company.projects.firstIndex(where: { $0.id == projectId }) {
            coordinator.company.projects[index] = project
        }

        // 직원 상태 업데이트
        if let employeeId = employeeId {
            coordinator.employeeStatuses[employeeId] = .idle
            coordinator.company.updateEmployeeStatus(employeeId, status: .idle)

            // 직원의 현재 태스크 해제 및 완료 수 증가
            for i in coordinator.company.departments.indices {
                if let j = coordinator.company.departments[i].employees.firstIndex(where: { $0.id == employeeId }) {
                    coordinator.company.departments[i].employees[j].currentTaskId = nil
                    coordinator.company.departments[i].employees[j].totalTasksCompleted += 1
                }
            }
        }
    }

    // MARK: - 워크플로우

    /// 태스크를 다음 부서로 이동
    func moveTaskToDepartment(taskId: UUID, projectId: UUID, toDepartment: DepartmentType, note: String = "") {
        if let projectIndex = coordinator.company.projects.firstIndex(where: { $0.id == projectId }),
           let taskIndex = coordinator.company.projects[projectIndex].tasks.firstIndex(where: { $0.id == taskId }) {
            coordinator.company.projects[projectIndex].tasks[taskIndex].moveToDepartment(toDepartment, note: note)
        }
    }

    /// 특정 부서의 대기 중인 태스크들 조회
    func getPendingTasks(for departmentType: DepartmentType) -> [(task: ProjectTask, projectId: UUID)] {
        var result: [(task: ProjectTask, projectId: UUID)] = []
        for project in coordinator.company.projects {
            let tasks = project.tasks.filter { $0.departmentType == departmentType && $0.status == .todo }
            result.append(contentsOf: tasks.map { (task: $0, projectId: project.id) })
        }
        return result
    }

    /// 워크플로우 순서대로 정렬된 부서들
    var departmentsByWorkflowOrder: [Department] {
        coordinator.company.departments.sorted { $0.type.workflowOrder < $1.type.workflowOrder }
    }

    // MARK: - 프로젝트 직원 관리

    /// 프로젝트에 직원 추가
    func addProjectEmployee(_ employee: ProjectEmployee, toProject projectId: UUID, department: DepartmentType) {
        if let index = coordinator.company.projects.firstIndex(where: { $0.id == projectId }) {
            coordinator.company.projects[index].addEmployee(employee, toDepartment: department)
            coordinator.employeeStatuses[employee.id] = employee.status
            coordinator.saveCompany()

            // 프로젝트 직원 프로필 파일 생성
            let projectName = coordinator.company.projects[index].name
            EmployeeWorkLogService.shared.createProjectEmployeeProfile(employee: employee, projectName: projectName)
        }
    }

    /// 프로젝트에서 직원 제거
    func removeProjectEmployee(_ employeeId: UUID, fromProject projectId: UUID) {
        if let index = coordinator.company.projects.firstIndex(where: { $0.id == projectId }) {
            coordinator.company.projects[index].removeEmployee(employeeId)
            coordinator.saveCompany()
        }
    }

    /// 프로젝트 내 직원 찾기
    func getProjectEmployee(byId employeeId: UUID, inProject projectId: UUID) -> ProjectEmployee? {
        guard let project = coordinator.company.projects.first(where: { $0.id == projectId }) else { return nil }
        return project.getEmployee(byId: employeeId)
    }

    /// 프로젝트 직원 상태 업데이트 (토스트 알림 포함)
    func updateProjectEmployeeStatus(_ employeeId: UUID, inProject projectId: UUID, status: EmployeeStatus) {
        let previousStatus = coordinator.employeeStatuses[employeeId]

        // 상태가 변경된 경우에만 처리
        guard previousStatus != status else { return }

        // 중앙 저장소 업데이트
        coordinator.employeeStatuses[employeeId] = status

        // 데이터 모델도 동기화
        guard let projectIndex = coordinator.company.projects.firstIndex(where: { $0.id == projectId }) else { return }
        for deptIndex in coordinator.company.projects[projectIndex].departments.indices {
            if let empIndex = coordinator.company.projects[projectIndex].departments[deptIndex].employees.firstIndex(where: { $0.id == employeeId }) {
                coordinator.company.projects[projectIndex].departments[deptIndex].employees[empIndex].status = status
                break
            }
        }

        // @Published 트리거 (UI 전체 업데이트)
        let updatedCompany = coordinator.company
        coordinator.company = updatedCompany

        // 직원 이름 찾기 (프로젝트 내에서 검색)
        let employeeName = findProjectEmployeeName(byId: employeeId)

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

    /// 프로젝트 직원 대화 기록 업데이트
    func updateProjectEmployeeConversation(projectId: UUID, employeeId: UUID, messages: [Message]) {
        guard let projectIndex = coordinator.company.projects.firstIndex(where: { $0.id == projectId }) else { return }
        for deptIndex in coordinator.company.projects[projectIndex].departments.indices {
            if let empIndex = coordinator.company.projects[projectIndex].departments[deptIndex].employees.firstIndex(where: { $0.id == employeeId }) {
                coordinator.company.projects[projectIndex].departments[deptIndex].employees[empIndex].conversationHistory = messages
                coordinator.saveCompany()
                break
            }
        }
    }

    /// 프로젝트 직원 수
    func getProjectEmployeeCount(_ projectId: UUID) -> Int {
        guard let project = coordinator.company.projects.first(where: { $0.id == projectId }) else { return 0 }
        return project.allEmployees.count
    }

    /// 프로젝트 내 작업 중인 직원 수
    func getProjectWorkingEmployeesCount(_ projectId: UUID) -> Int {
        guard let project = coordinator.company.projects.first(where: { $0.id == projectId }) else { return 0 }
        return project.workingEmployees.count
    }

    // MARK: - 프로젝트 디렉토리 관리

    /// 기존 프로젝트들의 디렉토리 구조 생성 (README 포함)
    func ensureProjectDirectoriesExist() {
        for project in coordinator.company.projects {
            DataPathService.shared.createProjectDirectories(projectName: project.name)
        }
    }

    // MARK: - Private Helpers

    /// 직원 이름 찾기 (일반 직원 + 프로젝트 직원)
    private func findProjectEmployeeName(byId employeeId: UUID) -> String {
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
}
