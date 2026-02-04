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
                Text("프로젝트")
                    .font(.largeTitle.bold())
                
                Spacer()
                
                Button {
                    showingAddProject = true
                } label: {
                    Label("새 프로젝트", systemImage: "plus")
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(project.description.isEmpty ? "설명 없음" : project.description)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Status badge
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
            
            // Progress
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("진행률")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(project.progress * 100))%")
                        .font(.callout.bold())
                }
                
                ProgressView(value: project.progress)
                    .tint(project.status.color)
            }
            
            Divider()
            
            // Stats
            HStack {
                StatBadge(icon: "checkmark.circle.fill", value: "\(project.completedTasksCount)", color: .green)
                StatBadge(icon: "play.circle.fill", value: "\(project.inProgressTasksCount)", color: .blue)
                StatBadge(icon: "circle", value: "\(project.pendingTasksCount)", color: .gray)

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

                // Priority
                HStack(spacing: 2) {
                    Image(systemName: project.priority.icon)
                    Text(project.priority.rawValue)
                }
                .font(.callout)
                .foregroundStyle(project.priority.color)
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
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("프로젝트가 없습니다")
                .font(.title2)
            
            Text("새 프로젝트를 만들어 AI 직원들에게 일을 할당해보세요")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                showingAddProject = true
            } label: {
                Label("첫 프로젝트 만들기", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ProjectListView(selectedProjectId: .constant(nil), selectedTab: .constant(.projects))
        .environmentObject(CompanyStore())
        .frame(width: 900, height: 600)
}
