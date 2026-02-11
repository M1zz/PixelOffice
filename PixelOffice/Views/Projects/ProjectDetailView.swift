import SwiftUI

struct ProjectDetailView: View {
    let project: Project
    @EnvironmentObject var companyStore: CompanyStore
    @State private var showingAddTask = false
    @State private var selectedTask: ProjectTask?
    @State private var showingConversation = false
    
    var body: some View {
        HSplitView {
            // Main Content
            VStack(spacing: 0) {
                // Header
                ProjectHeader(project: project)
                
                Divider()
                
                // Task Board
                TaskBoardView(
                    project: project,
                    selectedTask: $selectedTask,
                    showingConversation: $showingConversation
                )
            }
            .frame(minWidth: 600)
            
            // Task Detail / Conversation
            if let task = selectedTask {
                if showingConversation {
                    ConversationView(
                        task: task,
                        projectId: project.id,
                        onClose: { showingConversation = false }
                    )
                    .frame(width: 450)
                } else {
                    TaskDetailPanel(
                        task: task,
                        projectId: project.id,
                        onClose: { selectedTask = nil },
                        onStartConversation: { showingConversation = true }
                    )
                    .frame(width: 350)
                }
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    showingAddTask = true
                } label: {
                    Label("태스크 추가", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskView(projectId: project.id)
        }
    }
}

struct ProjectHeader: View {
    let project: Project
    @EnvironmentObject var companyStore: CompanyStore
    @State private var isEditingStatus = false
    @State private var showingProjectInfo = false
    @State private var showingSourcePathEditor = false
    @State private var editingSourcePath = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.title.bold())

                    if !project.description.isEmpty {
                        Text(project.description)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // 프로젝트 정보 버튼
                Button {
                    showingProjectInfo = true
                } label: {
                    Label("프로젝트 정보", systemImage: "info.circle")
                }
                .buttonStyle(.bordered)

                // Status Picker
                Menu {
                    ForEach(ProjectStatus.allCases, id: \.self) { status in
                        Button {
                            var updatedProject = project
                            updatedProject.status = status
                            companyStore.updateProject(updatedProject)
                        } label: {
                            Label(status.rawValue, systemImage: status.icon)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: project.status.icon)
                        Text(project.status.rawValue)
                        Image(systemName: "chevron.down")
                            .font(.callout)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(project.status.color.opacity(0.2))
                    .foregroundStyle(project.status.color)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            
            // Source Path
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
                    Text("소스 경로 미설정")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
                
                Spacer()
                
                Button {
                    editingSourcePath = project.sourcePath ?? ""
                    showingSourcePathEditor = true
                } label: {
                    Text(project.sourcePath == nil ? "설정" : "변경")
                        .font(.callout)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            // Progress Bar
            HStack {
                ProgressView(value: project.progress)
                    .tint(project.status.color)
                
                Text("\(Int(project.progress * 100))%")
                    .font(.callout.bold())
                    .frame(width: 40)
            }
            
            // Stats Row
            HStack(spacing: 20) {
                ProjectStatItem(
                    icon: "checkmark.circle.fill",
                    label: "완료",
                    value: "\(project.completedTasksCount)",
                    color: .green
                )
                ProjectStatItem(
                    icon: "play.circle.fill",
                    label: "진행 중",
                    value: "\(project.inProgressTasksCount)",
                    color: .blue
                )
                ProjectStatItem(
                    icon: "circle",
                    label: "대기",
                    value: "\(project.pendingTasksCount)",
                    color: .gray
                )
                
                Divider()
                    .frame(height: 20)
                
                ProjectStatItem(
                    icon: project.priority.icon,
                    label: "우선순위",
                    value: project.priority.rawValue,
                    color: project.priority.color
                )
                
                if let deadline = project.deadline {
                    ProjectStatItem(
                        icon: "calendar",
                        label: "마감일",
                        value: deadline.formatted(date: .abbreviated, time: .omitted),
                        color: deadline < Date() ? .red : .secondary
                    )
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .sheet(isPresented: $showingProjectInfo) {
            ProjectInfoEditorView(projectName: project.name, isPresented: $showingProjectInfo)
        }
        .sheet(isPresented: $showingSourcePathEditor) {
            SourcePathEditorSheet(
                projectId: project.id,
                sourcePath: $editingSourcePath,
                isPresented: $showingSourcePathEditor
            )
            .environmentObject(companyStore)
        }
    }
}

// MARK: - Source Path Editor Sheet

struct SourcePathEditorSheet: View {
    let projectId: UUID
    @Binding var sourcePath: String
    @Binding var isPresented: Bool
    @EnvironmentObject var companyStore: CompanyStore
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("소스 코드 경로 설정")
                    .font(.title2.bold())
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            VStack(alignment: .leading, spacing: 16) {
                Text("AI가 코드를 수정할 때 사용할 프로젝트 폴더를 선택하세요.")
                    .foregroundStyle(.secondary)
                
                HStack {
                    TextField("프로젝트 폴더 경로", text: $sourcePath)
                        .textFieldStyle(.roundedBorder)
                        .font(.body.monospaced())
                    
                    Button("선택...") {
                        selectFolder()
                    }
                    .buttonStyle(.bordered)
                }
                
                if !sourcePath.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text(sourcePath)
                            .font(.callout.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            
            Spacer()
            
            Divider()
            
            // Footer
            HStack {
                Spacer()
                
                Button("취소") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                
                Button("저장") {
                    saveSourcePath()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 500, height: 300)
    }
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.message = "프로젝트 소스 코드 폴더를 선택하세요"
        
        if panel.runModal() == .OK, let url = panel.url {
            sourcePath = url.path
        }
    }
    
    private func saveSourcePath() {
        if var project = companyStore.company.projects.first(where: { $0.id == projectId }) {
            project.sourcePath = sourcePath.isEmpty ? nil : sourcePath
            companyStore.updateProject(project)
        }
        isPresented = false
    }
}

struct ProjectStatItem: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.callout.bold())
            }
        }
    }
}

struct TaskBoardView: View {
    let project: Project
    @Binding var selectedTask: ProjectTask?
    @Binding var showingConversation: Bool
    
    let columns: [TaskStatus] = [.backlog, .todo, .inProgress, .done, .needsReview, .rejected]
    
    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(columns, id: \.self) { status in
                    TaskColumn(
                        status: status,
                        tasks: project.tasks.filter { $0.status == status },
                        projectId: project.id,
                        selectedTask: $selectedTask,
                        showingConversation: $showingConversation
                    )
                }
            }
            .padding()
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct TaskColumn: View {
    let status: TaskStatus
    let tasks: [ProjectTask]
    let projectId: UUID
    @Binding var selectedTask: ProjectTask?
    @Binding var showingConversation: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Column Header
            HStack {
                Image(systemName: status.icon)
                    .foregroundStyle(status.color)
                Text(status.rawValue)
                    .font(.headline)
                Spacer()
                Text("\(tasks.count)")
                    .font(.callout)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.secondary.opacity(0.2))
                    .clipShape(Capsule())
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(status.color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Tasks
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(tasks) { task in
                        TaskCardView(
                            task: task,
                            projectId: projectId,
                            isSelected: selectedTask?.id == task.id,
                            onSelect: {
                                selectedTask = task
                                showingConversation = false
                            }
                        )
                    }
                }
            }
        }
        .frame(width: 280)
    }
}

struct TaskCardView: View {
    let task: ProjectTask
    let projectId: UUID
    let isSelected: Bool
    let onSelect: () -> Void
    
    @EnvironmentObject var companyStore: CompanyStore
    @State private var isHovering = false
    
    var assignee: Employee? {
        guard let id = task.assigneeId else { return nil }
        return companyStore.getEmployee(byId: id)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            Text(task.title)
                .font(.subheadline.bold())
                .lineLimit(2)
            
            // Department
            HStack(spacing: 4) {
                Image(systemName: task.departmentType.icon)
                Text(task.departmentType.rawValue)
            }
            .font(.callout)
            .foregroundStyle(task.departmentType.color)
            
            // Description preview
            if !task.description.isEmpty {
                Text(task.description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            Divider()
            
            // Footer
            HStack {
                // Assignee
                if let assignee = assignee {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(assignee.aiType.color)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Circle()
                                    .fill(assignee.status.color)
                                    .frame(width: 6, height: 6)
                                    .offset(x: 5, y: 5)
                            )
                        Text(assignee.name)
                            .font(.callout)
                            .lineLimit(1)
                    }
                } else {
                    Text("미배정")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Conversation count
                if !task.conversation.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "bubble.left.and.bubble.right")
                        Text("\(task.conversation.count)")
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(isSelected ? AnyShapeStyle(Color.accentColor.opacity(0.1)) : AnyShapeStyle(.regularMaterial))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
    }
}

struct TaskDetailPanel: View {
    let task: ProjectTask
    let projectId: UUID
    let onClose: () -> Void
    let onStartConversation: () -> Void
    
    @EnvironmentObject var companyStore: CompanyStore
    @State private var selectedEmployeeId: UUID?
    
    var assignee: Employee? {
        guard let id = task.assigneeId else { return nil }
        return companyStore.getEmployee(byId: id)
    }
    
    var availableEmployees: [Employee] {
        companyStore.company.allEmployees.filter { $0.status != .offline }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("태스크 상세")
                    .font(.headline)
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
                    // Title & Status
                    VStack(alignment: .leading, spacing: 8) {
                        Text(task.title)
                            .font(.title3.bold())
                        
                        HStack {
                            Image(systemName: task.status.icon)
                                .foregroundStyle(task.status.color)
                            Text(task.status.rawValue)
                            
                            Spacer()
                            
                            Image(systemName: task.departmentType.icon)
                                .foregroundStyle(task.departmentType.color)
                            Text(task.departmentType.rawValue)
                        }
                        .font(.callout)
                    }
                    
                    Divider()
                    
                    // Description
                    if !task.description.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("설명")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Text(task.description)
                                .font(.callout)
                        }
                    }
                    
                    // Prompt
                    if !task.prompt.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("프롬프트")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Text(task.prompt)
                                .font(.callout)
                                .padding(8)
                                .background(.regularMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    
                    Divider()
                    
                    // Assignee
                    VStack(alignment: .leading, spacing: 8) {
                        Text("담당자")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        
                        if let assignee = assignee {
                            EmployeeCard(employee: assignee)
                        } else {
                            Picker("직원 선택", selection: $selectedEmployeeId) {
                                Text("선택...").tag(nil as UUID?)
                                ForEach(availableEmployees) { employee in
                                    HStack {
                                        Image(systemName: employee.aiType.icon)
                                        Text(employee.name)
                                    }
                                    .tag(employee.id as UUID?)
                                }
                            }
                            .onChange(of: selectedEmployeeId) { _, newValue in
                                if let employeeId = newValue {
                                    companyStore.assignTaskToEmployee(
                                        taskId: task.id,
                                        employeeId: employeeId,
                                        projectId: projectId
                                    )
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Actions
                    VStack(spacing: 8) {
                        if task.status == .todo && task.isAssigned {
                            Button {
                                companyStore.startTask(taskId: task.id, projectId: projectId)
                            } label: {
                                Label("작업 시작", systemImage: "play.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        
                        if task.status == .inProgress {
                            Button {
                                onStartConversation()
                            } label: {
                                Label("대화 열기", systemImage: "bubble.left.and.bubble.right.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button {
                                companyStore.completeTask(taskId: task.id, projectId: projectId)
                            } label: {
                                Label("완료 처리", systemImage: "checkmark")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        if task.status == .done {
                            Label("완료됨", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                    }
                    
                    // Outputs
                    if !task.outputs.isEmpty {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("산출물")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            
                            ForEach(task.outputs) { output in
                                HStack {
                                    Image(systemName: output.type.icon)
                                    Text(output.fileName ?? output.type.rawValue)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(output.createdAt.formatted(date: .omitted, time: .shortened))
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(8)
                                .background(.regularMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

#Preview {
    let store = CompanyStore()
    store.addProject(Project(
        name: "테스트 프로젝트",
        description: "테스트 설명입니다",
        tasks: [
            ProjectTask(title: "기획서 작성", departmentType: .planning),
            ProjectTask(title: "디자인 시안", status: .inProgress, departmentType: .design),
            ProjectTask(title: "개발", status: .done, departmentType: .development)
        ]
    ))
    
    return ProjectDetailView(project: store.company.projects[0])
        .environmentObject(store)
        .frame(width: 1000, height: 700)
}
