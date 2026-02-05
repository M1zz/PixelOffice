import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var companyStore: CompanyStore
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // API Settings
            APISettingsView()
                .tabItem {
                    Label("API 설정", systemImage: "key.fill")
                }
                .tag(0)
            
            // Company Settings
            CompanySettingsView()
                .tabItem {
                    Label("회사 설정", systemImage: "building.2.fill")
                }
                .tag(1)
            
            // Department Skills
            DepartmentSkillsView()
                .tabItem {
                    Label("부서 스킬", systemImage: "person.3.fill")
                }
                .tag(2)

            // Structured Debate
            DebateSettingsView()
                .tabItem {
                    Label("구조화된 토론", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .tag(3)

            // Data Management
            DataManagementView()
                .tabItem {
                    Label("데이터 관리", systemImage: "externaldrive.fill")
                }
                .tag(4)

            // About
            AboutView()
                .tabItem {
                    Label("정보", systemImage: "info.circle.fill")
                }
                .tag(5)
        }
        .frame(minWidth: 600, minHeight: 400)
        .padding()
    }
}

struct APISettingsView: View {
    @EnvironmentObject var companyStore: CompanyStore
    @State private var showingAddAPI = false
    @State private var editingConfig: APIConfiguration?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("API 설정")
                        .font(.title2.bold())
                    Text("AI 직원들이 사용할 API를 설정합니다")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button {
                    showingAddAPI = true
                } label: {
                    Label("API 추가", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            
            Divider()
            
            // API List
            if companyStore.company.settings.apiConfigurations.isEmpty {
                EmptyAPIView(showingAddAPI: $showingAddAPI)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(companyStore.company.settings.apiConfigurations) { config in
                            APIConfigCard(
                                config: config,
                                onEdit: { editingConfig = config },
                                onDelete: { companyStore.removeAPIConfiguration(config.id) }
                            )
                        }
                    }
                }
            }
        }
        .padding()
        .sheet(isPresented: $showingAddAPI) {
            APIConfigEditor(config: nil)
        }
        .sheet(item: $editingConfig) { config in
            APIConfigEditor(config: config)
        }
    }
}

struct EmptyAPIView: View {
    @Binding var showingAddAPI: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.slash")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            
            Text("API가 설정되지 않았습니다")
                .font(.headline)
            
            Text("AI 직원들이 작업하려면 API 키가 필요합니다")
                .font(.callout)
                .foregroundStyle(.secondary)
            
            Button {
                showingAddAPI = true
            } label: {
                Label("첫 API 추가하기", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct APIConfigCard: View {
    let config: APIConfiguration
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 16) {
            // AI Type Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(config.type.color.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: config.type.icon)
                    .font(.title2)
                    .foregroundStyle(config.type.color)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(config.name)
                        .font(.headline)
                    
                    if config.isEnabled {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                    } else {
                        Circle()
                            .fill(.gray)
                            .frame(width: 8, height: 8)
                    }
                }
                
                Text(config.type.rawValue)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                
                HStack {
                    Text("모델: \(config.model)")
                    Text("•")
                    Text(config.isConfigured ? "설정됨" : "API 키 필요")
                        .foregroundStyle(config.isConfigured ? .green : .orange)
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Actions
            if isHovering {
                HStack(spacing: 8) {
                    Button {
                        onEdit()
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.bordered)
                    
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

struct APIConfigEditor: View {
    let config: APIConfiguration?
    
    @EnvironmentObject var companyStore: CompanyStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var aiType: AIType = .claude
    @State private var apiKey = ""
    @State private var model = ""
    @State private var maxTokens = 4096
    @State private var temperature = 0.7
    @State private var isEnabled = true
    
    var isEditing: Bool {
        config != nil
    }
    
    var isValid: Bool {
        !name.isEmpty && !apiKey.isEmpty
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isEditing ? "API 수정" : "새 API")
                    .font(.title2.bold())
                Spacer()
                Button("취소") {
                    dismiss()
                }
            }
            .padding()
            
            Divider()
            
            Form {
                Section {
                    TextField("이름", text: $name)
                        .textFieldStyle(.roundedBorder)
                    
                    Picker("AI 유형", selection: $aiType) {
                        ForEach(AIType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .onChange(of: aiType) { _, newValue in
                        model = newValue.modelName
                    }
                }
                
                Section("인증") {
                    SecureField("API Key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                    
                    switch aiType {
                    case .claude:
                        Link("Anthropic에서 API 키 발급받기",
                             destination: URL(string: "https://console.anthropic.com/")!)
                    case .gpt:
                        Link("OpenAI에서 API 키 발급받기",
                             destination: URL(string: "https://platform.openai.com/api-keys")!)
                    case .gemini:
                        Link("Google AI Studio에서 API 키 발급받기",
                             destination: URL(string: "https://aistudio.google.com/app/apikey")!)
                    case .local:
                        Text("로컬 LLM은 API 키가 필요하지 않습니다")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("모델 설정") {
                    TextField("모델명", text: $model)
                        .textFieldStyle(.roundedBorder)
                    
                    HStack {
                        Text("최대 토큰")
                        Spacer()
                        TextField("", value: $maxTokens, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                    }
                    
                    HStack {
                        Text("Temperature")
                        Slider(value: $temperature, in: 0...2, step: 0.1)
                        Text(String(format: "%.1f", temperature))
                            .frame(width: 40)
                    }
                }
                
                Section {
                    Toggle("활성화", isOn: $isEnabled)
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
                
                Button(isEditing ? "저장" : "추가") {
                    saveConfig()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid && aiType != .local)
            }
            .padding()
        }
        .frame(width: 500, height: 550)
        .onAppear {
            if let config = config {
                name = config.name
                aiType = config.type
                apiKey = config.apiKey
                model = config.model
                maxTokens = config.maxTokens
                temperature = config.temperature
                isEnabled = config.isEnabled
            } else {
                model = aiType.modelName
            }
        }
    }
    
    private func saveConfig() {
        let newConfig = APIConfiguration(
            id: config?.id ?? UUID(),
            name: name,
            type: aiType,
            apiKey: apiKey,
            model: model,
            maxTokens: maxTokens,
            temperature: temperature,
            isEnabled: isEnabled
        )
        
        if isEditing {
            companyStore.updateAPIConfiguration(newConfig)
        } else {
            companyStore.addAPIConfiguration(newConfig)
        }
        
        dismiss()
    }
}

struct CompanySettingsView: View {
    @EnvironmentObject var companyStore: CompanyStore
    @State private var companyName: String = ""
    @State private var autoSaveEnabled = true
    @State private var cloudSyncEnabled = false
    @State private var notificationsEnabled = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("회사 설정")
                .font(.title2.bold())
            
            Divider()
            
            Form {
                Section("기본 정보") {
                    TextField("회사 이름", text: $companyName)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: companyName) { _, newValue in
                            companyStore.company.name = newValue
                        }
                }
                
                Section("저장 설정") {
                    Toggle("자동 저장", isOn: $autoSaveEnabled)
                        .onChange(of: autoSaveEnabled) { _, newValue in
                            companyStore.company.settings.autoSaveEnabled = newValue
                        }
                    
                    Toggle("클라우드 동기화 (준비 중)", isOn: $cloudSyncEnabled)
                        .disabled(true)
                        .onChange(of: cloudSyncEnabled) { _, newValue in
                            companyStore.company.settings.cloudSyncEnabled = newValue
                        }
                    
                    Text("클라우드 동기화는 향후 업데이트에서 지원될 예정입니다")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                
                Section("알림") {
                    Toggle("알림 활성화", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { _, newValue in
                            companyStore.company.settings.notificationsEnabled = newValue
                        }
                }
            }
            .formStyle(.grouped)
        }
        .padding()
        .onAppear {
            companyName = companyStore.company.name
            autoSaveEnabled = companyStore.company.settings.autoSaveEnabled
            cloudSyncEnabled = companyStore.company.settings.cloudSyncEnabled
            notificationsEnabled = companyStore.company.settings.notificationsEnabled
        }
    }
}

struct DataManagementView: View {
    @EnvironmentObject var companyStore: CompanyStore
    @State private var showingExportSuccess = false
    @State private var showingImportPicker = false
    @State private var showingDeleteConfirmation = false
    
    private let dataManager = DataManager()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("데이터 관리")
                .font(.title2.bold())
            
            Divider()
            
            Form {
                Section("백업") {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("백업 생성")
                                .font(.headline)
                            Text("현재 데이터의 백업을 생성합니다")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("백업") {
                            _ = dataManager.createBackup(companyStore.company)
                        }
                    }
                }
                
                Section("내보내기/가져오기") {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("데이터 내보내기")
                                .font(.headline)
                            Text("JSON 파일로 내보냅니다")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("내보내기") {
                            exportData()
                        }
                    }
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("데이터 가져오기")
                                .font(.headline)
                            Text("JSON 파일에서 가져옵니다")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("가져오기") {
                            showingImportPicker = true
                        }
                    }
                }
                
                Section("초기화") {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("모든 데이터 삭제")
                                .font(.headline)
                                .foregroundStyle(.red)
                            Text("이 작업은 되돌릴 수 없습니다")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Text("삭제")
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
        .padding()
        .alert("모든 데이터를 삭제하시겠습니까?", isPresented: $showingDeleteConfirmation) {
            Button("취소", role: .cancel) {}
            Button("삭제", role: .destructive) {
                dataManager.deleteCompany()
                companyStore.company = Company()
            }
        } message: {
            Text("프로젝트, 직원, 대화 기록 등 모든 데이터가 영구적으로 삭제됩니다.")
        }
    }
    
    private func exportData() {
        guard let data = dataManager.exportCompany(companyStore.company) else { return }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "ai_company_backup.json"
        
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url)
        }
    }
}

struct DebateSettingsView: View {
    @State private var defaultRounds = 1
    @State private var autoPostToCommunity = true
    @State private var saveToWiki = true

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("🏛️ 구조화된 토론 설정")
                    .font(.title2.bold())
                Text("AI 직원들 간 구조화된 토론의 기본 설정을 관리합니다")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                // 토론 구조 설명
                VStack(alignment: .leading, spacing: 12) {
                    Text("토론 진행 구조")
                        .font(.callout.weight(.semibold))

                    InfoRow(icon: "doc.text.fill", title: "Phase 1: 주제 제시", description: "토론 주제와 배경 정보를 정리합니다")
                    InfoRow(icon: "person.fill.questionmark", title: "Phase 2: 독립 의견", description: "각 직원이 독립적으로 의견을 제출합니다 (병렬 처리)")
                    InfoRow(icon: "arrow.triangle.2.circlepath", title: "Phase 3: 교차 검토", description: "다른 직원의 의견에 대해 반박/보완합니다")
                    InfoRow(icon: "lightbulb.max.fill", title: "Phase 4: 종합", description: "합의점, 쟁점, 액션 아이템을 도출합니다")
                }

                Divider()

                // 기본 설정
                VStack(alignment: .leading, spacing: 12) {
                    Text("기본 설정")
                        .font(.callout.weight(.semibold))

                    Stepper("교차 검토 라운드: \(defaultRounds)", value: $defaultRounds, in: 1...3)
                        .font(.callout)

                    Toggle("완료 후 커뮤니티에 자동 게시", isOn: $autoPostToCommunity)
                        .font(.callout)

                    Toggle("위키에 회의록 자동 저장", isOn: $saveToWiki)
                        .font(.callout)
                }

                Divider()

                // 비용 안내
                VStack(alignment: .leading, spacing: 8) {
                    Text("예상 API 비용")
                        .font(.callout.weight(.semibold))
                    Text("참여자 3명, 교차 검토 1라운드 기준: ~10 API 호출")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("참여자 수와 라운드 수에 비례하여 증가합니다")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding()
    }
}


struct InfoRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.orange)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.callout.weight(.medium))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "building.2.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color.accentColor)

            Text("Pixel Office")
                .font(.largeTitle.bold())

            Text("버전 1.0.0")
                .font(.callout)
                .foregroundStyle(.secondary)

            Divider()
                .frame(width: 200)

            VStack(spacing: 8) {
                Text("AI 에이전트를 시각화하고 관리하는")
                Text("픽셀아트 스타일의 회사 시뮬레이션 앱")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            Spacer()

            Text("Made with ❤️ by Leeo")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    SettingsView()
        .environmentObject(CompanyStore())
        .frame(width: 700, height: 500)
}
