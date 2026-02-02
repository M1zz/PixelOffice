import Foundation
import SwiftUI

/// 프로젝트 내 부서 (프로젝트별로 독립적인 직원 구성)
struct ProjectDepartment: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var type: DepartmentType
    var employees: [ProjectEmployee]
    var maxCapacity: Int
    var position: DeskPosition

    init(
        id: UUID = UUID(),
        type: DepartmentType,
        employees: [ProjectEmployee] = [],
        maxCapacity: Int = 4,
        position: DeskPosition = DeskPosition(row: 0, column: 0)
    ) {
        self.id = id
        self.type = type
        self.employees = employees
        self.maxCapacity = maxCapacity
        self.position = position
    }

    var name: String {
        type.rawValue + "팀"
    }

    var availableSlots: Int {
        maxCapacity - employees.count
    }

    var isFull: Bool {
        employees.count >= maxCapacity
    }

    static func == (lhs: ProjectDepartment, rhs: ProjectDepartment) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// 새 프로젝트 생성 시 기본 부서 구성
    static var defaultProjectDepartments: [ProjectDepartment] {
        [
            ProjectDepartment(type: .planning, position: DeskPosition(row: 0, column: 0)),
            ProjectDepartment(type: .design, position: DeskPosition(row: 0, column: 1)),
            ProjectDepartment(type: .development, position: DeskPosition(row: 1, column: 0)),
            ProjectDepartment(type: .marketing, position: DeskPosition(row: 1, column: 1)),
            ProjectDepartment(type: .qa, position: DeskPosition(row: 2, column: 0))
        ]
    }
}
