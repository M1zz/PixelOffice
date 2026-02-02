import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var companyStore: CompanyStore
    @Binding var selectedTab: SidebarItem
    @Binding var selectedProjectId: UUID?
    
    var body: some View {
        List {
            Section {
                SidebarButton(
                    label: "오피스",
                    icon: "building.2.fill",
                    isSelected: selectedTab == .office
                ) {
                    selectedTab = .office
                }
            }

            Section("프로젝트") {
                SidebarButton(
                    label: "전체 프로젝트",
                    icon: "folder.fill",
                    badge: companyStore.company.projects.count,
                    isSelected: selectedTab == .projects && selectedProjectId == nil
                ) {
                    selectedTab = .projects
                    selectedProjectId = nil
                }

                ForEach(companyStore.company.projects) { project in
                    DisclosureGroup {
                        // 프로젝트 오피스
                        Button {
                            selectedTab = .projectOffice(project.id)
                            selectedProjectId = project.id
                        } label: {
                            HStack {
                                Image(systemName: "building.2")
                                    .frame(width: 16)
                                Text("오피스")
                                Spacer()
                                Text("\(project.allEmployees.count)명")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 2)
                        .padding(.horizontal, 8)
                        .background(selectedTab == .projectOffice(project.id) ? Color.accentColor.opacity(0.2) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                        // 프로젝트 태스크
                        Button {
                            selectedTab = .projects
                            selectedProjectId = project.id
                        } label: {
                            HStack {
                                Image(systemName: "checklist")
                                    .frame(width: 16)
                                Text("태스크")
                                Spacer()
                                Text("\(project.completedTasksCount)/\(project.tasks.count)")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 2)
                        .padding(.horizontal, 8)
                        .background(selectedTab == .projects && selectedProjectId == project.id ? Color.accentColor.opacity(0.2) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    } label: {
                        HStack {
                            Circle()
                                .fill(project.status.color)
                                .frame(width: 8, height: 8)
                            Text(project.name)
                                .lineLimit(1)
                        }
                    }
                }
            }

            Section("통계") {
                StatRow(icon: "person.2.fill", title: "직원", value: "\(companyStore.totalEmployees)명")
                StatRow(icon: "keyboard.fill", title: "작업 중", value: "\(companyStore.workingEmployeesCount)명")
                StatRow(icon: "checkmark.circle.fill", title: "완료 태스크", value: "\(companyStore.completedTasks)개")
                StatRow(icon: "circle", title: "대기 태스크", value: "\(companyStore.pendingTasks)개")
            }

            Section {
                SidebarButton(
                    label: "회사 위키",
                    icon: "books.vertical.fill",
                    badge: companyStore.company.wikiDocuments.count,
                    isSelected: selectedTab == .wiki
                ) {
                    selectedTab = .wiki
                }
            }

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
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    NotificationCenter.default.post(name: .addNewProject, object: nil)
                } label: {
                    Image(systemName: "plus")
                }
                .help("새 프로젝트 추가")
            }
        }
    }
}

struct StatRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.callout)
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
    SidebarView(selectedTab: .constant(.office), selectedProjectId: .constant(nil))
        .environmentObject(CompanyStore())
}
