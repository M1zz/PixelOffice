import Foundation
import SwiftUI

/// 프로젝트 내 부서 (프로젝트별로 독립적인 직원 구성)
struct ProjectDepartment: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var type: DepartmentType
    var employees: [ProjectEmployee]
    var maxCapacity: Int
    var position: DeskPosition
    var customName: String?  // 커스텀 부서 이름 (nil이면 기본 이름 사용)
    var customIcon: String?  // 커스텀 아이콘 (SF Symbol 이름)
    var customColorHex: String?  // 커스텀 색상 (HEX)

    init(
        id: UUID = UUID(),
        type: DepartmentType,
        employees: [ProjectEmployee] = [],
        maxCapacity: Int = 4,
        position: DeskPosition = DeskPosition(row: 0, column: 0),
        customName: String? = nil,
        customIcon: String? = nil,
        customColorHex: String? = nil
    ) {
        self.id = id
        self.type = type
        self.employees = employees
        self.maxCapacity = maxCapacity
        self.position = position
        self.customName = customName
        self.customIcon = customIcon
        self.customColorHex = customColorHex
    }

    var name: String {
        customName ?? (type.rawValue + "팀")
    }
    
    var icon: String {
        customIcon ?? type.icon
    }
    
    var color: Color {
        if let hex = customColorHex {
            return Color(hex: hex)
        }
        return type.color
    }
    
    /// 커스텀 부서인지 확인
    var isCustom: Bool {
        type == .general && customName != nil
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

// MARK: - Color Extension for Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
