import SwiftUI

/// 프로젝트에 직원 추가하는 뷰
struct AddProjectEmployeeView: View {
    let projectId: UUID
    var preselectedDepartmentType: DepartmentType?

    @EnvironmentObject var companyStore: CompanyStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var aiType: AIType = .claude
    @State private var selectedDepartmentType: DepartmentType?
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
            selectedDepartmentType != nil
    }

    var selectedDepartment: ProjectDepartment? {
        guard let type = selectedDepartmentType, let project = project else { return nil }
        return project.getDepartment(byType: type)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("프로젝트 직원 추가")
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
                                    getName: { CharacterAppearance.skinToneName($0) }
                                )
                                ProjectAppearancePicker(
                                    title: "헤어 스타일",
                                    value: $appearance.hairStyle,
                                    max: 11,
                                    getName: { CharacterAppearance.hairStyleName($0) }
                                )
                                ProjectAppearancePicker(
                                    title: "헤어 색상",
                                    value: $appearance.hairColor,
                                    max: 8,
                                    getName: { CharacterAppearance.hairColorName($0) }
                                )
                                ProjectAppearancePicker(
                                    title: "셔츠 색상",
                                    value: $appearance.shirtColor,
                                    max: 11,
                                    getName: { CharacterAppearance.shirtColorName($0) }
                                )
                                ProjectAppearancePicker(
                                    title: "악세서리",
                                    value: $appearance.accessory,
                                    max: 9,
                                    getName: { CharacterAppearance.accessoryName($0) }
                                )
                                ProjectAppearancePicker(
                                    title: "표정",
                                    value: $appearance.expression,
                                    max: 4,
                                    getName: { CharacterAppearance.expressionName($0) }
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
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(value == i ? Color.accentColor : Color.gray.opacity(0.2))
                                    .frame(width: 32, height: 32)
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
}

#Preview {
    AddProjectEmployeeView(projectId: UUID())
        .environmentObject(CompanyStore())
}
