import SwiftUI

struct AddTaskView: View {
    let projectId: UUID
    @EnvironmentObject var companyStore: CompanyStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var description = ""
    @State private var departmentType: DepartmentType = .general
    @State private var prompt = ""
    @State private var selectedEmployeeId: UUID?
    @State private var estimatedHours: Double?
    
    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var availableEmployees: [Employee] {
        companyStore.company.allEmployees.filter { $0.status != .offline }
    }
    
    var employeesInDepartment: [Employee] {
        guard let dept = companyStore.getDepartment(byType: departmentType) else {
            return availableEmployees
        }
        return dept.employees.filter { $0.status != .offline }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("새 태스크")
                    .font(.title2.bold())
                Spacer()
                Button("취소") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
            }
            .padding()
            
            Divider()
            
            // Form
            Form {
                Section {
                    TextField("태스크 제목", text: $title)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("설명 (선택)", text: $description, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                }
                
                Section("부서 및 담당자") {
                    Picker("부서", selection: $departmentType) {
                        ForEach(DepartmentType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    
                    Picker("담당자", selection: $selectedEmployeeId) {
                        Text("나중에 배정").tag(nil as UUID?)
                        
                        if !employeesInDepartment.isEmpty {
                            Section("\(departmentType.rawValue)팀") {
                                ForEach(employeesInDepartment) { employee in
                                    HStack {
                                        Image(systemName: employee.aiType.icon)
                                            .foregroundStyle(employee.aiType.color)
                                        Text(employee.name)
                                        Spacer()
                                        Circle()
                                            .fill(employee.status.color)
                                            .frame(width: 8, height: 8)
                                    }
                                    .tag(employee.id as UUID?)
                                }
                            }
                        }
                        
                        let otherEmployees = availableEmployees.filter { emp in
                            !employeesInDepartment.contains { $0.id == emp.id }
                        }
                        
                        if !otherEmployees.isEmpty {
                            Section("다른 부서") {
                                ForEach(otherEmployees) { employee in
                                    HStack {
                                        Image(systemName: employee.aiType.icon)
                                            .foregroundStyle(employee.aiType.color)
                                        Text(employee.name)
                                        Spacer()
                                        Circle()
                                            .fill(employee.status.color)
                                            .frame(width: 8, height: 8)
                                    }
                                    .tag(employee.id as UUID?)
                                }
                            }
                        }
                    }
                }
                
                Section("AI 프롬프트") {
                    TextEditor(text: $prompt)
                        .frame(minHeight: 100)
                        .font(.body)
                        .overlay(
                            Group {
                                if prompt.isEmpty {
                                    Text("AI에게 전달할 작업 지시사항을 입력하세요...\n\n예: \"iOS 앱의 메인 화면 UI를 SwiftUI로 구현해주세요. 탭바를 사용하고 홈, 검색, 프로필 3개의 탭이 있어야 합니다.\"")
                                        .foregroundStyle(.secondary)
                                        .padding(8)
                                        .allowsHitTesting(false)
                                }
                            },
                            alignment: .topLeading
                        )
                    
                    Text("이 프롬프트는 담당 AI 직원에게 전달됩니다")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            
            Divider()
            
            // Actions
            HStack {
                Spacer()
                
                Button("취소") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Button("생성") {
                    createTask()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 550, height: 600)
    }
    
    private func createTask() {
        var task = ProjectTask(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            assigneeId: selectedEmployeeId,
            departmentType: departmentType,
            prompt: prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        if selectedEmployeeId != nil {
            task.status = .todo
        }
        
        companyStore.addTask(task, toProject: projectId)
        dismiss()
    }
}

#Preview {
    let store = CompanyStore()
    store.addEmployee(
        Employee(name: "Claude-1", aiType: .claude),
        toDepartment: store.company.departments[2].id  // 개발팀
    )
    
    return AddTaskView(projectId: UUID())
        .environmentObject(store)
}
