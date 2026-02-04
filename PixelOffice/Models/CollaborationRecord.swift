import Foundation

/// 부서 간 협업 기록
struct CollaborationRecord: Codable, Identifiable {
    var id: UUID
    var timestamp: Date

    /// 요청자 정보
    var requesterId: UUID
    var requesterName: String
    var requesterDepartment: String

    /// 응답자 정보
    var responderId: UUID
    var responderName: String
    var responderDepartment: String

    /// 대화 내용
    var requestContent: String
    var responseContent: String

    /// 관련 프로젝트 (있는 경우)
    var projectId: UUID?
    var projectName: String?

    /// 상태
    var status: CollaborationStatus

    /// 태그 (검색용)
    var tags: [String]

    enum CodingKeys: String, CodingKey {
        case id, timestamp, requesterId, requesterName, requesterDepartment
        case responderId, responderName, responderDepartment
        case requestContent, responseContent, projectId, projectName
        case status, tags
    }

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        requesterId: UUID,
        requesterName: String,
        requesterDepartment: String,
        responderId: UUID,
        responderName: String,
        responderDepartment: String,
        requestContent: String,
        responseContent: String,
        projectId: UUID? = nil,
        projectName: String? = nil,
        status: CollaborationStatus = .completed,
        tags: [String] = []
    ) {
        self.id = id
        self.timestamp = timestamp
        self.requesterId = requesterId
        self.requesterName = requesterName
        self.requesterDepartment = requesterDepartment
        self.responderId = responderId
        self.responderName = responderName
        self.responderDepartment = responderDepartment
        self.requestContent = requestContent
        self.responseContent = responseContent
        self.projectId = projectId
        self.projectName = projectName
        self.status = status
        self.tags = tags
    }

    /// 포맷된 날짜
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd HH:mm"
        return formatter.string(from: timestamp)
    }

    /// 요약 (첫 100자)
    var summary: String {
        let text = requestContent.prefix(100)
        return text.count < requestContent.count ? "\(text)..." : String(text)
    }
}

enum CollaborationStatus: String, Codable {
    case pending = "대기중"
    case completed = "완료"
    case failed = "실패"

    var icon: String {
        switch self {
        case .pending: return "clock"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }
}
