import SwiftUI

@main
struct PixelOfficeApp: App {
    @StateObject private var companyStore = CompanyStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        // 메인 윈도우
        WindowGroup {
            ContentView()
                .environmentObject(companyStore)
                .frame(minWidth: 1200, minHeight: 800)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .inactive || newPhase == .background {
                        companyStore.saveCompany()
                    }
                }
                .onDisappear {
                    companyStore.saveCompany()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("새 프로젝트") {
                    NotificationCenter.default.post(name: .addNewProject, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("새 직원") {
                    NotificationCenter.default.post(name: .addNewEmployee, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
        }

        // 직원 채팅 윈도우 (독립 창)
        WindowGroup("직원 대화", id: "employee-chat", for: UUID.self) { $employeeId in
            if let employeeId = employeeId,
               let employee = companyStore.findEmployee(byId: employeeId) {
                EmployeeChatView(employee: employee)
                    .environmentObject(companyStore)
            } else {
                Text("직원을 찾을 수 없습니다")
                    .frame(width: 400, height: 300)
            }
        }
        .windowStyle(.automatic)
        .windowResizability(.contentSize)
        .defaultSize(width: 500, height: 600)

        // 직원 추가 윈도우 (독립 창)
        WindowGroup("직원 추가", id: "add-employee", for: UUID.self) { $departmentId in
            AddEmployeeView(preselectedDepartmentId: departmentId)
                .environmentObject(companyStore)
        }
        .windowStyle(.automatic)
        .windowResizability(.contentSize)
        .defaultSize(width: 600, height: 550)

        // 프로젝트 직원 채팅 윈도우
        WindowGroup("프로젝트 대화", id: "project-employee-chat", for: ProjectEmployeeChatContext.self) { $context in
            if let context = context {
                ProjectEmployeeChatView(projectId: context.projectId, employeeId: context.employeeId)
                    .environmentObject(companyStore)
            } else {
                Text("대화 컨텍스트를 찾을 수 없습니다")
                    .frame(width: 400, height: 300)
            }
        }
        .windowStyle(.automatic)
        .windowResizability(.contentSize)
        .defaultSize(width: 500, height: 600)

        // 프로젝트 직원 추가 윈도우
        WindowGroup("프로젝트 직원 추가", id: "add-project-employee", for: AddProjectEmployeeContext.self) { $context in
            if let context = context {
                AddProjectEmployeeView(projectId: context.projectId, preselectedDepartmentType: context.departmentType)
                    .environmentObject(companyStore)
            } else {
                Text("컨텍스트를 찾을 수 없습니다")
                    .frame(width: 400, height: 300)
            }
        }
        .windowStyle(.automatic)
        .windowResizability(.contentSize)
        .defaultSize(width: 600, height: 600)

        Settings {
            SettingsView()
                .environmentObject(companyStore)
        }
    }
}

extension Notification.Name {
    static let addNewProject = Notification.Name("addNewProject")
    static let addNewEmployee = Notification.Name("addNewEmployee")
}
