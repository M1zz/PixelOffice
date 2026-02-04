import SwiftUI

struct OfficeView: View {
    @EnvironmentObject var companyStore: CompanyStore
    @Environment(\.openWindow) private var openWindow
    @State private var selectedDepartment: Department?
    @State private var selectedEmployee: Employee?
    @State private var zoomLevel: Double = 1.0
    @State private var floorSize: CGSize = .zero

    let columns = 2

    /// 걸어다니는 직원들의 이동 범위
    var walkingBounds: CGRect {
        CGRect(x: 30, y: 80, width: max(floorSize.width - 60, 200), height: max(floorSize.height - 100, 200))
    }

    /// 직원 ID로 직원과 소속 부서 찾기
    private func findEmployeeAndDepartment(employeeId: UUID) -> (Employee, Department)? {
        for department in companyStore.company.departments {
            if let employee = department.employees.first(where: { $0.id == employeeId }) {
                return (employee, department)
            }
        }
        return nil
    }

    var body: some View {
        HStack(spacing: 0) {
            // Office Floor View
            ScrollView([.horizontal, .vertical]) {
                ZStack {
                    VStack(spacing: 0) {
                        // Office Header
                        OfficeHeader(companyName: companyStore.company.name)

                        // Department Grid
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: columns), spacing: 20) {
                            ForEach(companyStore.company.departments) { department in
                                DepartmentView(
                                    department: department,
                                    isSelected: selectedDepartment?.id == department.id,
                                    onSelect: {
                                        withAnimation(.spring(response: 0.3)) {
                                            selectedDepartment = department
                                            selectedEmployee = nil
                                        }
                                    },
                                    onEmployeeSelect: { employee in
                                        withAnimation(.spring(response: 0.3)) {
                                            selectedEmployee = employee
                                            selectedDepartment = department
                                        }
                                    }
                                )
                            }
                        }
                        .padding(30)
                    }
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .onAppear { floorSize = geo.size }
                                .onChange(of: geo.size) { _, newSize in floorSize = newSize }
                        }
                    )

                    // 걸어다니는 휴식 중인 직원들 (회사 직원만)
                    WalkingEmployeesLayer(floorBounds: walkingBounds, projectId: nil) { employeeId in
                        // 직원과 부서를 찾아서 선택
                        if let (employee, department) = findEmployeeAndDepartment(employeeId: employeeId) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedEmployee = employee
                                selectedDepartment = department
                            }
                        }
                    }
                    .allowsHitTesting(true)
                }
                .scaleEffect(zoomLevel)
            }
            .background(OfficeFloorBackground())
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Detail Panel
            if let employee = selectedEmployee {
                EmployeeDetailPanel(
                    employeeId: employee.id,
                    department: selectedDepartment,
                    onClose: { selectedEmployee = nil }
                )
                .frame(width: 320)
                .transition(.move(edge: .trailing))
            } else if let department = selectedDepartment {
                DepartmentDetailPanel(
                    department: department,
                    onClose: { selectedDepartment = nil },
                    onAddEmployee: { openWindow(id: "add-employee", value: department.id) }
                )
                .frame(width: 320)
                .transition(.move(edge: .trailing))
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Slider(value: $zoomLevel, in: 0.5...2.0) {
                    Text("Zoom")
                }
                .frame(width: 100)

                Button {
                    // 부서 선택 없이 직원 추가 창 열기 (빈 UUID 전달)
                    openWindow(id: "add-employee", value: UUID())
                } label: {
                    Label("직원 추가", systemImage: "person.badge.plus")
                }
            }
        }
    }
}

struct OfficeHeader: View {
    let companyName: String
    
    var body: some View {
        HStack {
            Image(systemName: "building.2.fill")
                .font(.title)
            Text(companyName)
                .font(.title.bold())
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}

struct OfficeFloorBackground: View {
    var body: some View {
        Canvas { context, size in
            let gridSize: CGFloat = 32

            // Draw grid pattern (floor tiles) - 밝은 색상으로 변경
            for x in stride(from: 0, through: size.width, by: gridSize) {
                for y in stride(from: 0, through: size.height, by: gridSize) {
                    let isAlternate = (Int(x / gridSize) + Int(y / gridSize)) % 2 == 0
                    let rect = CGRect(x: x, y: y, width: gridSize, height: gridSize)

                    context.fill(
                        Path(rect),
                        with: .color(isAlternate ? Color(white: 0.92) : Color(white: 0.88))
                    )
                }
            }
        }
    }
}

struct EmployeeDetailPanel: View {
    let employeeId: UUID  // ID만 받아서 실시간으로 조회
    let department: Department?
    let onClose: () -> Void
    @EnvironmentObject var companyStore: CompanyStore

    /// CompanyStore에서 실시간 직원 정보 가져오기
    var employee: Employee? {
        companyStore.findEmployee(byId: employeeId)
    }

    var body: some View {
        if let employee = employee {
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text(employee.name)
                            .font(.title2.bold())
                        HStack {
                            Image(systemName: employee.aiType.icon)
                            Text(employee.aiType.rawValue)
                        }
                        .font(.body)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(.ultraThinMaterial)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Status Card
                        StatusCard(employeeId: employeeId)

                        // Stats
                        StatsCard(employeeId: employeeId)

                        // Current Task
                        if let taskId = employee.currentTaskId {
                            CurrentTaskCard(taskId: taskId)
                        }

                        // Actions
                        ActionsCard(employeeId: employeeId)
                    }
                    .padding()
                }
            }
            .background(Color(NSColor.windowBackgroundColor))
        } else {
            Text("직원을 찾을 수 없습니다")
        }
    }
}

struct StatusCard: View {
    let employeeId: UUID
    @EnvironmentObject var companyStore: CompanyStore

    var employee: Employee? {
        companyStore.findEmployee(byId: employeeId)
    }

    var body: some View {
        if let employee = employee {
            VStack(alignment: .leading, spacing: 8) {
                Text("상태")
                    .font(.headline)

                HStack {
                    Circle()
                        .fill(employee.status.color)
                        .frame(width: 12, height: 12)
                    Text(employee.status.rawValue)
                    Spacer()
                    Image(systemName: employee.status.icon)
                        .foregroundStyle(employee.status.color)
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

struct StatsCard: View {
    let employeeId: UUID
    @EnvironmentObject var companyStore: CompanyStore

    var employee: Employee? {
        companyStore.findEmployee(byId: employeeId)
    }

    var body: some View {
        if let employee = employee {
            VStack(alignment: .leading, spacing: 8) {
                Text("통계")
                    .font(.headline)

                VStack(spacing: 12) {
                    HStack {
                        Text("완료한 태스크")
                        Spacer()
                        Text("\(employee.totalTasksCompleted)개")
                            .fontWeight(.medium)
                    }

                    HStack {
                        Text("생성일")
                        Spacer()
                        Text(employee.createdAt.formatted(date: .abbreviated, time: .omitted))
                            .fontWeight(.medium)
                    }

                    HStack {
                        Text("대화 기록")
                        Spacer()
                        Text("\(employee.conversationHistory.count)개 메시지")
                            .fontWeight(.medium)
                    }
                }
                .font(.callout)
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

struct CurrentTaskCard: View {
    let taskId: UUID
    @EnvironmentObject var companyStore: CompanyStore
    
    var task: ProjectTask? {
        companyStore.company.projects.flatMap { $0.tasks }.first { $0.id == taskId }
    }
    
    var body: some View {
        if let task = task {
            VStack(alignment: .leading, spacing: 8) {
                Text("현재 작업")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(task.title)
                        .fontWeight(.medium)
                    
                    HStack {
                        Image(systemName: task.departmentType.icon)
                        Text(task.departmentType.rawValue)
                    }
                    .font(.body)
                    .foregroundStyle(.secondary)
                    
                    ProgressView(value: 0.5)
                        .tint(.blue)
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

struct ActionsCard: View {
    let employeeId: UUID
    @EnvironmentObject var companyStore: CompanyStore
    @Environment(\.openWindow) private var openWindow
    @State private var showingBadge = false

    var employee: Employee? {
        companyStore.findEmployee(byId: employeeId)
    }

    var employeeDepartment: DepartmentType {
        companyStore.company.departments.first { dept in
            dept.employees.contains { $0.id == employeeId }
        }?.type ?? .general
    }

    var body: some View {
        if let employee = employee {
            VStack(alignment: .leading, spacing: 8) {
                Text("액션")
                    .font(.headline)

                VStack(spacing: 8) {
                    Button {
                        openWindow(id: "employee-chat", value: employee.id)
                    } label: {
                        Label("대화 열기", systemImage: "bubble.left.and.bubble.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        showingBadge = true
                    } label: {
                        Label("사원증 보기", systemImage: "person.crop.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        openWindow(id: "employee-worklog", value: EmployeeWorkLogData(employeeId: employee.id, employeeName: employee.name))
                    } label: {
                        Label("업무 기록", systemImage: "doc.text.magnifyingglass")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        clearConversation()
                    } label: {
                        Label("대화 초기화", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive) {
                        companyStore.removeEmployee(employee.id)
                    } label: {
                        Label("직원 삭제", systemImage: "person.badge.minus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .sheet(isPresented: $showingBadge) {
                VStack(spacing: 20) {
                    Text("사원증")
                        .font(.headline)

                    EmployeeBadgeView(
                        name: employee.name,
                        employeeNumber: employee.employeeNumber,
                        departmentType: employeeDepartment,
                        aiType: employee.aiType,
                        appearance: employee.characterAppearance,
                        hireDate: employee.createdAt
                    )

                    Button("닫기") {
                        showingBadge = false
                    }
                    .buttonStyle(.bordered)
                }
                .padding(40)
            }
        }
    }

    private func clearConversation() {
        for (deptIndex, dept) in companyStore.company.departments.enumerated() {
            if let empIndex = dept.employees.firstIndex(where: { $0.id == employeeId }) {
                companyStore.company.departments[deptIndex].employees[empIndex].conversationHistory = []
                companyStore.saveCompany()
                break
            }
        }
    }
}

struct DepartmentDetailPanel: View {
    let department: Department
    let onClose: () -> Void
    let onAddEmployee: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    HStack {
                        Image(systemName: department.type.icon)
                            .foregroundStyle(department.type.color)
                        Text(department.name)
                            .font(.title2.bold())
                    }
                    Text(department.type.description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(.ultraThinMaterial)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Capacity
                    VStack(alignment: .leading, spacing: 8) {
                        Text("인원")
                            .font(.headline)
                        
                        HStack {
                            Text("\(department.employees.count) / \(department.maxCapacity)")
                                .font(.title3.bold())
                            Spacer()
                            if department.isFull {
                                Text("풀")
                                    .font(.body)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(.red.opacity(0.2))
                                    .foregroundStyle(.red)
                                    .clipShape(Capsule())
                            }
                        }
                        
                        ProgressView(value: Double(department.employees.count), total: Double(department.maxCapacity))
                            .tint(department.type.color)
                    }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    // Employees List
                    VStack(alignment: .leading, spacing: 8) {
                        Text("직원 목록")
                            .font(.headline)
                        
                        if department.employees.isEmpty {
                            Text("아직 직원이 없습니다")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            ForEach(department.employees) { employee in
                                HStack {
                                    Circle()
                                        .fill(employee.status.color)
                                        .frame(width: 8, height: 8)
                                    Text(employee.name)
                                    Spacer()
                                    Image(systemName: employee.aiType.icon)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding()
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    // Add Employee Button
                    Button(action: onAddEmployee) {
                        Label("직원 추가", systemImage: "person.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(department.isFull)
                }
                .padding()
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

#Preview {
    OfficeView()
        .environmentObject(CompanyStore())
        .frame(width: 1200, height: 800)
}
