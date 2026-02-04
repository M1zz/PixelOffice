import Foundation

/// 권한 요청 유형
enum PermissionType: String, Codable, CaseIterable {
    case fileWrite = "파일 작성"
    case fileEdit = "파일 수정"
    case fileDelete = "파일 삭제"
    case commandExecution = "명령 실행"
    case apiCall = "API 호출"
    case dataExport = "데이터 내보내기"
}

/// 권한 요청 상태
enum PermissionStatus: String, Codable {
    case pending = "대기 중"
    case approved = "승인됨"
    case denied = "거부됨"
    case expired = "만료됨"
}

/// 권한 요청
struct PermissionRequest: Identifiable, Codable, Hashable {
    let id: UUID
    let type: PermissionType
    let employeeId: UUID
    let employeeName: String
    let employeeDepartment: String
    let projectId: UUID?
    let projectName: String?

    let title: String              // 요청 제목
    let description: String        // 상세 설명
    let targetPath: String?        // 파일 경로 또는 명령어
    let estimatedSize: Int?        // 파일 크기 (bytes)
    let metadata: [String: String] // 추가 메타데이터

    var status: PermissionStatus
    let requestedAt: Date
    var respondedAt: Date?
    var expiresAt: Date?

    var autoApproved: Bool         // 자동 승인 규칙에 의해 승인됨
    var reason: String?            // 승인/거부 사유

    init(
        id: UUID = UUID(),
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
        status: PermissionStatus = .pending,
        requestedAt: Date = Date(),
        respondedAt: Date? = nil,
        expiresAt: Date? = nil,
        autoApproved: Bool = false,
        reason: String? = nil
    ) {
        self.id = id
        self.type = type
        self.employeeId = employeeId
        self.employeeName = employeeName
        self.employeeDepartment = employeeDepartment
        self.projectId = projectId
        self.projectName = projectName
        self.title = title
        self.description = description
        self.targetPath = targetPath
        self.estimatedSize = estimatedSize
        self.metadata = metadata
        self.status = status
        self.requestedAt = requestedAt
        self.respondedAt = respondedAt
        self.expiresAt = expiresAt
        self.autoApproved = autoApproved
        self.reason = reason
    }

    /// 파일 크기를 사람이 읽기 쉬운 형식으로 변환
    var formattedSize: String? {
        guard let size = estimatedSize else { return nil }

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }

    /// 만료 여부 확인
    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }

    /// 대기 시간 (초)
    var waitingTime: TimeInterval? {
        guard status == .pending else { return nil }
        return Date().timeIntervalSince(requestedAt)
    }
}

/// 자동 승인 규칙
struct AutoApprovalRule: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var enabled: Bool

    var permissionTypes: [PermissionType]    // 허용할 권한 유형
    var employeeIds: [UUID]?                  // 특정 직원만 (nil = 모든 직원)
    var departments: [String]?                // 특정 부서만 (nil = 모든 부서)
    var pathPatterns: [String]?               // 경로 패턴 (glob)
    var maxFileSize: Int?                     // 최대 파일 크기

    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        enabled: Bool = true,
        permissionTypes: [PermissionType] = [],
        employeeIds: [UUID]? = nil,
        departments: [String]? = nil,
        pathPatterns: [String]? = nil,
        maxFileSize: Int? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.enabled = enabled
        self.permissionTypes = permissionTypes
        self.employeeIds = employeeIds
        self.departments = departments
        self.pathPatterns = pathPatterns
        self.maxFileSize = maxFileSize
        self.createdAt = createdAt
    }

    /// 요청이 이 규칙과 일치하는지 확인
    func matches(_ request: PermissionRequest) -> Bool {
        guard enabled else { return false }

        // 권한 유형 확인
        guard permissionTypes.isEmpty || permissionTypes.contains(request.type) else {
            return false
        }

        // 직원 확인
        if let allowedEmployees = employeeIds, !allowedEmployees.contains(request.employeeId) {
            return false
        }

        // 부서 확인
        if let allowedDepartments = departments, !allowedDepartments.contains(request.employeeDepartment) {
            return false
        }

        // 파일 크기 확인
        if let maxSize = maxFileSize, let requestSize = request.estimatedSize, requestSize > maxSize {
            return false
        }

        // 경로 패턴 확인 (간단한 와일드카드 매칭)
        if let patterns = pathPatterns, !patterns.isEmpty, let path = request.targetPath {
            let matchesAnyPattern = patterns.contains { pattern in
                matchesWildcard(string: path, pattern: pattern)
            }
            if !matchesAnyPattern {
                return false
            }
        }

        return true
    }

    /// 간단한 와일드카드 패턴 매칭
    private func matchesWildcard(string: String, pattern: String) -> Bool {
        let regexPattern = pattern
            .replacingOccurrences(of: ".", with: "\\.")
            .replacingOccurrences(of: "*", with: ".*")

        guard let regex = try? NSRegularExpression(pattern: "^" + regexPattern + "$") else {
            return false
        }

        let range = NSRange(string.startIndex..., in: string)
        return regex.firstMatch(in: string, range: range) != nil
    }
}
