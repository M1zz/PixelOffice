import SwiftUI

/// 프로젝트별 오피스 뷰
struct ProjectOfficeView: View {
    let projectId: UUID
    @EnvironmentObject var companyStore: CompanyStore
    @Environment(\.openWindow) private var openWindow
    @State private var selectedDepartment: ProjectDepartment?
    @State private var selectedEmployee: ProjectEmployee?
    @State private var zoomLevel: Double = 1.0
    @State private var floorSize: CGSize = .zero

    let columns = 2

    var project: Project? {
        companyStore.company.projects.first { $0.id == projectId }
    }

    /// 프로젝트 직원 ID로 직원과 소속 부서 찾기
    private func findProjectEmployeeAndDepartment(employeeId: UUID, project: Project) -> (ProjectEmployee, ProjectDepartment)? {
        for department in project.departments {
            if let employee = department.employees.first(where: { $0.id == employeeId }) {
                return (employee, department)
            }
        }
        return nil
    }

    /// 걸어다니는 직원들의 이동 범위
    var walkingBounds: CGRect {
        CGRect(x: 30, y: 80, width: max(floorSize.width - 60, 200), height: max(floorSize.height - 100, 200))
    }

    var body: some View {
        if let project = project {
            HStack(spacing: 0) {
                // Office Floor View
                ScrollView([.horizontal, .vertical]) {
                    ZStack {
                        VStack(spacing: 0) {
                            // Project Office Header
                            ProjectOfficeHeader(
                                project: project,
                                onOpenKanban: {
                                    openWindow(id: "kanban", value: projectId)
                                },
                                onOpenWiki: {
                                    openWindow(id: "project-wiki", value: projectId)
                                },
                                onOpenCollaboration: {
                                    openWindow(id: "collaboration", value: projectId)
                                }
                            )

                            // Department Grid
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: columns), spacing: 20) {
                                ForEach(project.departments) { department in
                                    ProjectDepartmentView(
                                        department: department,
                                        projectId: projectId,
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

                        // 걸어다니는 휴식 중인 직원들 (이 프로젝트 직원만)
                        WalkingEmployeesLayer(floorBounds: walkingBounds, projectId: projectId) { employeeId in
                            // 직원과 부서를 찾아서 선택
                            if let (employee, department) = findProjectEmployeeAndDepartment(employeeId: employeeId, project: project) {
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
                    ProjectEmployeeDetailPanel(
                        employeeId: employee.id,
                        projectId: projectId,
                        department: selectedDepartment,
                        onClose: { selectedEmployee = nil }
                    )
                    .frame(width: 320)
                    .transition(.move(edge: .trailing))
                } else if let department = selectedDepartment {
                    ProjectDepartmentDetailPanel(
                        department: department,
                        projectId: projectId,
                        onClose: { selectedDepartment = nil },
                        onAddEmployee: {
                            openWindow(id: "add-project-employee", value: AddProjectEmployeeContext(projectId: projectId, departmentType: department.type))
                        }
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
                        openWindow(id: "kanban", value: projectId)
                    } label: {
                        Label("칸반", systemImage: "rectangle.split.3x1")
                    }

                    Button {
                        openWindow(id: "project-wiki", value: projectId)
                    } label: {
                        Label("위키", systemImage: "books.vertical")
                    }

                    Button {
                        openWindow(id: "collaboration", value: projectId)
                    } label: {
                        Label("협업", systemImage: "bubble.left.and.bubble.right")
                    }

                    Button {
                        openWindow(id: "add-project-employee", value: AddProjectEmployeeContext(projectId: projectId, departmentType: nil))
                    } label: {
                        Label("직원 추가", systemImage: "person.badge.plus")
                    }
                }
            }
        } else {
            Text("프로젝트를 찾을 수 없습니다")
        }
    }
}

struct ProjectOfficeHeader: View {
    let project: Project
    let onOpenKanban: () -> Void
    let onOpenWiki: () -> Void
    let onOpenCollaboration: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "building.2.fill")
                .font(.title)
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.title.bold())
                HStack(spacing: 4) {
                    Circle()
                        .fill(project.status.color)
                        .frame(width: 8, height: 8)
                    Text(project.status.rawValue)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()

            // 칸반 보드 버튼
            Button {
                onOpenKanban()
            } label: {
                Label("칸반", systemImage: "rectangle.split.3x1")
            }
            .buttonStyle(.bordered)

            // 위키 버튼
            Button {
                onOpenWiki()
            } label: {
                Label("위키", systemImage: "books.vertical")
            }
            .buttonStyle(.bordered)

            // 협업 기록 버튼
            Button {
                onOpenCollaboration()
            } label: {
                Label("협업", systemImage: "bubble.left.and.bubble.right")
            }
            .buttonStyle(.bordered)

            VStack(alignment: .trailing) {
                Text("직원 \(project.allEmployees.count)명")
                    .font(.body)
                Text("작업 중 \(project.workingEmployees.count)명")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
}

struct ProjectEmployeeDetailPanel: View {
    let employeeId: UUID
    let projectId: UUID
    let department: ProjectDepartment?
    let onClose: () -> Void
    @EnvironmentObject var companyStore: CompanyStore
    @Environment(\.openWindow) private var openWindow

    var employee: ProjectEmployee? {
        companyStore.getProjectEmployee(byId: employeeId, inProject: projectId)
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
                        ProjectEmployeeStatusCard(employee: employee)

                        // Stats
                        ProjectEmployeeStatsCard(employee: employee)

                        // Actions
                        ProjectEmployeeActionsCard(
                            employeeId: employeeId,
                            projectId: projectId
                        )
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

struct ProjectEmployeeStatusCard: View {
    let employee: ProjectEmployee

    var body: some View {
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

struct ProjectEmployeeStatsCard: View {
    let employee: ProjectEmployee

    var body: some View {
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
                    Text("배정일")
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

struct ProjectEmployeeActionsCard: View {
    let employeeId: UUID
    let projectId: UUID
    @EnvironmentObject var companyStore: CompanyStore
    @Environment(\.openWindow) private var openWindow
    @State private var showingBadge = false

    var employee: ProjectEmployee? {
        companyStore.getProjectEmployee(byId: employeeId, inProject: projectId)
    }

    var project: Project? {
        companyStore.company.projects.first { $0.id == projectId }
    }

    var body: some View {
        if let employee = employee {
            VStack(alignment: .leading, spacing: 8) {
                Text("액션")
                    .font(.headline)

                VStack(spacing: 8) {
                    Button {
                        openWindow(id: "project-employee-chat", value: ProjectEmployeeChatContext(projectId: projectId, employeeId: employeeId))
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

                    if let proj = project {
                        Button {
                            openWindow(id: "project-employee-worklog", value: ProjectEmployeeWorkLogData(employeeId: employee.id, employeeName: employee.name, projectName: proj.name, departmentType: employee.departmentType))
                        } label: {
                            Label("업무 기록", systemImage: "doc.text.magnifyingglass")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    Button {
                        clearConversation()
                    } label: {
                        Label("대화 초기화", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button(role: .destructive) {
                        companyStore.removeProjectEmployee(employeeId, fromProject: projectId)
                    } label: {
                        Label("직원 제거", systemImage: "person.badge.minus")
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
                        departmentType: employee.departmentType,
                        aiType: employee.aiType,
                        appearance: employee.characterAppearance,
                        hireDate: employee.createdAt,
                        jobRoles: employee.jobRoles,
                        personality: employee.personality,
                        strengths: employee.strengths,
                        workStyle: employee.workStyle,
                        statistics: employee.statistics
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
        companyStore.updateProjectEmployeeConversation(projectId: projectId, employeeId: employeeId, messages: [])
    }
}

struct ProjectDepartmentDetailPanel: View {
    let department: ProjectDepartment
    let projectId: UUID
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

/// 프로젝트 직원 추가 창에 전달할 컨텍스트
struct AddProjectEmployeeContext: Codable, Hashable {
    let projectId: UUID
    let departmentType: DepartmentType?
}

/// 프로젝트 직원 채팅 창에 전달할 컨텍스트
struct ProjectEmployeeChatContext: Codable, Hashable {
    let projectId: UUID
    let employeeId: UUID
}

#Preview {
    ProjectOfficeView(projectId: UUID())
        .environmentObject(CompanyStore())
        .frame(width: 1200, height: 800)
}
