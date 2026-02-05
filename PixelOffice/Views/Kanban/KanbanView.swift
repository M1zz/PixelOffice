import SwiftUI

/// 스프린트 필터 모드
enum SprintFilter: Hashable {
    case all        // 전체 태스크
    case backlog    // 백로그 (스프린트 미배정)
    case sprint(UUID) // 특정 스프린트
}

/// 프로젝트별 칸반 보드
struct KanbanView: View {
    let projectId: UUID
    @EnvironmentObject var companyStore: CompanyStore
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddTask = false
    @State private var selectedTask: ProjectTask?
    @State private var draggedTask: ProjectTask?
    @State private var selectedDepartment: DepartmentType?
    @State private var showingSprintManager = false
    @State private var sprintFilter: SprintFilter = .all

    var project: Project? {
        companyStore.company.projects.first { $0.id == projectId }
    }

    var activeSprint: Sprint? {
        project?.activeSprint
    }

    /// 현재 필터에 해당하는 스프린트
    var displayedSprint: Sprint? {
        switch sprintFilter {
        case .all, .backlog:
            return nil
        case .sprint(let id):
            return project?.sprints.first { $0.id == id }
        }
    }

    /// 필터링된 태스크 (부서 + 스프린트 필터)
    func tasks(for status: TaskStatus) -> [ProjectTask] {
        project?.tasks.filter { task in
            let matchesStatus = task.status == status
            let matchesDept = selectedDepartment == nil || task.departmentType == selectedDepartment
            let matchesSprint: Bool
            switch sprintFilter {
            case .all:
                matchesSprint = true
            case .backlog:
                matchesSprint = task.sprintId == nil
            case .sprint(let id):
                matchesSprint = task.sprintId == id
            }
            return matchesStatus && matchesDept && matchesSprint
        } ?? []
    }

    /// 필터링된 전체 태스크 수
    var filteredTaskCount: Int {
        TaskStatus.allCases.reduce(0) { $0 + tasks(for: $1).count }
    }

    /// 태스크가 있는 부서 목록
    var departmentsWithTasks: [DepartmentType] {
        let allTasks = project?.tasks ?? []
        let types = Set(allTasks.map { $0.departmentType })
        return DepartmentType.allCases.filter { types.contains($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            KanbanHeader(
                projectName: project?.name ?? "프로젝트",
                taskCount: filteredTaskCount,
                totalTaskCount: project?.tasks.count ?? 0,
                isFiltered: selectedDepartment != nil || sprintFilter != .all,
                onClose: { dismiss() },
                onAddTask: { showingAddTask = true }
            )

            Divider()

            // 스프린트 필터 탭
            SprintFilterBar(
                sprints: project?.sprints ?? [],
                allTaskCount: project?.tasks.count ?? 0,
                backlogTaskCount: project?.tasks.filter { $0.sprintId == nil }.count ?? 0,
                sprintFilter: $sprintFilter,
                onManageSprints: { showingSprintManager = true }
            )

            // 스프린트 배너 (특정 스프린트 선택 시)
            if let sprint = displayedSprint {
                SprintBannerView(
                    sprint: sprint,
                    projectId: projectId,
                    onManageSprints: { showingSprintManager = true }
                )
            }

            // 부서 필터 바
            if !departmentsWithTasks.isEmpty {
                DepartmentFilterBar(
                    departments: departmentsWithTasks,
                    selectedDepartment: $selectedDepartment
                )
            }

            Divider()

            // 칸반 보드
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(TaskStatus.allCases, id: \.self) { status in
                        KanbanColumn(
                            status: status,
                            tasks: tasks(for: status),
                            allTasks: project?.tasks ?? [],
                            projectId: projectId,
                            onTaskSelect: { task in
                                selectedTask = task
                            },
                            onTaskDrop: { task, newStatus in
                                moveTask(task, to: newStatus)
                            }
                        )
                    }
                }
                .padding()
            }
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        }
        .frame(minWidth: 1000, minHeight: 600)
        .sheet(isPresented: $showingAddTask) {
            KanbanAddTaskView(projectId: projectId)
        }
        .sheet(item: $selectedTask) { task in
            TaskDetailView(task: task, projectId: projectId)
        }
        .sheet(isPresented: $showingSprintManager) {
            SprintManagerView(projectId: projectId)
        }
        .onAppear {
            if let active = activeSprint {
                sprintFilter = .sprint(active.id)
            }
        }
    }

    private func moveTask(_ task: ProjectTask, to newStatus: TaskStatus) {
        var updatedTask = task
        updatedTask.status = newStatus
        updatedTask.updatedAt = Date()

        if newStatus == .done {
            updatedTask.completedAt = Date()
        }

        companyStore.updateTask(updatedTask, inProject: projectId)
    }
}

// MARK: - KanbanHeader

struct KanbanHeader: View {
    let projectName: String
    let taskCount: Int
    let totalTaskCount: Int
    let isFiltered: Bool
    let onClose: () -> Void
    let onAddTask: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(projectName) - 칸반 보드")
                    .font(.title2.bold())
                HStack(spacing: 4) {
                    if isFiltered {
                        Text("\(taskCount)/\(totalTaskCount)개 태스크 (필터 적용)")
                    } else {
                        Text("총 \(totalTaskCount)개 태스크")
                    }
                }
                .font(.body)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                onAddTask()
            } label: {
                Label("태스크 추가", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
}

// MARK: - SprintFilterBar

struct SprintFilterBar: View {
    let sprints: [Sprint]
    let allTaskCount: Int
    let backlogTaskCount: Int
    @Binding var sprintFilter: SprintFilter
    let onManageSprints: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                // 전체
                SprintFilterChip(
                    label: "전체",
                    icon: "tray.full",
                    count: allTaskCount,
                    isSelected: sprintFilter == .all
                ) {
                    sprintFilter = .all
                }

                // 백로그
                SprintFilterChip(
                    label: "백로그",
                    icon: "tray",
                    count: backlogTaskCount,
                    isSelected: sprintFilter == .backlog
                ) {
                    sprintFilter = .backlog
                }

                if !sprints.isEmpty {
                    Divider()
                        .frame(height: 20)
                }

                // 각 스프린트
                ForEach(sprints) { sprint in
                    SprintFilterChip(
                        label: sprint.name,
                        icon: sprint.isActive ? "flag.fill" : "flag",
                        count: nil,
                        isActive: sprint.isActive,
                        isSelected: sprintFilter == .sprint(sprint.id)
                    ) {
                        sprintFilter = .sprint(sprint.id)
                    }
                }

                Divider()
                    .frame(height: 20)

                // 스프린트 관리 버튼
                Button {
                    onManageSprints()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
}

struct SprintFilterChip: View {
    let label: String
    let icon: String
    var count: Int?
    var isActive: Bool = false
    let isSelected: Bool
    let action: () -> Void

    var chipColor: Color {
        isActive ? .orange : .accentColor
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(isActive && isSelected ? .orange : isSelected ? .accentColor : .secondary)
                Text(label)
                    .font(.caption)
                    .lineLimit(1)
                if let count = count {
                    Text("\(count)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(isSelected ? chipColor : Color.secondary.opacity(0.6))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? chipColor.opacity(0.15) : Color(NSColor.controlBackgroundColor))
            .foregroundStyle(isSelected ? chipColor : .secondary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? chipColor.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - SprintBannerView

struct SprintBannerView: View {
    let sprint: Sprint?
    let projectId: UUID
    let onManageSprints: () -> Void
    @EnvironmentObject var companyStore: CompanyStore

    var project: Project? {
        companyStore.company.projects.first { $0.id == projectId }
    }

    var sprintTasks: [ProjectTask] {
        guard let sprint = sprint else { return [] }
        return project?.tasks.filter { $0.sprintId == sprint.id } ?? []
    }

    var sprintProgress: Double {
        guard !sprintTasks.isEmpty else { return 0 }
        let completed = sprintTasks.filter { $0.status == .done }.count
        return Double(completed) / Double(sprintTasks.count)
    }

    var body: some View {
        if let sprint = sprint {
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    // 스프린트명 + 버전
                    HStack(spacing: 6) {
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

                    Spacer()

                    // 진행률
                    HStack(spacing: 6) {
                        ProgressView(value: sprintProgress)
                            .frame(width: 100)
                        Text("\(Int(sprintProgress * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    // 태스크 수
                    let completed = sprintTasks.filter { $0.status == .done }.count
                    Text("\(completed)/\(sprintTasks.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)

                    Divider()
                        .frame(height: 16)

                    // 남은 일수
                    HStack(spacing: 4) {
                        if sprint.isOverdue {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text("마감 초과")
                                .foregroundStyle(.red)
                        } else {
                            Image(systemName: "calendar")
                                .foregroundStyle(.secondary)
                            Text("D-\(sprint.remainingDays)")
                                .foregroundStyle(sprint.remainingDays <= 3 ? .red : .secondary)
                        }
                    }
                    .font(.caption)

                    // 관리 버튼
                    Button {
                        onManageSprints()
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.body)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }

                // 목표 태스크
                if !sprint.goalTaskIds.isEmpty {
                    let goalTasks = sprint.goalTaskIds.compactMap { goalId in
                        project?.tasks.first { $0.id == goalId }
                    }
                    if !goalTasks.isEmpty {
                        HStack(alignment: .top, spacing: 4) {
                            Text("목표:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(goalTasks) { task in
                                    HStack(spacing: 4) {
                                        Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                                            .font(.caption2)
                                            .foregroundStyle(task.status == .done ? .green : .secondary)
                                        Text(task.title)
                                            .font(.caption)
                                            .foregroundStyle(task.status == .done ? .secondary : .primary)
                                            .strikethrough(task.status == .done)
                                    }
                                }
                            }
                            Spacer()
                        }
                    }
                }

                // 텍스트 목표
                if !sprint.goal.isEmpty {
                    HStack {
                        Text("목표: \(sprint.goal)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.05))
        } else {
            // 스프린트 없을 때
            HStack {
                Image(systemName: "flag")
                    .foregroundStyle(.secondary)
                Text("활성 스프린트가 없습니다")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("스프린트 만들기") {
                    onManageSprints()
                }
                .font(.caption)
                .buttonStyle(.link)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }
}

// MARK: - DepartmentFilterBar

struct DepartmentFilterBar: View {
    let departments: [DepartmentType]
    @Binding var selectedDepartment: DepartmentType?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                FilterChip(
                    label: "전체",
                    icon: "square.grid.2x2",
                    color: .gray,
                    isSelected: selectedDepartment == nil
                ) {
                    selectedDepartment = nil
                }

                ForEach(departments, id: \.self) { dept in
                    FilterChip(
                        label: dept.rawValue,
                        icon: dept.icon,
                        color: dept.color,
                        isSelected: selectedDepartment == dept
                    ) {
                        selectedDepartment = (selectedDepartment == dept) ? nil : dept
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }
}

struct FilterChip: View {
    let label: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(label)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? color.opacity(0.2) : Color(NSColor.controlBackgroundColor))
            .foregroundStyle(isSelected ? color : .secondary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? color.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - SprintManagerView

struct SprintManagerView: View {
    let projectId: UUID
    @EnvironmentObject var companyStore: CompanyStore
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddSprint = false

    var project: Project? {
        companyStore.company.projects.first { $0.id == projectId }
    }

    var sprints: [Sprint] {
        project?.sprints ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text("스프린트 관리")
                    .font(.headline)
                Spacer()
                Button {
                    showingAddSprint = true
                } label: {
                    Label("추가", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            if sprints.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "flag.slash")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("스프린트가 없습니다")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Text("새 스프린트를 만들어 태스크를 관리하세요")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(sprints) { sprint in
                        SprintRowView(
                            sprint: sprint,
                            projectId: projectId,
                            taskCount: taskCount(for: sprint)
                        )
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(width: 500, height: 400)
        .sheet(isPresented: $showingAddSprint) {
            AddSprintView(projectId: projectId)
        }
    }

    private func taskCount(for sprint: Sprint) -> Int {
        project?.tasks.filter { $0.sprintId == sprint.id }.count ?? 0
    }
}

struct SprintRowView: View {
    let sprint: Sprint
    let projectId: UUID
    let taskCount: Int
    @EnvironmentObject var companyStore: CompanyStore

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(sprint.name)
                        .font(.body.weight(.medium))
                    if sprint.isActive {
                        Text("활성")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.green.opacity(0.2))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                    if !sprint.version.isEmpty {
                        Text(sprint.version)
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                }
                HStack(spacing: 8) {
                    Text("\(sprint.startDate.formatted(date: .abbreviated, time: .omitted)) ~ \(sprint.endDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(taskCount)개 태스크")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if !sprint.isActive {
                Button("활성화") {
                    companyStore.activateSprint(sprint.id, inProject: projectId)
                }
                .controlSize(.small)
            } else {
                Button("비활성화") {
                    // 비활성화: 모든 스프린트를 비활성으로
                    var updated = sprint
                    updated.isActive = false
                    companyStore.updateSprint(updated, inProject: projectId)
                }
                .controlSize(.small)
            }

            Button(role: .destructive) {
                companyStore.removeSprint(sprint.id, fromProject: projectId)
            } label: {
                Image(systemName: "trash")
            }
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - AddSprintView

struct AddSprintView: View {
    let projectId: UUID
    @EnvironmentObject var companyStore: CompanyStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var goal = ""
    @State private var version = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .weekOfYear, value: 2, to: Date()) ?? Date()
    @State private var activateImmediately = true
    @State private var selectedGoalTaskIds: Set<UUID> = []

    var project: Project? {
        companyStore.company.projects.first { $0.id == projectId }
    }

    /// 백로그 태스크 (스프린트에 배정되지 않은 태스크)
    var backlogTasks: [ProjectTask] {
        project?.tasks.filter { $0.sprintId == nil } ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("새 스프린트")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            Form {
                Section("기본 정보") {
                    TextField("스프린트 이름", text: $name)
                    TextField("목표", text: $goal)
                    TextField("버전 (예: v1.0.0)", text: $version)
                }

                Section {
                    if backlogTasks.isEmpty {
                        Text("백로그에 태스크가 없습니다")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(backlogTasks) { task in
                            HStack(spacing: 8) {
                                Image(systemName: selectedGoalTaskIds.contains(task.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedGoalTaskIds.contains(task.id) ? .blue : .secondary)
                                Text(task.title)
                                    .lineLimit(1)
                                Spacer()
                                Text(task.departmentType.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(task.departmentType.color)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedGoalTaskIds.contains(task.id) {
                                    selectedGoalTaskIds.remove(task.id)
                                } else {
                                    selectedGoalTaskIds.insert(task.id)
                                }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("목표 태스크 (백로그에서 선택)")
                        Spacer()
                        if !backlogTasks.isEmpty {
                            Text("\(selectedGoalTaskIds.count)개 선택")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("기간") {
                    DatePicker("시작일", selection: $startDate, displayedComponents: .date)
                    DatePicker("종료일", selection: $endDate, displayedComponents: .date)
                }

                Section {
                    Toggle("즉시 활성화", isOn: $activateImmediately)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Button("취소") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("추가") {
                    addSprint()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty)
            }
            .padding()
        }
        .frame(width: 400, height: 520)
    }

    private func addSprint() {
        let sprint = Sprint(
            name: name,
            goal: goal,
            version: version,
            startDate: startDate,
            endDate: endDate,
            isActive: activateImmediately,
            goalTaskIds: Array(selectedGoalTaskIds)
        )

        companyStore.addSprint(sprint, toProject: projectId)

        // 선택된 목표 태스크들을 새 스프린트에 배정
        for taskId in selectedGoalTaskIds {
            companyStore.assignTaskToSprint(taskId: taskId, sprintId: sprint.id, projectId: projectId)
        }

        if activateImmediately {
            companyStore.activateSprint(sprint.id, inProject: projectId)
        }

        dismiss()
    }
}

// MARK: - KanbanColumn

struct KanbanColumn: View {
    let status: TaskStatus
    let tasks: [ProjectTask]
    let allTasks: [ProjectTask]
    let projectId: UUID
    let onTaskSelect: (ProjectTask) -> Void
    let onTaskDrop: (ProjectTask, TaskStatus) -> Void

    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 열 헤더
            HStack {
                Circle()
                    .fill(status.color)
                    .frame(width: 10, height: 10)
                Text(status.rawValue)
                    .font(.headline)
                Spacer()
                Text("\(tasks.count)")
                    .font(.body)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(status.color.opacity(0.2))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(status.color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // 태스크 카드들
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(tasks) { task in
                        KanbanTaskCard(task: task, projectId: projectId)
                            .onTapGesture {
                                onTaskSelect(task)
                            }
                            .draggable(task.id.uuidString) {
                                KanbanTaskCard(task: task, projectId: projectId)
                                    .frame(width: 250)
                                    .opacity(0.8)
                            }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .frame(width: 280)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isTargeted ? status.color.opacity(0.15) : Color(NSColor.controlBackgroundColor))
                .strokeBorder(isTargeted ? status.color : Color.clear, lineWidth: 2)
        )
        .dropDestination(for: String.self) { items, _ in
            guard let taskIdString = items.first,
                  let taskId = UUID(uuidString: taskIdString),
                  let task = tasks.first(where: { $0.id == taskId }) ?? findTask(byId: taskId) else {
                return false
            }
            onTaskDrop(task, status)
            return true
        } isTargeted: { targeted in
            isTargeted = targeted
        }
    }

    private func findTask(byId id: UUID) -> ProjectTask? {
        return allTasks.first { $0.id == id }
    }
}

// MARK: - KanbanTaskCard

struct KanbanTaskCard: View {
    let task: ProjectTask
    let projectId: UUID
    @EnvironmentObject var companyStore: CompanyStore

    var assignee: ProjectEmployee? {
        guard let assigneeId = task.assigneeId else { return nil }
        return companyStore.getProjectEmployee(byId: assigneeId, inProject: projectId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 제목
            Text(task.title)
                .font(.body)
                .fontWeight(.medium)
                .lineLimit(2)

            // 설명 (있는 경우)
            if !task.description.isEmpty {
                Text(task.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Divider()

            // 메타 정보
            HStack {
                // 부서
                HStack(spacing: 4) {
                    Image(systemName: task.departmentType.icon)
                        .font(.caption2)
                    Text(task.departmentType.rawValue)
                        .font(.caption)
                }
                .foregroundStyle(task.departmentType.color)

                Spacer()

                // 담당자
                if let assignee = assignee {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(assignee.status.color)
                            .frame(width: 6, height: 6)
                        Text(assignee.name)
                            .font(.caption)
                    }
                } else {
                    Text("미배정")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // 워크플로우 진행 상황 (있는 경우)
            if !task.workflowHistory.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.right.circle")
                        .font(.caption2)
                    Text("\(task.workflowHistory.count)단계 진행")
                        .font(.caption)
                }
                .foregroundStyle(.purple)
            }
        }
        .padding(12)
        .background(Color(NSColor.textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}

// MARK: - KanbanAddTaskView

struct KanbanAddTaskView: View {
    let projectId: UUID
    @EnvironmentObject var companyStore: CompanyStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var selectedDepartment: DepartmentType = .planning
    @State private var selectedAssignee: UUID?
    @State private var selectedSprintId: UUID?

    var project: Project? {
        companyStore.company.projects.first { $0.id == projectId }
    }

    var availableEmployees: [ProjectEmployee] {
        project?.departments.first { $0.type == selectedDepartment }?.employees ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text("새 태스크 추가")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // 폼
            Form {
                Section("기본 정보") {
                    TextField("제목", text: $title)

                    TextField("설명", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("배정") {
                    Picker("부서", selection: $selectedDepartment) {
                        ForEach(DepartmentType.allCases.filter { $0 != .general }, id: \.self) { dept in
                            Label(dept.rawValue, systemImage: dept.icon)
                                .tag(dept)
                        }
                    }

                    Picker("담당자", selection: $selectedAssignee) {
                        Text("미배정").tag(nil as UUID?)
                        ForEach(availableEmployees) { employee in
                            Text(employee.name).tag(employee.id as UUID?)
                        }
                    }

                    Picker("스프린트", selection: $selectedSprintId) {
                        Text("없음").tag(nil as UUID?)
                        ForEach(project?.sprints ?? []) { sprint in
                            HStack {
                                Text(sprint.name)
                                if sprint.isActive {
                                    Text("(활성)")
                                }
                            }
                            .tag(sprint.id as UUID?)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            Divider()

            // 버튼
            HStack {
                Button("취소") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("추가") {
                    addTask()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.isEmpty)
            }
            .padding()
        }
        .frame(width: 400, height: 450)
        .onAppear {
            // 활성 스프린트를 기본값으로 설정
            selectedSprintId = project?.activeSprint?.id
        }
    }

    private func addTask() {
        let task = ProjectTask(
            title: title,
            description: description,
            status: .todo,
            assigneeId: selectedAssignee,
            departmentType: selectedDepartment,
            sprintId: selectedSprintId
        )
        companyStore.addTask(task, toProject: projectId)
        dismiss()
    }
}

// MARK: - TaskDetailView

struct TaskDetailView: View {
    let task: ProjectTask
    let projectId: UUID
    @EnvironmentObject var companyStore: CompanyStore
    @Environment(\.dismiss) private var dismiss

    @State private var editedTitle: String
    @State private var editedDescription: String
    @State private var editedStatus: TaskStatus
    @State private var editedAssignee: UUID?
    @State private var editedSprintId: UUID?

    var project: Project? {
        companyStore.company.projects.first { $0.id == projectId }
    }

    var availableEmployees: [ProjectEmployee] {
        project?.departments.first { $0.type == task.departmentType }?.employees ?? []
    }

    init(task: ProjectTask, projectId: UUID) {
        self.task = task
        self.projectId = projectId
        _editedTitle = State(initialValue: task.title)
        _editedDescription = State(initialValue: task.description)
        _editedStatus = State(initialValue: task.status)
        _editedAssignee = State(initialValue: task.assigneeId)
        _editedSprintId = State(initialValue: task.sprintId)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("태스크 상세")
                        .font(.headline)
                    HStack(spacing: 4) {
                        Image(systemName: task.departmentType.icon)
                        Text(task.departmentType.rawValue)
                    }
                    .font(.caption)
                    .foregroundStyle(task.departmentType.color)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // 내용
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 제목
                    VStack(alignment: .leading, spacing: 4) {
                        Text("제목")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("제목", text: $editedTitle)
                            .textFieldStyle(.roundedBorder)
                    }

                    // 설명
                    VStack(alignment: .leading, spacing: 4) {
                        Text("설명")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $editedDescription)
                            .frame(minHeight: 80)
                            .padding(4)
                            .background(Color(NSColor.textBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.2))
                            )
                    }

                    // 상태
                    VStack(alignment: .leading, spacing: 4) {
                        Text("상태")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("상태", selection: $editedStatus) {
                            ForEach(TaskStatus.allCases, id: \.self) { status in
                                Label(status.rawValue, systemImage: status.icon)
                                    .tag(status)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // 담당자
                    VStack(alignment: .leading, spacing: 4) {
                        Text("담당자")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("담당자", selection: $editedAssignee) {
                            Text("미배정").tag(nil as UUID?)
                            ForEach(availableEmployees) { employee in
                                Text(employee.name).tag(employee.id as UUID?)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    // 스프린트
                    VStack(alignment: .leading, spacing: 4) {
                        Text("스프린트")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("스프린트", selection: $editedSprintId) {
                            Text("없음").tag(nil as UUID?)
                            ForEach(project?.sprints ?? []) { sprint in
                                HStack {
                                    Text(sprint.name)
                                    if sprint.isActive {
                                        Text("(활성)")
                                    }
                                }
                                .tag(sprint.id as UUID?)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    Divider()

                    // 메타 정보
                    VStack(alignment: .leading, spacing: 8) {
                        Text("정보")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack {
                            Text("생성일")
                            Spacer()
                            Text(task.createdAt.formatted())
                        }
                        .font(.caption)

                        HStack {
                            Text("수정일")
                            Spacer()
                            Text(task.updatedAt.formatted())
                        }
                        .font(.caption)

                        if let completedAt = task.completedAt {
                            HStack {
                                Text("완료일")
                                Spacer()
                                Text(completedAt.formatted())
                            }
                            .font(.caption)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    // 워크플로우 히스토리
                    if !task.workflowHistory.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("워크플로우 히스토리")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            ForEach(task.workflowHistory) { transition in
                                HStack {
                                    Image(systemName: transition.fromDepartment.icon)
                                        .foregroundStyle(transition.fromDepartment.color)
                                    Text(transition.fromDepartment.rawValue)
                                    Image(systemName: "arrow.right")
                                        .font(.caption)
                                    Image(systemName: transition.toDepartment.icon)
                                        .foregroundStyle(transition.toDepartment.color)
                                    Text(transition.toDepartment.rawValue)
                                    Spacer()
                                    Text(transition.transitionDate.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .font(.caption)
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding()
            }

            Divider()

            // 버튼
            HStack {
                Button(role: .destructive) {
                    companyStore.removeTask(task.id, fromProject: projectId)
                    dismiss()
                } label: {
                    Label("삭제", systemImage: "trash")
                }

                Spacer()

                Button("취소") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("저장") {
                    saveTask()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(editedTitle.isEmpty)
            }
            .padding()
        }
        .frame(width: 450, height: 600)
    }

    private func saveTask() {
        var updatedTask = task
        updatedTask.title = editedTitle
        updatedTask.description = editedDescription
        updatedTask.status = editedStatus
        updatedTask.assigneeId = editedAssignee
        updatedTask.sprintId = editedSprintId
        updatedTask.updatedAt = Date()

        if editedStatus == .done && task.status != .done {
            updatedTask.completedAt = Date()
        }

        companyStore.updateTask(updatedTask, inProject: projectId)
        dismiss()
    }
}

#Preview {
    KanbanView(projectId: UUID())
        .environmentObject(CompanyStore())
}
