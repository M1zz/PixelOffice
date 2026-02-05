import Foundation

struct Sprint: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var goal: String
    var version: String
    var startDate: Date
    var endDate: Date
    var isActive: Bool
    var createdAt: Date
    var goalTaskIds: [UUID]

    enum CodingKeys: String, CodingKey {
        case id, name, goal, version, startDate, endDate, isActive, createdAt, goalTaskIds
    }

    init(
        id: UUID = UUID(),
        name: String,
        goal: String = "",
        version: String = "",
        startDate: Date = Date(),
        endDate: Date = Calendar.current.date(byAdding: .weekOfYear, value: 2, to: Date()) ?? Date(),
        isActive: Bool = false,
        createdAt: Date = Date(),
        goalTaskIds: [UUID] = []
    ) {
        self.id = id
        self.name = name
        self.goal = goal
        self.version = version
        self.startDate = startDate
        self.endDate = endDate
        self.isActive = isActive
        self.createdAt = createdAt
        self.goalTaskIds = goalTaskIds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        goal = try container.decode(String.self, forKey: .goal)
        version = try container.decode(String.self, forKey: .version)
        startDate = try container.decode(Date.self, forKey: .startDate)
        endDate = try container.decode(Date.self, forKey: .endDate)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        goalTaskIds = try container.decodeIfPresent([UUID].self, forKey: .goalTaskIds) ?? []
    }

    var remainingDays: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: endDate).day ?? 0
    }

    var isOverdue: Bool {
        endDate < Date()
    }

    var totalDays: Int {
        Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 1
    }

    var elapsedDays: Int {
        Calendar.current.dateComponents([.day], from: startDate, to: Date()).day ?? 0
    }
}
