import SwiftUI

struct ProjectListView: View {
    @EnvironmentObject var companyStore: CompanyStore
    @Binding var selectedProjectId: UUID?
    @Binding var selectedTab: SidebarItem
    @State private var showingAddProject = false
    @State private var searchText = ""
    @State private var filterStatus: ProjectStatus?
    
    var filteredProjects: [Project] {
        var projects = companyStore.company.projects
        
        if !searchText.isEmpty {
            projects = projects.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        if let status = filterStatus {
            projects = projects.filter { $0.status == status }
        }
        
        return projects.sorted { $0.updatedAt > $1.updatedAt }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("입주사")
                    .font(.largeTitle.bold())
                
                Spacer()
                
                Button {
                    showingAddProject = true
                } label: {
                    Label("새 입주사", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            
            // Filters
            HStack {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("검색...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .frame(maxWidth: 300)
                
                Spacer()
                
                // Status Filter
                Picker("상태", selection: $filterStatus) {
                    Text("전체").tag(nil as ProjectStatus?)
                    ForEach(ProjectStatus.allCases, id: \.self) { status in
                        Label(status.rawValue, systemImage: status.icon)
                            .tag(status as ProjectStatus?)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 150)
            }
            .padding(.horizontal)
            .padding(.bottom)
            
            Divider()
            
            // Projects Grid
            if filteredProjects.isEmpty {
                EmptyProjectsView(showingAddProject: $showingAddProject)
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 300, maximum: 400), spacing: 16)
                    ], spacing: 16) {
                        ForEach(filteredProjects) { project in
                            ProjectCard(project: project)
                                .onTapGesture {
                                    selectedProjectId = project.id
                                    selectedTab = .projectOffice(project.id)
                                }
                        }
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showingAddProject) {
            AddProjectView()
        }
    }
}

struct ProjectCard: View {
    let project: Project
    @EnvironmentObject var companyStore: CompanyStore
    @Environment(\.openWindow) private var openWindow
    @State private var isHovering = false
    @State private var showingDeleteConfirmation = false
    @State private var showingRenameSheet = false
    @State private var newName = ""
    @State private var xcodeVersion: String?
    @State private var pipelineStats = DataPathService.PipelineStats()

    var activeSprint: Sprint? { project.sprints.first { $0.isActive } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(project.name)
                            .font(.headline)
                            .lineLimit(1)

                        if let version = xcodeVersion {
                            Text("v\(version)")
                                .font(.callout.monospaced())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.15))
                                .foregroundStyle(Color.accentColor)
                                .clipShape(Capsule())
                        }
                    }

                    Text(project.description.isEmpty ? "설명 없음" : project.description)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                // 스프린트 진행 중이면 스프린트 배지, 아니면 프로젝트 상태
                if let sprint = activeSprint {
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                            Text("스프린트 진행중")
                        }
                        .font(.callout.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.2))
                        .foregroundStyle(Color.blue)
                        .clipShape(Capsule())

                        Text(sprint.remainingDays > 0 ? "D-\(sprint.remainingDays)" : "기간 초과")
                            .font(.caption)
                            .foregroundStyle(sprint.isOverdue ? .red : .secondary)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: project.status.icon)
                        Text(project.status.rawValue)
                    }
                    .font(.callout)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(project.status.color.opacity(0.2))
                    .foregroundStyle(project.status.color)
                    .clipShape(Capsule())
                }
            }

            // 스프린트 목표 (진행 중일 때)
            if let sprint = activeSprint, !sprint.goal.isEmpty {
                Text(sprint.goal)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Progress
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("태스크 진행률")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(project.progress * 100))%")
                        .font(.callout.bold())
                }

                ProgressView(value: project.progress)
                    .tint(activeSprint != nil ? .blue : project.status.color)
            }

            Divider()

            // Stats: 태스크 + 파이프라인
            HStack {
                // 태스크 통계
                StatBadge(icon: "checkmark.circle.fill", value: "\(project.completedTasksCount)", color: .green)
                StatBadge(icon: "play.circle.fill", value: "\(project.inProgressTasksCount)", color: .blue)
                StatBadge(icon: "circle", value: "\(project.pendingTasksCount)", color: .gray)

                if pipelineStats.total > 0 {
                    Divider().frame(height: 14)

                    // 파이프라인 통계
                    StatBadge(icon: "checkmark.circle.fill", value: "\(pipelineStats.completed)", color: .green)
                        .help("파이프라인 성공")
                    StatBadge(icon: "xmark.circle.fill", value: "\(pipelineStats.failed)", color: .red)
                        .help("파이프라인 실패")
                    if pipelineStats.running > 0 {
                        StatBadge(icon: "gearshape.2.fill", value: "\(pipelineStats.running)", color: .orange)
                            .help("파이프라인 실행 중")
                    }
                }

                Spacer()

                // 칸반 보드 버튼
                Button {
                    openWindow(id: "kanban", value: project.id)
                } label: {
                    Image(systemName: "rectangle.split.3x1")
                        .font(.body)
                }
                .buttonStyle(.bordered)
                .help("칸반 보드 열기")
            }

            // Tags
            if !project.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(project.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.callout)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.secondary.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovering ? project.status.color.opacity(0.5) : Color.clear, lineWidth: 2)
        )
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .onAppear {
            if let path = project.sourcePath, !path.isEmpty {
                xcodeVersion = DataPathService.shared.readXcodeVersion(from: path)
            }
            pipelineStats = DataPathService.shared.loadPipelineStats(for: project.id)
        }
        .onChange(of: project.sourcePath) { _, newPath in
            if let path = newPath, !path.isEmpty {
                xcodeVersion = DataPathService.shared.readXcodeVersion(from: path)
            } else {
                xcodeVersion = nil
            }
        }
        .contextMenu {
            Button {
                openWindow(id: "kanban", value: project.id)
            } label: {
                Label("칸반 보드", systemImage: "rectangle.split.3x1")
            }
            
            Button {
                openWindow(id: "pipeline", value: project.id)
            } label: {
                Label("파이프라인", systemImage: "arrow.triangle.2.circlepath")
            }
            
            Button {
                openWindow(id: "project-wiki", value: project.id)
            } label: {
                Label("위키", systemImage: "book")
            }
            
            Divider()
            
            Button {
                newName = project.name
                showingRenameSheet = true
            } label: {
                Label("이름 변경", systemImage: "pencil")
            }
            
            Divider()
            
            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                Label("입주사 삭제", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showingRenameSheet) {
            RenameProjectSheet(
                projectId: project.id,
                currentName: project.name,
                newName: $newName,
                isPresented: $showingRenameSheet
            )
        }
        .alert("입주사 삭제", isPresented: $showingDeleteConfirmation) {
            Button("취소", role: .cancel) { }
            Button("삭제", role: .destructive) {
                deleteProject()
            }
        } message: {
            Text("'\(project.name)' 입주사를 삭제하시겠습니까?\n\n모든 태스크, 스프린트, 직원 대화 기록이 삭제됩니다. 이 작업은 되돌릴 수 없습니다.")
        }
    }
    
    private func deleteProject() {
        // 데이터 폴더도 삭제
        let basePath = DataPathService.shared.basePath
        let projectDataPath = "\(basePath)/\(project.name)"
        try? FileManager.default.removeItem(atPath: projectDataPath)
        
        // CompanyStore에서 삭제
        companyStore.removeProject(project.id)
    }
}

struct StatBadge: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
        }
        .font(.callout)
    }
}

struct EmptyProjectsView: View {
    @Binding var showingAddProject: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "building.2.crop.circle.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("입주사가 없습니다")
                .font(.title2)
            
            Text("새 입주사를 등록하고 AI 직원들에게 일을 할당해보세요")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                showingAddProject = true
            } label: {
                Label("첫 입주사 등록하기", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Rename Project Sheet

struct RenameProjectSheet: View {
    let projectId: UUID
    let currentName: String
    @Binding var newName: String
    @Binding var isPresented: Bool
    
    @EnvironmentObject var companyStore: CompanyStore
    
    var isValid: Bool {
        !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        newName != currentName
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("입주사 이름 변경")
                    .font(.title3.bold())
                Spacer()
                Button("취소") {
                    isPresented = false
                }
            }
            .padding()
            
            Divider()
            
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("현재 이름")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text(currentName)
                        .font(.body)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("새 이름")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    TextField("입주사 이름", text: $newName)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding()
            
            Spacer()
            
            Divider()
            
            HStack {
                Spacer()
                Button("취소") {
                    isPresented = false
                }
                Button("변경") {
                    renameProject()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 400, height: 280)
    }
    
    private func renameProject() {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        companyStore.renameProject(projectId, to: trimmedName)
        isPresented = false
    }
}

#Preview {
    ProjectListView(selectedProjectId: .constant(nil), selectedTab: .constant(.projects))
        .environmentObject(CompanyStore())
        .frame(width: 900, height: 600)
}
