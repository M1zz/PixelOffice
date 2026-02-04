import Foundation
import SwiftUI

/// 권한 관리 서비스
@MainActor
class PermissionManager: ObservableObject {
    static let shared = PermissionManager()

    @Published var requests: [PermissionRequest] = []
    @Published var autoApprovalRules: [AutoApprovalRule] = []

    private let requestsKey = "permission_requests"
    private let rulesKey = "auto_approval_rules"

    private init() {
        loadData()
    }

    // MARK: - 권한 요청 관리

    /// 새 권한 요청 생성
    func createRequest(
        type: PermissionType,
        employeeId: UUID,
        employeeName: String,
        employeeDepartment: String,
        projectId: UUID? = nil,
        projectName: String? = nil,
        title: String,
        description: String,
        targetPath: String? = nil,
        estimatedSize: Int? = nil,
        metadata: [String: String] = [:],
        expiresIn: TimeInterval? = nil
    ) -> PermissionRequest {
        var request = PermissionRequest(
            type: type,
            employeeId: employeeId,
            employeeName: employeeName,
            employeeDepartment: employeeDepartment,
            projectId: projectId,
            projectName: projectName,
            title: title,
            description: description,
            targetPath: targetPath,
            estimatedSize: estimatedSize,
            metadata: metadata,
            expiresAt: expiresIn != nil ? Date().addingTimeInterval(expiresIn!) : nil
        )

        // 자동 승인 규칙 확인
        if let rule = autoApprovalRules.first(where: { $0.matches(request) }) {
            request.status = .approved
            request.autoApproved = true
            request.reason = "자동 승인: \(rule.name)"
            request.respondedAt = Date()
        }

        requests.insert(request, at: 0)
        saveData()

        return request
    }

    /// 권한 요청 승인
    func approveRequest(_ requestId: UUID, reason: String? = nil) {
        guard let index = requests.firstIndex(where: { $0.id == requestId }) else { return }

        requests[index].status = .approved
        requests[index].respondedAt = Date()
        requests[index].reason = reason

        saveData()
    }

    /// 권한 요청 거부
    func denyRequest(_ requestId: UUID, reason: String? = nil) {
        guard let index = requests.firstIndex(where: { $0.id == requestId }) else { return }

        requests[index].status = .denied
        requests[index].respondedAt = Date()
        requests[index].reason = reason

        saveData()
    }

    /// 권한 요청 삭제
    func deleteRequest(_ requestId: UUID) {
        requests.removeAll { $0.id == requestId }
        saveData()
    }

    /// 모든 대기 중인 요청 삭제
    func clearPendingRequests() {
        requests.removeAll { $0.status == .pending }
        saveData()
    }

    /// 모든 완료된 요청 삭제
    func clearCompletedRequests() {
        requests.removeAll { $0.status == .approved || $0.status == .denied }
        saveData()
    }

    // MARK: - 자동 승인 규칙 관리

    /// 자동 승인 규칙 추가
    func addAutoApprovalRule(_ rule: AutoApprovalRule) {
        autoApprovalRules.append(rule)
        saveData()
    }

    /// 자동 승인 규칙 업데이트
    func updateAutoApprovalRule(_ rule: AutoApprovalRule) {
        guard let index = autoApprovalRules.firstIndex(where: { $0.id == rule.id }) else { return }
        autoApprovalRules[index] = rule
        saveData()
    }

    /// 자동 승인 규칙 삭제
    func deleteAutoApprovalRule(_ ruleId: UUID) {
        autoApprovalRules.removeAll { $0.id == ruleId }
        saveData()
    }

    /// 자동 승인 규칙 토글
    func toggleAutoApprovalRule(_ ruleId: UUID) {
        guard let index = autoApprovalRules.firstIndex(where: { $0.id == ruleId }) else { return }
        autoApprovalRules[index].enabled.toggle()
        saveData()
    }

    // MARK: - 필터링

    /// 대기 중인 요청
    var pendingRequests: [PermissionRequest] {
        requests.filter { $0.status == .pending && !$0.isExpired }
    }

    /// 승인된 요청
    var approvedRequests: [PermissionRequest] {
        requests.filter { $0.status == .approved }
    }

    /// 거부된 요청
    var deniedRequests: [PermissionRequest] {
        requests.filter { $0.status == .denied }
    }

    /// 대기 중인 요청 개수
    var pendingCount: Int {
        pendingRequests.count
    }

    // MARK: - 통계

    /// 유형별 요청 개수
    func requestCount(for type: PermissionType) -> Int {
        requests.filter { $0.type == type }.count
    }

    /// 직원별 요청 개수
    func requestCount(for employeeId: UUID) -> Int {
        requests.filter { $0.employeeId == employeeId }.count
    }

    /// 승인률
    var approvalRate: Double {
        let total = requests.filter { $0.status != .pending }.count
        guard total > 0 else { return 0 }
        let approved = approvedRequests.count
        return Double(approved) / Double(total)
    }

    // MARK: - 데이터 저장/로드

    private func saveData() {
        // 권한 요청 저장
        if let encoded = try? JSONEncoder().encode(requests) {
            UserDefaults.standard.set(encoded, forKey: requestsKey)
        }

        // 자동 승인 규칙 저장
        if let encoded = try? JSONEncoder().encode(autoApprovalRules) {
            UserDefaults.standard.set(encoded, forKey: rulesKey)
        }
    }

    private func loadData() {
        // 권한 요청 로드
        if let data = UserDefaults.standard.data(forKey: requestsKey),
           let decoded = try? JSONDecoder().decode([PermissionRequest].self, from: data) {
            requests = decoded
        }

        // 자동 승인 규칙 로드
        if let data = UserDefaults.standard.data(forKey: rulesKey),
           let decoded = try? JSONDecoder().decode([AutoApprovalRule].self, from: data) {
            autoApprovalRules = decoded
        }

        // 기본 자동 승인 규칙 생성 (처음 실행 시)
        if autoApprovalRules.isEmpty {
            createDefaultRules()
        }
    }

    /// 기본 자동 승인 규칙 생성
    private func createDefaultRules() {
        // 프로젝트 디렉토리 내 파일 작성 자동 승인
        let projectFilesRule = AutoApprovalRule(
            name: "프로젝트 내 문서 작성",
            enabled: true,
            permissionTypes: [.fileWrite],
            pathPatterns: ["*/datas/*"],
            maxFileSize: 10 * 1024 * 1024  // 10MB
        )
        autoApprovalRules.append(projectFilesRule)

        saveData()
    }

    // MARK: - 편의 메서드

    /// 파일 작성 권한 요청
    func requestFileWrite(
        employeeId: UUID,
        employeeName: String,
        employeeDepartment: String,
        projectId: UUID? = nil,
        projectName: String? = nil,
        filePath: String,
        fileSize: Int?,
        description: String
    ) -> PermissionRequest {
        createRequest(
            type: .fileWrite,
            employeeId: employeeId,
            employeeName: employeeName,
            employeeDepartment: employeeDepartment,
            projectId: projectId,
            projectName: projectName,
            title: "파일 작성: \((filePath as NSString).lastPathComponent)",
            description: description,
            targetPath: filePath,
            estimatedSize: fileSize
        )
    }

    /// 명령 실행 권한 요청
    func requestCommandExecution(
        employeeId: UUID,
        employeeName: String,
        employeeDepartment: String,
        projectId: UUID? = nil,
        projectName: String? = nil,
        command: String,
        description: String
    ) -> PermissionRequest {
        createRequest(
            type: .commandExecution,
            employeeId: employeeId,
            employeeName: employeeName,
            employeeDepartment: employeeDepartment,
            projectId: projectId,
            projectName: projectName,
            title: "명령 실행",
            description: description,
            targetPath: command
        )
    }
}
