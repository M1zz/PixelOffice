import SwiftUI

/// 사무실 바닥에서 걸어다니는 휴식 중인 직원들을 표시하는 레이어
struct WalkingEmployeesLayer: View {
    @EnvironmentObject var companyStore: CompanyStore
    @StateObject private var walkingManager = WalkingEmployeesManager()

    let floorBounds: CGRect
    /// nil이면 일반 오피스(회사 직원만), UUID가 있으면 해당 프로젝트 직원만 표시
    let projectId: UUID?
    /// 직원 선택 시 호출되는 콜백
    let onEmployeeSelect: ((UUID) -> Void)?

    init(floorBounds: CGRect, projectId: UUID? = nil, onEmployeeSelect: ((UUID) -> Void)? = nil) {
        self.floorBounds = floorBounds
        self.projectId = projectId
        self.onEmployeeSelect = onEmployeeSelect
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(walkingManager.walkingEmployees) { walkingEmployee in
                    WalkingEmployeeView(
                        walkingEmployee: walkingEmployee,
                        onSelect: {
                            onEmployeeSelect?(walkingEmployee.employeeId)
                        }
                    )
                    .position(walkingEmployee.position)
                }
            }
            .onAppear {
                walkingManager.updateIdleEmployees(from: companyStore, projectId: projectId)
            }
            .onChange(of: companyStore.employeeStatuses) { _, _ in
                walkingManager.updateIdleEmployees(from: companyStore, projectId: projectId)
            }
        }
    }
}

/// 걸어다니는 직원 하나를 표시
struct WalkingEmployeeView: View {
    @ObservedObject var walkingEmployee: WalkingEmployeeState
    let onSelect: () -> Void
    @State private var showName = false
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 0) {
            // 생각 말풍선 (랜덤하게 표시)
            if walkingEmployee.showThought {
                PixelThoughtBubble(text: walkingEmployee.currentThought)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    .animation(.spring(response: 0.3), value: walkingEmployee.showThought)
            }

            // 이름표 (호버 시)
            if showName && !walkingEmployee.showThought {
                Text(walkingEmployee.name)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .transition(.opacity.combined(with: .scale))
            }

            WalkingCharacter(
                appearance: walkingEmployee.appearance,
                aiType: walkingEmployee.aiType,
                direction: walkingEmployee.direction,
                isWalking: walkingEmployee.isWalking
            )
        }
        .scaleEffect(isHovering ? 1.1 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                showName = hovering
                isHovering = hovering
            }
        }
        .onTapGesture {
            onSelect()
        }
        .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
        .contentShape(Rectangle())  // 클릭 영역 확장
    }
}

/// 걸어다니는 직원들 관리
@MainActor
class WalkingEmployeesManager: ObservableObject {
    @Published var walkingEmployees: [WalkingEmployeeState] = []

    private var updateTimer: Timer?

    // 레이아웃 상수
    private let departmentWidth: CGFloat = 360
    private let departmentHeight: CGFloat = 380
    private let departmentSpacing: CGFloat = 20
    private let gridPadding: CGFloat = 30
    private let headerHeight: CGFloat = 60  // OfficeHeader 높이
    private let deskAreaPadding: CGFloat = 16
    private let deskSpacing: CGFloat = 12
    private let deskWidth: CGFloat = 120
    private let deskHeight: CGFloat = 120
    private let departmentHeaderHeight: CGFloat = 70

    init() {
        startUpdateLoop()
    }

    deinit {
        updateTimer?.invalidate()
    }

    /// 부서 인덱스로부터 부서의 화면 위치 계산
    private func departmentPosition(index: Int, columns: Int = 2) -> CGPoint {
        let col = index % columns
        let row = index / columns

        let x = gridPadding + CGFloat(col) * (departmentWidth + departmentSpacing) + departmentWidth / 2
        let y = headerHeight + gridPadding + CGFloat(row) * (departmentHeight + departmentSpacing) + departmentHeight / 2

        return CGPoint(x: x, y: y)
    }

    /// 부서 내 책상 인덱스로부터 책상의 화면 위치 계산
    private func deskPosition(departmentIndex: Int, deskIndex: Int, columns: Int = 2) -> CGPoint {
        let deptPos = departmentPosition(index: departmentIndex, columns: columns)

        // 부서 내 2x2 그리드에서의 위치
        let deskCol = deskIndex % 2
        let deskRow = deskIndex / 2

        // 부서 내 책상 영역 시작 위치 (부서 중심 기준)
        let deskAreaStartX = deptPos.x - departmentWidth / 2 + deskAreaPadding
        let deskAreaStartY = deptPos.y - departmentHeight / 2 + departmentHeaderHeight + deskAreaPadding

        // 각 책상의 중심 위치
        let x = deskAreaStartX + CGFloat(deskCol) * (deskWidth + deskSpacing) + deskWidth / 2
        let y = deskAreaStartY + CGFloat(deskRow) * (deskHeight + deskSpacing) + deskHeight / 2

        return CGPoint(x: x, y: y)
    }

    /// 휴식 중인 직원 목록 업데이트
    func updateIdleEmployees(from companyStore: CompanyStore, projectId: UUID?) {
        var idleEmployeesWithDesk: [(id: UUID, appearance: CharacterAppearance, aiType: AIType, name: String, deskPosition: CGPoint, departmentType: DepartmentType)] = []

        if let projectId = projectId {
            guard let project = companyStore.company.projects.first(where: { $0.id == projectId }) else {
                walkingEmployees.removeAll()
                return
            }

            for (deptIndex, dept) in project.departments.enumerated() {
                for (empIndex, emp) in dept.employees.enumerated() {
                    let status = companyStore.getEmployeeStatus(emp.id)
                    if status == .idle {
                        let deskPos = deskPosition(departmentIndex: deptIndex, deskIndex: empIndex)
                        idleEmployeesWithDesk.append((
                            id: emp.id,
                            appearance: emp.characterAppearance,
                            aiType: emp.aiType,
                            name: emp.name,
                            deskPosition: deskPos,
                            departmentType: dept.type
                        ))
                    }
                }
            }
        } else {
            for (deptIndex, dept) in companyStore.company.departments.enumerated() {
                for (empIndex, emp) in dept.employees.enumerated() {
                    let status = companyStore.getEmployeeStatus(emp.id)
                    if status == .idle {
                        let deskPos = deskPosition(departmentIndex: deptIndex, deskIndex: empIndex)
                        idleEmployeesWithDesk.append((
                            id: emp.id,
                            appearance: emp.characterAppearance,
                            aiType: emp.aiType,
                            name: emp.name,
                            deskPosition: deskPos,
                            departmentType: dept.type
                        ))
                    }
                }
            }
        }

        // 기존에 없던 직원 추가
        let existingIds = Set(walkingEmployees.map { $0.employeeId })
        for emp in idleEmployeesWithDesk {
            if !existingIds.contains(emp.id) {
                let newWalking = WalkingEmployeeState(
                    employeeId: emp.id,
                    appearance: emp.appearance,
                    aiType: emp.aiType,
                    name: emp.name,
                    deskPosition: emp.deskPosition,
                    departmentType: emp.departmentType
                )
                walkingEmployees.append(newWalking)
            }
        }

        // 더 이상 휴식 중이 아닌 직원 제거
        let idleIds = Set(idleEmployeesWithDesk.map { $0.id })
        walkingEmployees.removeAll { !idleIds.contains($0.employeeId) }
    }

    /// 위치 업데이트 루프 시작
    private func startUpdateLoop() {
        // 위치 업데이트 (30fps) - 각 직원이 자체 타이밍으로 움직임
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updatePositions()
            }
        }
    }

    private func updatePositions() {
        for employee in walkingEmployees {
            employee.updatePosition()
        }
        objectWillChange.send()
    }
}

#Preview {
    ZStack {
        Color(white: 0.9)

        WalkingEmployeesLayer(floorBounds: CGRect(x: 0, y: 0, width: 800, height: 600))
            .environmentObject(CompanyStore())
    }
    .frame(width: 800, height: 600)
}
