import SwiftUI

/// 프로젝트에 직원 추가하는 뷰
struct AddProjectEmployeeView: View {
    let projectId: UUID
    var preselectedDepartmentType: DepartmentType?

    @EnvironmentObject var companyStore: CompanyStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var skillStore = SkillStore.shared

    @State private var name = ""
    @State private var aiType: AIType = .claude
    @State private var selectedDepartmentType: DepartmentType?
    @State private var selectedJobRoles: Set<JobRole> = []
    @State private var selectedSkillIds: Set<String> = []  // 사용자가 직접 선택한 스킬
    @State private var appearance = CharacterAppearance.random()
    @State private var sourceMode: SourceMode = .new
    @State private var selectedSourceEmployee: Employee?

    enum SourceMode: String, CaseIterable {
        case new = "새로 생성"
        case copy = "회사 직원에서 복제"
    }

    var project: Project? {
        companyStore.company.projects.first { $0.id == projectId }
    }

    var isValid: Bool {
        if sourceMode == .copy {
            return selectedSourceEmployee != nil && selectedDepartmentType != nil
        }
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            selectedDepartmentType != nil &&
            !selectedJobRoles.isEmpty
    }

    var selectedDepartment: ProjectDepartment? {
        guard let type = selectedDepartmentType, let project = project else { return nil }
        return project.getDepartment(byType: type)
    }

    var availableJobRoles: [JobRole] {
        guard let type = selectedDepartmentType else { return [.general] }
        return JobRole.roles(for: type)
    }
    
    /// 선택된 직군들에 대한 추천 스킬 ID 목록
    func getRecommendedSkillIds() -> Set<String> {
        var allSkillIds = Set<String>()
        for role in selectedJobRoles {
            let skillIds = BuiltInSkills.recommendedSkillIds(for: role)
            allSkillIds.formUnion(skillIds)
        }
        return allSkillIds
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("직원을 고용합니다")
                    .font(.title2.bold())
                Spacer()
                Button("취소") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
            }
            .padding()

            Divider()

            HStack(spacing: 0) {
                // Form
                Form {
                    // 소스 선택
                    Section("직원 추가 방법") {
                        Picker("방법", selection: $sourceMode) {
                            ForEach(SourceMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.radioGroup)
                    }

                    if sourceMode == .new {
                        // 새로 생성
                        Section {
                            HStack {
                                TextField("직원 이름", text: $name)
                                    .textFieldStyle(.roundedBorder)
                                
                                Button {
                                    name = RandomEmployeeNames.random()
                                } label: {
                                    Image(systemName: "dice.fill")
                                }
                                .buttonStyle(.bordered)
                                .help("랜덤 이름 생성")
                            }

                            Text("예: Claude-기획, GPT-디자인")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }

                        Section("AI 유형") {
                            Picker("AI", selection: $aiType) {
                                ForEach(AIType.allCases, id: \.self) { type in
                                    HStack {
                                        Image(systemName: type.icon)
                                            .foregroundStyle(type.color)
                                        Text(type.rawValue)
                                    }
                                    .tag(type)
                                }
                            }
                            .pickerStyle(.radioGroup)

                            if aiType == .claude {
                                Label("Claude Code 사용 (API 키 불필요)", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.body)
                            } else if let config = companyStore.getAPIConfiguration(for: aiType), config.isConfigured {
                                Label("API 설정됨", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.body)
                            } else {
                                Label("설정에서 \(aiType.rawValue) API 키를 추가하세요", systemImage: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                    .font(.body)
                            }
                        }
                    } else {
                        // 회사 직원에서 복제
                        Section("복제할 직원 선택") {
                            Picker("직원", selection: $selectedSourceEmployee) {
                                Text("선택하세요").tag(nil as Employee?)

                                ForEach(companyStore.company.allEmployees) { employee in
                                    HStack {
                                        Image(systemName: employee.aiType.icon)
                                            .foregroundStyle(employee.aiType.color)
                                        Text(employee.name)
                                    }
                                    .tag(employee as Employee?)
                                }
                            }

                            if let employee = selectedSourceEmployee {
                                VStack(alignment: .leading, spacing: 4) {
                                    Label(employee.aiType.rawValue, systemImage: employee.aiType.icon)
                                        .foregroundStyle(employee.aiType.color)
                                    Text("대화 기록은 초기화됩니다")
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    Section("부서 배치") {
                        if let project = project {
                            Picker("부서", selection: $selectedDepartmentType) {
                                Text("선택하세요").tag(nil as DepartmentType?)

                                ForEach(project.departments) { dept in
                                    HStack {
                                        Image(systemName: dept.type.icon)
                                            .foregroundStyle(dept.type.color)
                                        Text(dept.name)
                                        Spacer()
                                        Text("\(dept.employees.count)/\(dept.maxCapacity)")
                                            .foregroundStyle(dept.isFull ? .red : .secondary)
                                    }
                                    .tag(dept.type as DepartmentType?)
                                }
                            }
                            .onChange(of: selectedDepartmentType) { oldValue, newValue in
                                // 부서가 변경되면 직군 선택 초기화
                                selectedJobRoles.removeAll()
                            }

                            if let dept = selectedDepartment {
                                if dept.isFull {
                                    Label("이 부서는 가득 찼습니다", systemImage: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.red)
                                        .font(.callout)
                                } else {
                                    Text("남은 자리: \(dept.availableSlots)")
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    if sourceMode == .new && selectedDepartmentType != nil && !availableJobRoles.isEmpty {
                        Section("직군 선택 (복수 선택 가능)") {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(availableJobRoles, id: \.self) { role in
                                    Button {
                                        if selectedJobRoles.contains(role) {
                                            selectedJobRoles.remove(role)
                                            // 해당 직군의 추천 스킬 제거
                                            let skillsToRemove = BuiltInSkills.recommendedSkillIds(for: role)
                                            selectedSkillIds.subtract(skillsToRemove)
                                        } else {
                                            selectedJobRoles.insert(role)
                                            // 해당 직군의 추천 스킬 자동 추가
                                            let skillsToAdd = BuiltInSkills.recommendedSkillIds(for: role)
                                            selectedSkillIds.formUnion(skillsToAdd)
                                        }
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: selectedJobRoles.contains(role) ? "checkmark.square.fill" : "square")
                                                .foregroundStyle(selectedJobRoles.contains(role) ? .blue : .secondary)
                                                .font(.title3)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(role.rawValue)
                                                    .font(.body)
                                                    .foregroundStyle(.primary)
                                                Text(role.description)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(2)
                                            }

                                            Spacer()
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.vertical, 4)
                                }
                            }

                            if !selectedJobRoles.isEmpty {
                                Divider()
                                Text("선택한 직군: \(selectedJobRoles.map { $0.rawValue }.joined(separator: ", "))")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    // 스킬 선택 섹션 (직군 선택과 별개로 자유롭게 선택 가능)
                    if sourceMode == .new {
                        Section {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("스킬 선택")
                                    .font(.headline)
                                Text("직군에 맞는 스킬이 자동 선택됩니다. 자유롭게 추가하거나 제거할 수 있습니다.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.bottom, 8)
                            
                            if skillStore.skills.isEmpty {
                                Text("등록된 스킬이 없습니다. 에이전트 허브에서 스킬을 추가하세요.")
                                    .foregroundStyle(.secondary)
                            } else {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(skillStore.skills) { skill in
                                        let isSelected = selectedSkillIds.contains(skill.id)
                                        let isRecommended = getRecommendedSkillIds().contains(skill.id)
                                        
                                        Button {
                                            if isSelected {
                                                selectedSkillIds.remove(skill.id)
                                            } else {
                                                selectedSkillIds.insert(skill.id)
                                            }
                                        } label: {
                                            HStack(spacing: 10) {
                                                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                                                    .foregroundStyle(isSelected ? skill.category.color : .secondary)
                                                    .font(.title3)
                                                
                                                Image(systemName: skill.category.icon)
                                                    .foregroundStyle(skill.category.color)
                                                    .frame(width: 18)
                                                
                                                VStack(alignment: .leading, spacing: 2) {
                                                    HStack(spacing: 4) {
                                                        Text(skill.name)
                                                            .font(.callout)
                                                            .foregroundStyle(.primary)
                                                        
                                                        if isRecommended && !selectedJobRoles.isEmpty {
                                                            Text("추천")
                                                                .font(.caption2)
                                                                .padding(.horizontal, 4)
                                                                .padding(.vertical, 1)
                                                                .background(Color.blue.opacity(0.2))
                                                                .foregroundStyle(.blue)
                                                                .clipShape(Capsule())
                                                        }
                                                        
                                                        if skill.isCustom {
                                                            Text("커스텀")
                                                                .font(.caption2)
                                                                .padding(.horizontal, 4)
                                                                .padding(.vertical, 1)
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
                                            }
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        .padding(.vertical, 3)
                                        .padding(.horizontal, 8)
                                        .background(isSelected ? skill.category.color.opacity(0.1) : Color.clear)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                }
                                
                                if !selectedSkillIds.isEmpty {
                                    Divider()
                                    HStack {
                                        Text("선택된 스킬: \(selectedSkillIds.count)개")
                                            .font(.callout)
                                            .foregroundStyle(.blue)
                                        
                                        Spacer()
                                        
                                        Button("모두 해제") {
                                            selectedSkillIds.removeAll()
                                        }
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                .formStyle(.grouped)
                .frame(width: 420)

                Divider()

                // Character Preview (with scroll)
                ScrollView {
                    VStack(spacing: 20) {
                        Text("캐릭터 미리보기")
                            .font(.headline)

                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.secondary.opacity(0.1))
                                .frame(width: 180, height: 180)

                            PixelCharacter(
                                appearance: sourceMode == .copy ? (selectedSourceEmployee?.characterAppearance ?? appearance) : appearance,
                                status: .idle,
                                aiType: sourceMode == .copy ? (selectedSourceEmployee?.aiType ?? aiType) : aiType
                            )
                            .scaleEffect(2.5)
                        }

                        if sourceMode == .new {
                            // Appearance customization
                            VStack(alignment: .leading, spacing: 12) {
                                ProjectAppearancePicker(
                                    title: "피부색",
                                    value: $appearance.skinTone,
                                    max: 3,
                                    getName: { CharacterAppearance.skinToneName($0) },
                                    appearance: appearance,
                                    aiType: aiType,
                                    attributeType: .skinTone
                                )
                                ProjectAppearancePicker(
                                    title: "헤어 스타일",
                                    value: $appearance.hairStyle,
                                    max: 11,
                                    getName: { CharacterAppearance.hairStyleName($0) },
                                    appearance: appearance,
                                    aiType: aiType,
                                    attributeType: .hairStyle
                                )
                                ProjectAppearancePicker(
                                    title: "헤어 색상",
                                    value: $appearance.hairColor,
                                    max: 8,
                                    getName: { CharacterAppearance.hairColorName($0) },
                                    appearance: appearance,
                                    aiType: aiType,
                                    attributeType: .hairColor
                                )
                                ProjectAppearancePicker(
                                    title: "셔츠 색상",
                                    value: $appearance.shirtColor,
                                    max: 11,
                                    getName: { CharacterAppearance.shirtColorName($0) },
                                    appearance: appearance,
                                    aiType: aiType,
                                    attributeType: .shirtColor
                                )
                                ProjectAppearancePicker(
                                    title: "악세서리",
                                    value: $appearance.accessory,
                                    max: 9,
                                    getName: { CharacterAppearance.accessoryName($0) },
                                    appearance: appearance,
                                    aiType: aiType,
                                    attributeType: .accessory
                                )
                                ProjectAppearancePicker(
                                    title: "표정",
                                    value: $appearance.expression,
                                    max: 4,
                                    getName: { CharacterAppearance.expressionName($0) },
                                    appearance: appearance,
                                    aiType: aiType,
                                    attributeType: .expression
                                )
                            }
                            .padding()

                            Button("랜덤 생성") {
                                withAnimation {
                                    appearance = CharacterAppearance.random()
                                }
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Text("외형은 원본 직원과 동일합니다")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .padding()
                        }
                    }
                    .padding()
                }
                .frame(width: 320)
            }

            Divider()

            // Actions
            HStack {
                Spacer()

                Button("취소") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Button("고용하기") {
                    createEmployee()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(!isValid || (selectedDepartment?.isFull ?? true))
            }
            .padding()
        }
        .frame(width: 800, height: 700)
        .onAppear {
            if let deptType = preselectedDepartmentType {
                selectedDepartmentType = deptType
            }
        }
    }

    private func createEmployee() {
        guard let deptType = selectedDepartmentType else { return }

        let employee: ProjectEmployee

        if sourceMode == .copy, let source = selectedSourceEmployee {
            employee = ProjectEmployee.from(employee: source, departmentType: deptType)
        } else {
            // 🐛 디버그: 미리보기 외모 정보 출력
            print("🎭 [프로젝트 직원 추가] 미리보기 외모:")
            print("   피부색: \(appearance.skinTone)")
            print("   헤어스타일: \(appearance.hairStyle)")
            print("   헤어색: \(appearance.hairColor)")
            print("   셔츠색: \(appearance.shirtColor)")
            print("   악세서리: \(appearance.accessory)")
            print("   표정: \(appearance.expression)")
            
            employee = ProjectEmployee(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                aiType: aiType,
                jobRoles: Array(selectedJobRoles),
                status: .idle,
                characterAppearance: appearance,
                departmentType: deptType,
                skillIds: Array(selectedSkillIds)
            )
            
            // 🐛 디버그: 생성된 직원의 외모 정보 출력
            print("👤 [프로젝트 직원 추가] 생성된 직원 '\(employee.name)'의 외모:")
            print("   피부색: \(employee.characterAppearance.skinTone)")
            print("   헤어스타일: \(employee.characterAppearance.hairStyle)")
            print("   헤어색: \(employee.characterAppearance.hairColor)")
            print("   셔츠색: \(employee.characterAppearance.shirtColor)")
            print("   악세서리: \(employee.characterAppearance.accessory)")
            print("   표정: \(employee.characterAppearance.expression)")
        }

        companyStore.addProjectEmployee(employee, toProject: projectId, department: deptType)
        dismiss()
    }
}

private struct ProjectAppearancePicker: View {
    let title: String
    @Binding var value: Int
    let max: Int
    let getName: (Int) -> String
    var appearance: CharacterAppearance
    var aiType: AIType
    var attributeType: ProjectAppearanceAttributeType

    enum ProjectAppearanceAttributeType {
        case skinTone, hairStyle, hairColor, shirtColor, accessory, expression
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.callout.bold())
                Spacer()
                Text(getName(value))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(0...max, id: \.self) { i in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                value = i
                            }
                        } label: {
                            VStack(spacing: 4) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.gray.opacity(0.1))
                                        .frame(width: 40, height: 40)

                                    // 미니 캐릭터 썸네일
                                    PixelCharacter(
                                        appearance: previewAppearance(for: i),
                                        status: .idle,
                                        aiType: aiType
                                    )
                                    .scaleEffect(0.6)
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(
                                            value == i ? Color.accentColor : Color.clear,
                                            lineWidth: 2
                                        )
                                )

                                Text("\(i)")
                                    .font(.caption2)
                                    .foregroundStyle(value == i ? .primary : .secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .help(getName(i))
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func previewAppearance(for index: Int) -> CharacterAppearance {
        var preview = appearance
        switch attributeType {
        case .skinTone:
            preview.skinTone = index
        case .hairStyle:
            preview.hairStyle = index
        case .hairColor:
            preview.hairColor = index
        case .shirtColor:
            preview.shirtColor = index
        case .accessory:
            preview.accessory = index
        case .expression:
            preview.expression = index
        }
        return preview
    }
}

// MARK: - Random Employee Names

enum RandomEmployeeNames {
    static let names: [String] = [
        // 한국 이름
        "지민", "서연", "하준", "수빈", "민준", "예진", "도윤", "채원", "시우", "유나",
        "현우", "소희", "준서", "다은", "우진", "지유", "건우", "서현", "지호", "은서",
        "민서", "하린", "예준", "윤아", "시현", "수아", "재민", "나윤", "태민", "지원",
        
        // 영어 이름
        "Alex", "Jordan", "Taylor", "Morgan", "Casey", "Riley", "Quinn", "Avery",
        "Charlie", "Sam", "Jamie", "Drew", "Sage", "Rowan", "Finley", "Hayden",
        "Parker", "Reese", "Skyler", "Dakota", "Robin", "Cameron", "Jessie", "Kai",
        
        // AI/테크 감성 이름
        "Nova", "Luna", "Orion", "Atlas", "Phoenix", "Cleo", "Neo", "Echo",
        "Pixel", "Byte", "Logic", "Syntax", "Vector", "Delta", "Sigma", "Alpha",
        "Zenith", "Cosmo", "Astro", "Cipher", "Matrix", "Prism", "Quasar", "Nexus",
        
        // 귀여운 닉네임
        "코코", "모모", "뽀뽀", "두부", "콩이", "망고", "초코", "라떼", "우유", "딸기",
        "푸딩", "버블", "허니", "캔디", "쿠키", "머핀", "와플", "마카롱", "젤리", "팝콘",
        
        // 조합형 (AI + 역할)
        "Claude-α", "GPT-β", "Gemini-γ", "Claude-X", "GPT-Z", "AI-01", "Bot-7",
        "Agent-K", "Helper-J", "Assist-M", "Claude-Pro", "GPT-Max", "AI-Ace",
        
        // 유명 AI/로봇 이름에서 영감
        "Jarvis", "Friday", "Karen", "Edith", "Samantha", "Ava", "Hal", "Data",
        "Bishop", "Sonny", "Chappie", "Tars", "Case", "Gerty", "Marvin", "R2",
        
        // 자연에서 영감
        "Willow", "River", "Storm", "Cloud", "Sunny", "Aurora", "Coral", "Ivy",
        "Maple", "Jasper", "Sage", "Brook", "Cliff", "Glen", "Flora", "Stone"
    ]
    
    static func random() -> String {
        names.randomElement() ?? "AI-직원"
    }
    
    static func random(count: Int) -> [String] {
        Array(names.shuffled().prefix(count))
    }
}

#Preview {
    AddProjectEmployeeView(projectId: UUID())
        .environmentObject(CompanyStore())
}
