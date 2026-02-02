import SwiftUI

struct AddProjectView: View {
    @EnvironmentObject var companyStore: CompanyStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var description = ""
    @State private var priority: ProjectPriority = .medium
    @State private var hasDeadline = false
    @State private var deadline = Date().addingTimeInterval(7 * 24 * 60 * 60)
    @State private var tagsText = ""
    
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("새 프로젝트")
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
                    TextField("프로젝트 이름", text: $name)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("설명 (선택)", text: $description, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }
                
                Section("설정") {
                    Picker("우선순위", selection: $priority) {
                        ForEach(ProjectPriority.allCases, id: \.self) { priority in
                            Label(priority.rawValue, systemImage: priority.icon)
                                .tag(priority)
                        }
                    }
                    
                    Toggle("마감일 설정", isOn: $hasDeadline)
                    
                    if hasDeadline {
                        DatePicker("마감일", selection: $deadline, displayedComponents: .date)
                    }
                }
                
                Section("태그") {
                    TextField("태그 (쉼표로 구분)", text: $tagsText)
                        .textFieldStyle(.roundedBorder)
                    
                    Text("예: iOS, SwiftUI, 사이드프로젝트")
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
                    createProject()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 500, height: 500)
    }
    
    private func createProject() {
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        let project = Project(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            deadline: hasDeadline ? deadline : nil,
            tags: tags,
            priority: priority
        )
        
        companyStore.addProject(project)
        dismiss()
    }
}

#Preview {
    AddProjectView()
        .environmentObject(CompanyStore())
}
