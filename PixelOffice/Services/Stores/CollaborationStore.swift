import Foundation

/// 협업 기록 관리 담당 도메인 Store
@MainActor
final class CollaborationStore {

    // MARK: - Properties

    unowned let coordinator: StoreCoordinator

    // MARK: - Init

    init(coordinator: StoreCoordinator) {
        self.coordinator = coordinator
    }

    // MARK: - 협업 기록 CRUD

    /// 협업 기록 추가
    func addCollaborationRecord(_ record: CollaborationRecord) {
        coordinator.company.collaborationRecords.append(record)
        coordinator.saveCompany()
    }

    /// 협업 기록 조회 (최신순)
    var collaborationRecords: [CollaborationRecord] {
        coordinator.company.collaborationRecords.sorted { $0.timestamp > $1.timestamp }
    }

    /// 특정 부서의 협업 기록
    func getCollaborationRecords(forDepartment department: String) -> [CollaborationRecord] {
        collaborationRecords.filter {
            $0.requesterDepartment == department || $0.responderDepartment == department
        }
    }

    /// 특정 프로젝트의 협업 기록
    func getCollaborationRecords(forProject projectId: UUID) -> [CollaborationRecord] {
        collaborationRecords.filter { $0.projectId == projectId }
    }

    /// 협업 기록 삭제
    func removeCollaborationRecord(_ recordId: UUID) {
        coordinator.company.collaborationRecords.removeAll { $0.id == recordId }
        coordinator.saveCompany()
    }

    /// 모든 협업 기록 삭제
    func clearAllCollaborationRecords() {
        coordinator.company.collaborationRecords.removeAll()
        coordinator.saveCompany()
    }
}
