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
                            TextField("직원 이름", text: $name)
                                .textFieldStyle(.roundedBorder)

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
                                        } else {
                                            selectedJobRoles.insert(role)
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
                    
                    // 적용되는 스킬 표시
                    if !selectedJobRoles.isEmpty {
                        Section("적용되는 스킬") {
                            let recommendedSkillIds = getRecommendedSkillIds()
                            let matchedSkills = skillStore.skills.filter { recommendedSkillIds.contains($0.id) }
                            
                            if matchedSkills.isEmpty {
                                Text("매칭되는 스킬이 없습니다")
                                    .foregroundStyle(.secondary)
                            } else {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(matchedSkills) { skill in
                                        HStack(spacing: 10) {
                                            Image(systemName: skill.category.icon)
                                                .foregroundStyle(skill.category.color)
                                                .frame(width: 20)
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                HStack {
                                                    Text(skill.name)
                                                        .font(.callout.bold())
                                                    
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
                                            
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.green)
                                        }
                                        .padding(.vertical, 2)
                                    }
                                }
                                
                                Divider()
                                
                                Text("총 \(matchedSkills.count)개 스킬 적용")
                                    .font(.callout)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
                .formStyle(.grouped)
                .frame(width: 300)

                Divider()

                // Character Preview (with scroll)
                ScrollView {
                    VStack(spacing: 20) {
                        Text("캐릭터 미리보기")
                            .font(.headline)

                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.secondary.opacity(0.1))
                                .frame(width: 150, height: 150)

                            PixelCharacter(
                                appearance: sourceMode == .copy ? (selectedSourceEmployee?.characterAppearance ?? appearance) : appearance,
                                status: .idle,
                                aiType: sourceMode == .copy ? (selectedSourceEmployee?.aiType ?? aiType) : aiType
                            )
                            .scaleEffect(2)
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
                .frame(width: 250)
            }

            Divider()

            // Actions
            HStack {
                Spacer()

                Button("취소") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Button("추가") {
                    createEmployee()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(!isValid || (selectedDepartment?.isFull ?? true))
            }
            .padding()
        }
        .frame(width: 600, height: 600)
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
            employee = ProjectEmployee(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                aiType: aiType,
                jobRoles: Array(selectedJobRoles),
                status: .idle,
                characterAppearance: appearance,
                departmentType: deptType
            )
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

#Preview {
    AddProjectEmployeeView(projectId: UUID())
        .environmentObject(CompanyStore())
}
