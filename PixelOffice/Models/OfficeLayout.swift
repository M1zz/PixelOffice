import Foundation
import SwiftUI

/// 오피스 레이아웃 설정
struct OfficeLayout: Codable {
    var mode: LayoutMode
    var gridColumns: Int
    var departmentPositions: [UUID: DeskPosition]  // 부서 ID -> 위치
    var customDepartments: [CustomDepartment]

    enum LayoutMode: String, Codable {
        case grid       // 자동 그리드 배치
        case custom     // 커스텀 자유 배치
    }

    init(
        mode: LayoutMode = .grid,
        gridColumns: Int = 2,
        departmentPositions: [UUID: DeskPosition] = [:],
        customDepartments: [CustomDepartment] = []
    ) {
        self.mode = mode
        self.gridColumns = gridColumns
        self.departmentPositions = departmentPositions
        self.customDepartments = customDepartments
    }

    static var `default`: OfficeLayout {
        OfficeLayout(mode: .grid, gridColumns: 2)
    }
}

/// 커스텀 부서 (이름 변경, 색상 등)
struct CustomDepartment: Codable, Identifiable {
    var id: UUID
    var customName: String?
    var customColor: CodableColor?
    var customIcon: String?
    var size: DepartmentSize

    enum DepartmentSize: String, Codable {
        case small = "소형"   // 2명
        case medium = "중형"  // 4명
        case large = "대형"   // 6명

        var maxCapacity: Int {
            switch self {
            case .small: return 2
            case .medium: return 4
            case .large: return 6
            }
        }
    }
}

/// Codable Color
struct CodableColor: Codable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double

    init(color: Color) {
        // SwiftUI Color를 RGB로 변환
        let components = color.cgColor?.components ?? [0, 0, 0, 1]
        self.red = components[0]
        self.green = components[1]
        self.blue = components[2]
        self.opacity = components.count > 3 ? components[3] : 1.0
    }

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }
}
