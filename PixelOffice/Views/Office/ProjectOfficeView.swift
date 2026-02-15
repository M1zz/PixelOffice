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
    @State private var showingProjectContext = false
    @State private var showingSourcePathEditor = false
    @State private var editingSourcePath = ""

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
                                },
                                onOpenProjectContext: {
                                    showingProjectContext = true
                                },
                                onOpenPipeline: {
                                    openWindow(id: "pipeline", value: projectId)
                                },
                                onEditSourcePath: {
                                    editingSourcePath = project.sourcePath ?? ""
                                    showingSourcePathEditor = true
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
                        openWindow(id: "pipeline", value: projectId)
                    } label: {
                        Label("파이프라인", systemImage: "gearshape.arrow.triangle.2.circlepath")
                    }

                    Button {
                        openWindow(id: "add-project-employee", value: AddProjectEmployeeContext(projectId: projectId, departmentType: nil))
                    } label: {
                        Label("직원 추가", systemImage: "person.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showingProjectContext) {
                ProjectInfoEditorView(projectName: project.name, isPresented: $showingProjectContext)
            }
            .sheet(isPresented: $showingSourcePathEditor) {
                SourcePathEditorSheet(
                    projectId: projectId,
                    sourcePath: $editingSourcePath,
                    isPresented: $showingSourcePathEditor
                )
                .environmentObject(companyStore)
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
    let onOpenProjectContext: () -> Void
    let onOpenPipeline: () -> Void
    let onEditSourcePath: () -> Void

    /// 현재 스프린트 태스크들
    var sprintTasks: [ProjectTask] {
        guard let sprint = project.activeSprint else { return [] }
        return project.tasks.filter { $0.sprintId == sprint.id }
    }

    /// 스프린트 진행률 (0.0 ~ 1.0)
    var sprintProgress: Double {
        guard !sprintTasks.isEmpty else { return 0 }
        let completed = sprintTasks.filter { $0.status == .done }.count
        return Double(completed) / Double(sprintTasks.count)
    }

    /// 전체 프로젝트 진행률 (완료된 태스크 / 전체 태스크)
    var overallProgress: Double {
        guard !project.tasks.isEmpty else { return 0 }
        let completed = project.tasks.filter { $0.status == .done }.count
        return Double(completed) / Double(project.tasks.count)
    }

    var body: some View {
        VStack(spacing: 8) {
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

            // 프로젝트 정보 버튼
            Button {
                onOpenProjectContext()
            } label: {
                Label("프로젝트 정보", systemImage: "info.circle")
            }
            .buttonStyle(.bordered)

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

            // 파이프라인 버튼
            Button {
                onOpenPipeline()
            } label: {
                Label("파이프라인", systemImage: "gearshape.arrow.triangle.2.circlepath")
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
            
            // 스프린트 진행률 표시
            if let sprint = project.activeSprint {
                SprintProgressRow(
                    sprint: sprint,
                    sprintTasks: sprintTasks,
                    sprintProgress: sprintProgress,
                    onOpenKanban: onOpenKanban
                )
            } else if !project.tasks.isEmpty {
                // 활성 스프린트가 없으면 전체 태스크 진행률 표시
                OverallProgressRow(
                    totalTasks: project.tasks.count,
                    completedTasks: project.tasks.filter { $0.status == .done }.count,
                    inProgressTasks: project.tasks.filter { $0.status == .inProgress }.count,
                    progress: overallProgress,
                    onOpenKanban: onOpenKanban
                )
            }
            
            // Source Path Row
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .foregroundStyle(.secondary)
                
                if let path = project.sourcePath, !path.isEmpty {
                    Text(path)
                        .font(.callout.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text("소스 경로 미설정 - AI가 코드를 수정하려면 경로를 설정하세요")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
                
                Spacer()
                
                Button {
                    onEditSourcePath()
                } label: {
                    Label(project.sourcePath == nil ? "경로 설정" : "변경", systemImage: "folder.badge.gearshape")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
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

// MARK: - Sprint Progress Row

struct SprintProgressRow: View {
    let sprint: Sprint
    let sprintTasks: [ProjectTask]
    let sprintProgress: Double
    let onOpenKanban: () -> Void

    var completedCount: Int {
        sprintTasks.filter { $0.status == .done }.count
    }

    var inProgressCount: Int {
        sprintTasks.filter { $0.status == .inProgress }.count
    }

    var body: some View {
        HStack(spacing: 16) {
            // 스프린트 아이콘 + 이름
            HStack(spacing: 8) {
                Image(systemName: "flag.fill")
                    .foregroundStyle(.orange)
                Text(sprint.name)
                    .font(.headline)
                if !sprint.version.isEmpty {
                    Text(sprint.version)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.15))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())
                }
            }

            Divider()
                .frame(height: 20)

            // 진행률 바
            HStack(spacing: 8) {
                ProgressView(value: sprintProgress)
                    .frame(width: 120)
                    .tint(progressColor)
                Text("\(Int(sprintProgress * 100))%")
                    .font(.callout.monospacedDigit().bold())
                    .foregroundStyle(progressColor)
            }

            // 태스크 카운트
            HStack(spacing: 12) {
                Label("\(completedCount)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Label("\(inProgressCount)", systemImage: "arrow.triangle.2.circlepath.circle.fill")
                    .foregroundStyle(.blue)
                Label("\(sprintTasks.count - completedCount - inProgressCount)", systemImage: "circle")
                    .foregroundStyle(.secondary)
            }
            .font(.callout)

            Divider()
                .frame(height: 20)

            // 남은 일수
            HStack(spacing: 4) {
                if sprint.isOverdue {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text("마감 초과")
                        .foregroundStyle(.red)
                } else {
                    Image(systemName: "calendar")
                    Text("D-\(sprint.remainingDays)")
                        .foregroundStyle(sprint.remainingDays <= 3 ? .red : .primary)
                }
            }
            .font(.callout)

            Spacer()

            // 칸반 바로가기
            Button {
                onOpenKanban()
            } label: {
                Label("칸반 열기", systemImage: "rectangle.split.3x1")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.08))
                .strokeBorder(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }

    var progressColor: Color {
        if sprintProgress >= 1.0 {
            return .green
        } else if sprintProgress >= 0.7 {
            return .blue
        } else if sprintProgress >= 0.3 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Overall Progress Row (스프린트 없을 때)

struct OverallProgressRow: View {
    let totalTasks: Int
    let completedTasks: Int
    let inProgressTasks: Int
    let progress: Double
    let onOpenKanban: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // 아이콘 + 라벨
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.blue)
                Text("전체 진행률")
                    .font(.headline)
            }

            Divider()
                .frame(height: 20)

            // 진행률 바
            HStack(spacing: 8) {
                ProgressView(value: progress)
                    .frame(width: 120)
                    .tint(progressColor)
                Text("\(Int(progress * 100))%")
                    .font(.callout.monospacedDigit().bold())
                    .foregroundStyle(progressColor)
            }

            // 태스크 카운트
            HStack(spacing: 12) {
                Label("\(completedTasks)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Label("\(inProgressTasks)", systemImage: "arrow.triangle.2.circlepath.circle.fill")
                    .foregroundStyle(.blue)
                Label("\(totalTasks - completedTasks - inProgressTasks)", systemImage: "circle")
                    .foregroundStyle(.secondary)
            }
            .font(.callout)

            Spacer()

            // 칸반 바로가기
            Button {
                onOpenKanban()
            } label: {
                Label("칸반 열기", systemImage: "rectangle.split.3x1")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.08))
                .strokeBorder(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }

    var progressColor: Color {
        if progress >= 1.0 {
            return .green
        } else if progress >= 0.7 {
            return .blue
        } else if progress >= 0.3 {
            return .orange
        } else {
            return .red
        }
    }
}

#Preview {
    ProjectOfficeView(projectId: UUID())
        .environmentObject(CompanyStore())
        .frame(width: 1200, height: 800)
}
