import SwiftUI

/// 프로젝트별 칸반 보드
struct KanbanView: View {
    let projectId: UUID
    @EnvironmentObject var companyStore: CompanyStore
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddTask = false
    @State private var selectedTask: ProjectTask?
    @State private var draggedTask: ProjectTask?

    var project: Project? {
        companyStore.company.projects.first { $0.id == projectId }
    }

    /// 상태별 태스크 분류
    func tasks(for status: TaskStatus) -> [ProjectTask] {
        project?.tasks.filter { $0.status == status } ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            KanbanHeader(
                projectName: project?.name ?? "프로젝트",
                taskCount: project?.tasks.count ?? 0,
                onClose: { dismiss() },
                onAddTask: { showingAddTask = true }
            )

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

/// 칸반 헤더
struct KanbanHeader: View {
    let projectName: String
    let taskCount: Int
    let onClose: () -> Void
    let onAddTask: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(projectName) - 칸반 보드")
                    .font(.title2.bold())
                Text("총 \(taskCount)개 태스크")
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

/// 칸반 열 (상태별)
struct KanbanColumn: View {
    let status: TaskStatus
    let tasks: [ProjectTask]
    let allTasks: [ProjectTask]  // 드래그앤드롭 시 다른 열의 태스크를 찾기 위해
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
        // 모든 태스크에서 찾기 - 다른 열에서 드래그된 경우
        return allTasks.first { $0.id == id }
    }
}

/// 칸반 태스크 카드
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

/// 칸반용 태스크 추가 뷰
struct KanbanAddTaskView: View {
    let projectId: UUID
    @EnvironmentObject var companyStore: CompanyStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var selectedDepartment: DepartmentType = .planning
    @State private var selectedAssignee: UUID?

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
        .frame(width: 400, height: 400)
    }

    private func addTask() {
        let task = ProjectTask(
            title: title,
            description: description,
            status: .todo,
            assigneeId: selectedAssignee,
            departmentType: selectedDepartment
        )
        companyStore.addTask(task, toProject: projectId)
        dismiss()
    }
}

/// 태스크 상세 뷰
struct TaskDetailView: View {
    let task: ProjectTask
    let projectId: UUID
    @EnvironmentObject var companyStore: CompanyStore
    @Environment(\.dismiss) private var dismiss

    @State private var editedTitle: String
    @State private var editedDescription: String
    @State private var editedStatus: TaskStatus
    @State private var editedAssignee: UUID?

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
        .frame(width: 450, height: 550)
    }

    private func saveTask() {
        var updatedTask = task
        updatedTask.title = editedTitle
        updatedTask.description = editedDescription
        updatedTask.status = editedStatus
        updatedTask.assigneeId = editedAssignee
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
