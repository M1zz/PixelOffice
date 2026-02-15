import SwiftUI

struct ContentView: View {
    @EnvironmentObject var companyStore: CompanyStore
    @Environment(\.openWindow) private var openWindow
    @State private var selectedTab: SidebarItem = .projects
    @State private var selectedProjectId: UUID?
    @State private var showingAddProject = false

    @StateObject private var toastManager = ToastManager.shared
    @ObservedObject private var stateManager = PipelineStateManager.shared

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
        .overlay(alignment: .top) {
            if let toast = toastManager.currentToast {
                ToastView(toast: toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: toastManager.currentToast)
        // 중단된 파이프라인 복구 알림
        .alert("중단된 파이프라인 발견", isPresented: $stateManager.showRecoveryAlert) {
            Button("나중에") {
                stateManager.dismissRecoveryAlert()
            }
            if let firstRun = stateManager.interruptedRuns.first {
                Button("히스토리 보기") {
                    // 해당 프로젝트의 파이프라인 윈도우 열기
                    openWindow(id: "pipeline", value: firstRun.projectId)
                    stateManager.acknowledgeInterruptedRun(firstRun.id)
                }
            }
        } message: {
            if let firstRun = stateManager.interruptedRuns.first {
                Text("'\(firstRun.projectName)' 프로젝트의 파이프라인이 비정상 종료되었습니다.\n마지막 단계: \(firstRun.currentPhase.name)\n히스토리에서 재개할 수 있습니다.")
            } else {
                Text("중단된 파이프라인을 히스토리에서 확인하세요.")
            }
        }
    }
    
    @ViewBuilder
    private var detailView: some View {
        switch selectedTab {
        case .projects:
            ProjectListView(selectedProjectId: $selectedProjectId, selectedTab: $selectedTab)
        case .projectOffice(let projectId):
            ProjectOfficeView(projectId: projectId)
        case .community:
            CommunityView()
        case .debate:
            DebateView()
        case .wiki:
            WikiView()
//        case .permissions:
//            PermissionsView()
        case .settings:
            SettingsView()
        }
    }
}

enum SidebarItem: Hashable {
    case projects
    case projectOffice(UUID)  // 프로젝트별 오피스
    case community  // 커뮤니티
    case debate     // 구조화된 토론
    case wiki       // 회사 위키
//    case permissions  // 권한 관리
    case settings
}

#Preview {
    ContentView()
        .environmentObject(CompanyStore())
}
