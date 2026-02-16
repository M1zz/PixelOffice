import SwiftUI

struct AddProjectView: View {
    @EnvironmentObject var companyStore: CompanyStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var description = ""
    @State private var projectContext = ""
    @State private var priority: ProjectPriority = .medium
    @State private var hasDeadline = false
    @State private var deadline = Date().addingTimeInterval(7 * 24 * 60 * 60)
    @State private var tagsText = ""
    @State private var sourcePath = ""
    
    // 분석 상태
    @State private var isAnalyzing = false
    @State private var analysisError: String?
    @State private var showAnalysisError = false
    
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var canAnalyze: Bool {
        !sourcePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isAnalyzing
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("새 입주사")
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
                // 소스 경로를 맨 위로
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            TextField("소스 폴더 경로", text: $sourcePath)
                                .textFieldStyle(.roundedBorder)
                            
                            Button("선택...") {
                                selectFolder()
                            }
                        }
                        
                        HStack {
                            Text("AI가 코드를 분석하여 상세 정보를 자동으로 채웁니다")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Button {
                                Task { await analyzeProject() }
                            } label: {
                                if isAnalyzing {
                                    HStack(spacing: 6) {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                        Text("분석 중...")
                                    }
                                } else {
                                    Label("소스 분석", systemImage: "sparkles")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!canAnalyze)
                        }
                    }
                } header: {
                    Label("소스 코드 경로", systemImage: "folder")
                }
                
                Section {
                    TextField("입주사 이름", text: $name)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("설명 (선택)", text: $description, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                } header: {
                    Label("기본 정보", systemImage: "info.circle")
                }
                
                Section {
                    TextField("태그 (쉼표로 구분)", text: $tagsText)
                        .textFieldStyle(.roundedBorder)
                    
                    Text("예: iOS, SwiftUI, 사이드프로젝트")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } header: {
                    Label("태그", systemImage: "tag")
                }
                
                Section {
                    TextField("프로젝트 컨텍스트 (AI 작업 시 참고)", text: $projectContext, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(4...8)
                    
                    Text("프로젝트의 목적, 주요 기능, 아키텍처 등 AI가 작업할 때 참고할 정보")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } header: {
                    Label("프로젝트 컨텍스트", systemImage: "doc.text")
                }
                
                Section {
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
                } header: {
                    Label("설정", systemImage: "gearshape")
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
        .frame(width: 550, height: 650)
        .alert("분석 오류", isPresented: $showAnalysisError) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(analysisError ?? "알 수 없는 오류가 발생했습니다")
        }
    }
    
    private func createProject() {
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        let trimmedPath = sourcePath.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let project = Project(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            deadline: hasDeadline ? deadline : nil,
            tags: tags,
            priority: priority,
            projectContext: projectContext.trimmingCharacters(in: .whitespacesAndNewlines),
            sourcePath: trimmedPath.isEmpty ? nil : trimmedPath
        )
        
        companyStore.addProject(project)
        dismiss()
    }
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.message = "소스 코드 폴더를 선택하세요"
        
        if panel.runModal() == .OK, let url = panel.url {
            sourcePath = url.path
        }
    }
    
    private func analyzeProject() async {
        let path = sourcePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else { return }
        
        isAnalyzing = true
        analysisError = nil
        
        do {
            let result = try await ProjectAnalyzerService.shared.analyzeProject(at: path)
            
            await MainActor.run {
                // 분석 결과로 필드 채우기
                if name.isEmpty {
                    name = result.name
                }
                if description.isEmpty {
                    description = result.description
                }
                if tagsText.isEmpty {
                    // 태그와 기술스택 합치기
                    let allTags = result.tags + result.techStack
                    tagsText = allTags.joined(separator: ", ")
                }
                if projectContext.isEmpty {
                    projectContext = result.projectContext
                }
                
                isAnalyzing = false
            }
        } catch {
            await MainActor.run {
                analysisError = error.localizedDescription
                showAnalysisError = true
                isAnalyzing = false
            }
        }
    }
}

#Preview {
    AddProjectView()
        .environmentObject(CompanyStore())
}
