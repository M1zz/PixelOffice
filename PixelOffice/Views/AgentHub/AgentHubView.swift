import SwiftUI

/// 스킬 & 에이전트 관리 메인 뷰
struct AgentHubView: View {
    @StateObject private var skillStore = SkillStore.shared
    
    @State private var selectedSection: HubSection = .skills
    @State private var searchText = ""
    @State private var selectedCategory: SkillCategory?
    @State private var showingImportSheet = false
    @State private var showingAddSkill = false
    @State private var selectedSkill: Skill?
    
    enum HubSection: String, CaseIterable {
        case skills = "스킬"
        case favorites = "즐겨찾기"
        case custom = "커스텀"
        
        var icon: String {
            switch self {
            case .skills: return "cube.box.fill"
            case .favorites: return "star.fill"
            case .custom: return "wrench.and.screwdriver.fill"
            }
        }
    }
    
    var filteredSkills: [Skill] {
        var result: [Skill]
        
        switch selectedSection {
        case .skills:
            result = skillStore.skills
        case .favorites:
            result = skillStore.favoriteSkills
        case .custom:
            result = skillStore.customSkills
        }
        
        // 카테고리 필터
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }
        
        // 검색 필터
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(query) ||
                $0.description.lowercased().contains(query) ||
                $0.tags.contains { $0.lowercased().contains(query) }
            }
        }
        
        return result
    }
    
    var body: some View {
        HSplitView {
            // 왼쪽: 스킬 목록
            VStack(spacing: 0) {
                // 헤더
                HStack {
                    Text("에이전트 허브")
                        .font(.title2.bold())
                    
                    Spacer()
                    
                    // Import 버튼
                    Button {
                        showingImportSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                    .help("스킬 가져오기")
                    
                    // 추가 버튼
                    Button {
                        showingAddSkill = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .help("새 스킬 만들기")
                }
                .padding()
                
                // 섹션 선택
                Picker("섹션", selection: $selectedSection) {
                    ForEach(HubSection.allCases, id: \.self) { section in
                        Label(section.rawValue, systemImage: section.icon)
                            .tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                // 검색
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("스킬 검색...", text: $searchText)
                        .textFieldStyle(.plain)
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding()
                
                // 카테고리 필터
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        CategoryChip(
                            title: "전체",
                            isSelected: selectedCategory == nil,
                            color: .secondary
                        ) {
                            selectedCategory = nil
                        }
                        
                        ForEach(SkillCategory.allCases, id: \.self) { category in
                            CategoryChip(
                                title: category.rawValue,
                                icon: category.icon,
                                isSelected: selectedCategory == category,
                                color: category.color
                            ) {
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 8)
                
                Divider()
                
                // 스킬 목록
                if filteredSkills.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "cube.transparent")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text(selectedSection == .custom ? "커스텀 스킬이 없습니다" : "스킬이 없습니다")
                            .foregroundStyle(.secondary)
                        
                        if selectedSection == .custom {
                            Button("새 스킬 만들기") {
                                showingAddSkill = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filteredSkills, selection: $selectedSkill) { skill in
                        HubSkillRow(skill: skill, isFavorite: skillStore.isFavorite(skill.id)) {
                            skillStore.toggleFavorite(skill.id)
                        }
                        .tag(skill)
                    }
                    .listStyle(.plain)
                }
            }
            .frame(minWidth: 350, maxWidth: 500)
            
            // 오른쪽: 스킬 상세
            if let skill = selectedSkill {
                SkillDetailView(skill: skill)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "cube.box")
                        .font(.system(size: 64))
                        .foregroundStyle(.secondary)
                    Text("스킬을 선택하세요")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("왼쪽에서 스킬을 선택하면 상세 정보를 볼 수 있습니다")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showingImportSheet) {
            ImportSkillSheet()
        }
        .sheet(isPresented: $showingAddSkill) {
            HubAddSkillSheet()
        }
    }
}

// MARK: - Category Chip

private struct CategoryChip: View {
    let title: String
    var icon: String?
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.callout)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? color.opacity(0.2) : Color.clear)
            .foregroundStyle(isSelected ? color : .secondary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(isSelected ? color : Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Skill Row

private struct HubSkillRow: View {
    let skill: Skill
    let isFavorite: Bool
    let onToggleFavorite: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 아이콘
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(skill.category.color.opacity(0.2))
                    .frame(width: 40, height: 40)
                Image(systemName: skill.category.icon)
                    .foregroundStyle(skill.category.color)
            }
            
            // 정보
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(skill.name)
                        .font(.headline)
                    
                    if skill.isCustom {
                        Text("커스텀")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    }
                }
                
                Text(skill.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 즐겨찾기 버튼
            Button {
                onToggleFavorite()
            } label: {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .foregroundStyle(isFavorite ? .yellow : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Skill Detail View

private struct SkillDetailView: View {
    let skill: Skill
    @StateObject private var skillStore = SkillStore.shared
    @State private var showingEdit = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 헤더
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(skill.category.color.opacity(0.2))
                            .frame(width: 60, height: 60)
                        Image(systemName: skill.category.icon)
                            .font(.title)
                            .foregroundStyle(skill.category.color)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(skill.name)
                                .font(.title.bold())
                            
                            if skill.isCustom {
                                Text("커스텀")
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.2))
                                    .foregroundStyle(.orange)
                                    .clipShape(Capsule())
                            }
                        }
                        
                        HStack(spacing: 8) {
                            Label(skill.category.rawValue, systemImage: skill.category.icon)
                            Text("v\(skill.version)")
                        }
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    // 액션 버튼들
                    HStack(spacing: 8) {
                        Button {
                            skillStore.toggleFavorite(skill.id)
                        } label: {
                            Image(systemName: skillStore.isFavorite(skill.id) ? "star.fill" : "star")
                        }
                        .buttonStyle(.bordered)
                        
                        if skill.isCustom {
                            Button {
                                showingEdit = true
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.bordered)
                            
                            Button {
                                showingDeleteAlert = true
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                        }
                        
                        Menu {
                            Button {
                                _ = skillStore.duplicateSkill(skill)
                            } label: {
                                Label("복제", systemImage: "doc.on.doc")
                            }
                            
                            Button {
                                exportSkill()
                            } label: {
                                Label("내보내기", systemImage: "square.and.arrow.up")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                Divider()
                
                // 설명
                VStack(alignment: .leading, spacing: 8) {
                    Text("설명")
                        .font(.headline)
                    Text(skill.description)
                        .foregroundStyle(.secondary)
                }
                
                // 태그
                if !skill.tags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("태그")
                            .font(.headline)
                        
                        HubFlowLayout(spacing: 8) {
                            ForEach(skill.tags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.callout)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.secondary.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                
                // 시스템 프롬프트
                if let systemPrompt = skill.systemPrompt, !systemPrompt.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("시스템 프롬프트")
                            .font(.headline)
                        
                        Text(systemPrompt)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                
                // 프롬프트 템플릿
                VStack(alignment: .leading, spacing: 8) {
                    Text("프롬프트 템플릿")
                        .font(.headline)
                    
                    Text(skill.promptTemplate)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                // 입력 스키마
                if let inputSchema = skill.inputSchema {
                    SchemaSection(title: "입력 스키마", schema: inputSchema)
                }
                
                // 출력 스키마
                if let outputSchema = skill.outputSchema {
                    SchemaSection(title: "출력 스키마", schema: outputSchema)
                }
                
                // 필요 도구
                if !skill.requiredTools.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("필요한 도구")
                            .font(.headline)
                        
                        ForEach(skill.requiredTools, id: \.name) { tool in
                            HStack {
                                Image(systemName: tool.isRequired ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(tool.isRequired ? .green : .secondary)
                                VStack(alignment: .leading) {
                                    Text(tool.name)
                                        .font(.callout.bold())
                                    Text(tool.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(8)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
                
                // 메타데이터
                VStack(alignment: .leading, spacing: 8) {
                    Text("메타데이터")
                        .font(.headline)
                    
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                        if let estimatedTokens = skill.estimatedTokens {
                            GridRow {
                                Text("예상 토큰")
                                    .foregroundStyle(.secondary)
                                Text("\(estimatedTokens)")
                            }
                        }
                        
                        if let estimatedDuration = skill.estimatedDuration {
                            GridRow {
                                Text("예상 시간")
                                    .foregroundStyle(.secondary)
                                Text("\(Int(estimatedDuration))초")
                            }
                        }
                        
                        GridRow {
                            Text("생성일")
                                .foregroundStyle(.secondary)
                            Text(skill.createdAt.formatted(date: .abbreviated, time: .shortened))
                        }
                        
                        GridRow {
                            Text("수정일")
                                .foregroundStyle(.secondary)
                            Text(skill.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        }
                    }
                    .font(.callout)
                }
            }
            .padding(24)
        }
        .sheet(isPresented: $showingEdit) {
            EditSkillSheet(skill: skill)
        }
        .alert("스킬 삭제", isPresented: $showingDeleteAlert) {
            Button("취소", role: .cancel) { }
            Button("삭제", role: .destructive) {
                skillStore.deleteSkill(skill)
            }
        } message: {
            Text("'\(skill.name)' 스킬을 삭제하시겠습니까?")
        }
    }
    
    private func exportSkill() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(skill.id).json"
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try skillStore.exportSkills([skill])
                try data.write(to: url)
            } catch {
                print("Export failed: \(error)")
            }
        }
    }
}

// MARK: - Schema Section

private struct SchemaSection: View {
    let title: String
    let schema: SkillSchema
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(schema.properties.keys.sorted()), id: \.self) { key in
                    if let prop = schema.properties[key] {
                        HStack(alignment: .top) {
                            Text(key)
                                .font(.callout.bold())
                                .foregroundStyle(schema.required.contains(key) ? .primary : .secondary)
                            
                            Text("(\(prop.type))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            if schema.required.contains(key) {
                                Text("*")
                                    .foregroundStyle(.red)
                            }
                            
                            Spacer()
                        }
                        
                        if let desc = prop.description {
                            Text(desc)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Flow Layout

private struct HubFlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }
    
    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let width = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxWidth: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > width && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            positions.append(CGPoint(x: currentX, y: currentY))
            
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            maxWidth = max(maxWidth, currentX - spacing)
        }
        
        return (CGSize(width: maxWidth, height: currentY + lineHeight), positions)
    }
}

// MARK: - Import Sheet

private struct ImportSkillSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var skillStore = SkillStore.shared
    
    @State private var importMethod: ImportMethod = .file
    @State private var urlString = ""
    @State private var isImporting = false
    @State private var importResult: ImportResult?
    
    enum ImportMethod: String, CaseIterable {
        case file = "파일"
        case url = "URL"
    }
    
    enum ImportResult {
        case success(Int)
        case error(String)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text("스킬 가져오기")
                    .font(.title3.bold())
                Spacer()
                Button("닫기") {
                    dismiss()
                }
            }
            .padding()
            
            Divider()
            
            VStack(spacing: 20) {
                Picker("가져오기 방법", selection: $importMethod) {
                    ForEach(ImportMethod.allCases, id: \.self) { method in
                        Text(method.rawValue).tag(method)
                    }
                }
                .pickerStyle(.segmented)
                
                switch importMethod {
                case .file:
                    VStack(spacing: 16) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        
                        Text("JSON 파일을 선택하세요")
                            .foregroundStyle(.secondary)
                        
                        Button("파일 선택...") {
                            selectFile()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                case .url:
                    VStack(alignment: .leading, spacing: 12) {
                        Text("스킬 JSON URL 입력")
                            .font(.headline)
                        
                        TextField("https://example.com/skill.json", text: $urlString)
                            .textFieldStyle(.roundedBorder)
                        
                        Button {
                            importFromURL()
                        } label: {
                            if isImporting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Text("가져오기")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(urlString.isEmpty || isImporting)
                    }
                }
                
                // 결과 표시
                if let result = importResult {
                    switch result {
                    case .success(let count):
                        Label("\(count)개의 스킬을 가져왔습니다", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    case .error(let message):
                        Label(message, systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding()
            
            Spacer()
        }
        .frame(width: 450, height: 400)
    }
    
    private func selectFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let skills = try skillStore.importSkills(from: url)
                importResult = .success(skills.count)
            } catch {
                importResult = .error(error.localizedDescription)
            }
        }
    }
    
    private func importFromURL() {
        isImporting = true
        importResult = nil
        
        Task {
            do {
                let skills = try await skillStore.importFromURL(urlString)
                importResult = .success(skills.count)
            } catch {
                importResult = .error(error.localizedDescription)
            }
            isImporting = false
        }
    }
}

// MARK: - Add Skill Sheet

private struct HubAddSkillSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var skillStore = SkillStore.shared
    
    @State private var id = ""
    @State private var name = ""
    @State private var description = ""
    @State private var category: SkillCategory = .custom
    @State private var systemPrompt = ""
    @State private var promptTemplate = ""
    @State private var tags = ""
    
    var isValid: Bool {
        !id.trimmingCharacters(in: .whitespaces).isEmpty &&
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !promptTemplate.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text("새 스킬 만들기")
                    .font(.title3.bold())
                Spacer()
                Button("취소") {
                    dismiss()
                }
            }
            .padding()
            
            Divider()
            
            Form {
                Section("기본 정보") {
                    TextField("ID (영문, 예: code-analysis)", text: $id)
                    TextField("이름", text: $name)
                    TextField("설명", text: $description)
                    
                    Picker("카테고리", selection: $category) {
                        ForEach(SkillCategory.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: cat.icon)
                                .tag(cat)
                        }
                    }
                    
                    TextField("태그 (쉼표 구분)", text: $tags)
                }
                
                Section("프롬프트") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("시스템 프롬프트")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $systemPrompt)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 80)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("프롬프트 템플릿 *")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $promptTemplate)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 120)
                    }
                }
            }
            .formStyle(.grouped)
            
            Divider()
            
            HStack {
                Spacer()
                Button("취소") {
                    dismiss()
                }
                Button("생성") {
                    createSkill()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 550, height: 600)
    }
    
    private func createSkill() {
        let tagList = tags.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
        
        let skill = Skill(
            id: id.trimmingCharacters(in: .whitespaces),
            name: name.trimmingCharacters(in: .whitespaces),
            description: description.trimmingCharacters(in: .whitespaces),
            category: category,
            promptTemplate: promptTemplate,
            systemPrompt: systemPrompt.isEmpty ? nil : systemPrompt,
            tags: tagList,
            isCustom: true
        )
        
        skillStore.addSkill(skill)
        dismiss()
    }
}

// MARK: - Edit Skill Sheet

private struct EditSkillSheet: View {
    let skill: Skill
    @Environment(\.dismiss) private var dismiss
    @StateObject private var skillStore = SkillStore.shared
    
    @State private var name: String
    @State private var description: String
    @State private var category: SkillCategory
    @State private var systemPrompt: String
    @State private var promptTemplate: String
    @State private var tags: String
    
    init(skill: Skill) {
        self.skill = skill
        self._name = State(initialValue: skill.name)
        self._description = State(initialValue: skill.description)
        self._category = State(initialValue: skill.category)
        self._systemPrompt = State(initialValue: skill.systemPrompt ?? "")
        self._promptTemplate = State(initialValue: skill.promptTemplate)
        self._tags = State(initialValue: skill.tags.joined(separator: ", "))
    }
    
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !promptTemplate.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text("스킬 편집")
                    .font(.title3.bold())
                Spacer()
                Button("취소") {
                    dismiss()
                }
            }
            .padding()
            
            Divider()
            
            Form {
                Section("기본 정보") {
                    LabeledContent("ID", value: skill.id)
                    TextField("이름", text: $name)
                    TextField("설명", text: $description)
                    
                    Picker("카테고리", selection: $category) {
                        ForEach(SkillCategory.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: cat.icon)
                                .tag(cat)
                        }
                    }
                    
                    TextField("태그 (쉼표 구분)", text: $tags)
                }
                
                Section("프롬프트") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("시스템 프롬프트")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $systemPrompt)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 80)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("프롬프트 템플릿 *")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $promptTemplate)
                            .font(.system(.body, design: .monospaced))
                            .frame(minHeight: 120)
                    }
                }
            }
            .formStyle(.grouped)
            
            Divider()
            
            HStack {
                Spacer()
                Button("취소") {
                    dismiss()
                }
                Button("저장") {
                    saveSkill()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 550, height: 600)
    }
    
    private func saveSkill() {
        let tagList = tags.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
        
        var updated = skill
        updated.name = name.trimmingCharacters(in: .whitespaces)
        updated.description = description.trimmingCharacters(in: .whitespaces)
        updated.category = category
        updated.systemPrompt = systemPrompt.isEmpty ? nil : systemPrompt
        updated.promptTemplate = promptTemplate
        updated.tags = tagList
        
        skillStore.updateSkill(updated)
        dismiss()
    }
}

#Preview {
    AgentHubView()
}
