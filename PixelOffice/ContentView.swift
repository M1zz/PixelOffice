import SwiftUI

struct ContentView: View {
    @EnvironmentObject var companyStore: CompanyStore
    @Environment(\.openWindow) private var openWindow
    @State private var selectedTab: SidebarItem = .office
    @State private var selectedProjectId: UUID?
    @State private var showingAddProject = false

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedTab: $selectedTab, selectedProjectId: $selectedProjectId)
                .frame(minWidth: 220)
        } detail: {
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showingAddProject) {
            AddProjectView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .addNewProject)) { _ in
            showingAddProject = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .addNewEmployee)) { _ in
            openWindow(id: "add-employee", value: UUID())
        }
    }
    
    @ViewBuilder
    private var detailView: some View {
        switch selectedTab {
        case .office:
            OfficeView()
        case .projects:
            if let projectId = selectedProjectId,
               let project = companyStore.company.projects.first(where: { $0.id == projectId }) {
                ProjectDetailView(project: project)
            } else {
                ProjectListView(selectedProjectId: $selectedProjectId)
            }
        case .projectOffice(let projectId):
            ProjectOfficeView(projectId: projectId)
        case .wiki:
            WikiView()
        case .settings:
            SettingsView()
        }
    }
}

enum SidebarItem: Hashable {
    case office
    case projects
    case projectOffice(UUID)  // 프로젝트별 오피스
    case wiki
    case settings
}

#Preview {
    ContentView()
        .environmentObject(CompanyStore())
}
