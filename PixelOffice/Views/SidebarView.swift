import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var companyStore: CompanyStore
    @Binding var selectedTab: SidebarItem
    @Binding var selectedProjectId: UUID?
//    @StateObject private var permissionManager = PermissionManager.shared

    var body: some View {
        List {
            Section {
                SidebarButton(
                    label: "오피스",
                    icon: "building.2.fill",
                    isSelected: selectedTab == .projects
                ) {
                    selectedTab = .projects
                    selectedProjectId = nil
                }
            }

            Section {
                SidebarButton(
                    label: "커뮤니티",
                    icon: "person.3.fill",
                    isSelected: selectedTab == .community
                ) {
                    selectedTab = .community
                }

                SidebarButton(
                    label: "토론",
                    icon: "bubble.left.and.bubble.right.fill",
                    isSelected: selectedTab == .debate
                ) {
                    selectedTab = .debate
                }
            }

//            Section {
//                SidebarButton(
//                    label: "권한",
//                    icon: "hand.raised.fill",
//                    badge: permissionManager.pendingCount,
//                    isSelected: selectedTab == .permissions
//                ) {
//                    selectedTab = .permissions
//                }
//            }

            Section {
                SidebarButton(
                    label: "설정",
                    icon: "gearshape.fill",
                    isSelected: selectedTab == .settings
                ) {
                    selectedTab = .settings
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
    }
}

struct SidebarButton: View {
    let label: String
    let icon: String
    var badge: Int = 0
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Label(label, systemImage: icon)
                Spacer()
                if badge > 0 {
                    Text("\(badge)")
                        .font(.callout)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.3))
                        .clipShape(Capsule())
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

#Preview {
    SidebarView(selectedTab: .constant(.projects), selectedProjectId: .constant(nil))
        .environmentObject(CompanyStore())
}
