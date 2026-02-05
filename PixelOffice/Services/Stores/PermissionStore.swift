import Foundation

/// 권한 요청 및 자동 승인 규칙 관리 담당 도메인 Store
@MainActor
final class PermissionStore {

    // MARK: - Properties

    unowned let coordinator: StoreCoordinator

    // MARK: - Init

    init(coordinator: StoreCoordinator) {
        self.coordinator = coordinator
    }

    // MARK: - 권한 요청

    /// 권한 요청 추가 (자동 승인 규칙 확인)
    func addPermissionRequest(_ request: PermissionRequest) {
        print("🏪 [PermissionStore] 권한 요청 추가 시작")
        print("   - 요청 ID: \(request.id)")
        print("   - 제목: \(request.title)")
        print("   - 직원: \(request.employeeName)")

        var modifiedRequest = request

        // 자동 승인 규칙 확인
        if let matchingRule = coordinator.company.autoApprovalRules.first(where: { $0.matches(request) }) {
            print("⚡️ [PermissionStore] 자동 승인 규칙 매칭: \(matchingRule.name)")
            modifiedRequest.status = .approved
            modifiedRequest.autoApproved = true
            modifiedRequest.reason = "자동 승인: \(matchingRule.name)"
            modifiedRequest.respondedAt = Date()
        } else {
            print("⏳ [PermissionStore] 자동 승인 규칙 없음 - Pending 상태로 추가")
        }

        coordinator.company.permissionRequests.append(modifiedRequest)
        print("✅ [PermissionStore] 권한 요청 추가 완료 - 총 \(coordinator.company.permissionRequests.count)개")
        print("📊 [PermissionStore] Pending: \(coordinator.company.permissionRequests.filter { $0.status == .pending }.count)개")

        coordinator.saveCompany()

        // UI 업데이트 강제
        coordinator.triggerObjectUpdate()
    }

    /// 권한 요청 승인
    func approvePermissionRequest(_ requestId: UUID, reason: String? = nil) {
        guard let index = coordinator.company.permissionRequests.firstIndex(where: { $0.id == requestId }) else { return }
        coordinator.company.permissionRequests[index].status = .approved
        coordinator.company.permissionRequests[index].respondedAt = Date()
        coordinator.company.permissionRequests[index].reason = reason
        coordinator.saveCompany()

        // 토스트 알림
        let request = coordinator.company.permissionRequests[index]
        ToastManager.shared.show(
            title: "권한 승인",
            message: "\(request.employeeName)의 '\(request.title)' 요청을 승인했습니다",
            type: .success
        )
    }

    /// 권한 요청 거부
    func denyPermissionRequest(_ requestId: UUID, reason: String? = nil) {
        guard let index = coordinator.company.permissionRequests.firstIndex(where: { $0.id == requestId }) else { return }
        coordinator.company.permissionRequests[index].status = .denied
        coordinator.company.permissionRequests[index].respondedAt = Date()
        coordinator.company.permissionRequests[index].reason = reason
        coordinator.saveCompany()

        // 토스트 알림
        let request = coordinator.company.permissionRequests[index]
        ToastManager.shared.show(
            title: "권한 거부",
            message: "\(request.employeeName)의 '\(request.title)' 요청을 거부했습니다",
            type: .error
        )
    }

    /// 대기 중인 권한 요청 조회
    var pendingPermissionRequests: [PermissionRequest] {
        coordinator.company.permissionRequests.filter { $0.status == .pending }
    }

    /// 특정 직원의 권한 요청 조회
    func getPermissionRequests(employeeId: UUID) -> [PermissionRequest] {
        coordinator.company.permissionRequests.filter { $0.employeeId == employeeId }
    }

    /// 권한 요청 삭제
    func removePermissionRequest(_ requestId: UUID) {
        coordinator.company.permissionRequests.removeAll { $0.id == requestId }
        coordinator.saveCompany()
    }

    // MARK: - 자동 승인 규칙

    /// 자동 승인 규칙 추가
    func addAutoApprovalRule(_ rule: AutoApprovalRule) {
        coordinator.company.autoApprovalRules.append(rule)
        coordinator.saveCompany()
    }

    /// 자동 승인 규칙 업데이트
    func updateAutoApprovalRule(_ ruleId: UUID, update: (inout AutoApprovalRule) -> Void) {
        guard let index = coordinator.company.autoApprovalRules.firstIndex(where: { $0.id == ruleId }) else { return }
        update(&coordinator.company.autoApprovalRules[index])
        coordinator.saveCompany()
    }

    /// 자동 승인 규칙 삭제
    func removeAutoApprovalRule(_ ruleId: UUID) {
        coordinator.company.autoApprovalRules.removeAll { $0.id == ruleId }
        coordinator.saveCompany()
    }

    /// 모든 자동 승인 규칙
    var autoApprovalRules: [AutoApprovalRule] {
        coordinator.company.autoApprovalRules
    }
}
