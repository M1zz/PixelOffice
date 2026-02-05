import SwiftUI

struct AddEmployeeView: View {
    var preselectedDepartment: Department?
    var preselectedDepartmentId: UUID?  // WindowGroup용

    @EnvironmentObject var companyStore: CompanyStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var aiType: AIType = .claude
    @State private var selectedDepartmentId: UUID?
    @State private var selectedJobRoles: Set<JobRole> = []
    @State private var appearance = CharacterAppearance.random()

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedDepartmentId != nil &&
        !selectedJobRoles.isEmpty
    }

    var selectedDepartment: Department? {
        guard let id = selectedDepartmentId else { return nil }
        return companyStore.getDepartment(byId: id)
    }

    var availableJobRoles: [JobRole] {
        guard let dept = selectedDepartment else { return [.general] }
        return JobRole.roles(for: dept.type)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("새 AI 직원")
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
                        
                        // API Configuration status
                        if aiType == .claude {
                            // Claude는 Claude Code CLI 사용 (API 키 불필요)
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
                    
                    Section("부서 배치") {
                        Picker("부서", selection: $selectedDepartmentId) {
                            Text("선택하세요").tag(nil as UUID?)

                            ForEach(companyStore.company.departments) { dept in
                                HStack {
                                    Image(systemName: dept.type.icon)
                                        .foregroundStyle(dept.type.color)
                                    Text(dept.name)
                                    Spacer()
                                    Text("\(dept.employees.count)/\(dept.maxCapacity)")
                                        .foregroundStyle(dept.isFull ? .red : .secondary)
                                }
                                .tag(dept.id as UUID?)
                            }
                        }
                        .onChange(of: selectedDepartmentId) { oldValue, newValue in
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

                    if selectedDepartmentId != nil && !availableJobRoles.isEmpty {
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
                }
                .formStyle(.grouped)
                .frame(width: 300)
                
                Divider()
                
                // Character Preview
                ScrollView {
                    VStack(spacing: 20) {
                        Text("캐릭터 미리보기")
                            .font(.headline)

                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.secondary.opacity(0.1))
                                .frame(width: 200, height: 200)

                            PixelCharacter(
                                appearance: appearance,
                                status: .idle,
                                aiType: aiType
                            )
                            .scaleEffect(3)
                        }

                        // Appearance customization
                        VStack(alignment: .leading, spacing: 16) {
                            AppearancePickerWithName(
                                title: "피부색",
                                value: $appearance.skinTone,
                                max: 3,
                                getName: { CharacterAppearance.skinToneName($0) },
                                appearance: appearance,
                                aiType: aiType,
                                attributeType: .skinTone
                            )

                            AppearancePickerWithName(
                                title: "헤어 스타일",
                                value: $appearance.hairStyle,
                                max: 11,
                                getName: { CharacterAppearance.hairStyleName($0) },
                                appearance: appearance,
                                aiType: aiType,
                                attributeType: .hairStyle
                            )

                            AppearancePickerWithName(
                                title: "헤어 색상",
                                value: $appearance.hairColor,
                                max: 8,
                                getName: { CharacterAppearance.hairColorName($0) },
                                appearance: appearance,
                                aiType: aiType,
                                attributeType: .hairColor
                            )

                            AppearancePickerWithName(
                                title: "셔츠 색상",
                                value: $appearance.shirtColor,
                                max: 11,
                                getName: { CharacterAppearance.shirtColorName($0) },
                                appearance: appearance,
                                aiType: aiType,
                                attributeType: .shirtColor
                            )

                            AppearancePickerWithName(
                                title: "악세서리",
                                value: $appearance.accessory,
                                max: 9,
                                getName: { CharacterAppearance.accessoryName($0) },
                                appearance: appearance,
                                aiType: aiType,
                                attributeType: .accessory
                            )

                            AppearancePickerWithName(
                                title: "표정",
                                value: $appearance.expression,
                                max: 4,
                                getName: { CharacterAppearance.expressionName($0) },
                                appearance: appearance,
                                aiType: aiType,
                                attributeType: .expression
                            )
                        }
                        .padding(.horizontal)

                        Button("랜덤 생성") {
                            withAnimation {
                                appearance = CharacterAppearance.random()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                }
                .frame(width: 300)
            }
            
            Divider()
            
            // Actions
            HStack {
                Spacer()
                
                Button("취소") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Button("고용") {
                    createEmployee()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
                .disabled(!isValid || (selectedDepartment?.isFull ?? true))
            }
            .padding()
        }
        .frame(width: 650, height: 600)
        .onAppear {
            if let dept = preselectedDepartment {
                selectedDepartmentId = dept.id
            } else if let deptId = preselectedDepartmentId,
                      companyStore.getDepartment(byId: deptId) != nil {
                // 유효한 부서 ID인 경우에만 설정
                selectedDepartmentId = deptId
            }
        }
    }

    private func createEmployee() {
        guard let deptId = selectedDepartmentId,
              let dept = selectedDepartment else { return }

        // 🐛 디버그: 미리보기 외모 정보 출력
        print("🎭 [직원추가] 미리보기 외모:")
        print("   피부색: \(appearance.skinTone)")
        print("   헤어스타일: \(appearance.hairStyle)")
        print("   헤어색: \(appearance.hairColor)")
        print("   셔츠색: \(appearance.shirtColor)")
        print("   악세서리: \(appearance.accessory)")
        print("   표정: \(appearance.expression)")

        let employee = Employee(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            aiType: aiType,
            jobRoles: Array(selectedJobRoles),
            status: .idle,
            characterAppearance: appearance
        )

        // 🐛 디버그: 생성된 직원의 외모 정보 출력
        print("👤 [직원추가] 생성된 직원 \(employee.name)의 외모:")
        print("   피부색: \(employee.characterAppearance.skinTone)")
        print("   헤어스타일: \(employee.characterAppearance.hairStyle)")
        print("   헤어색: \(employee.characterAppearance.hairColor)")
        print("   셔츠색: \(employee.characterAppearance.shirtColor)")
        print("   악세서리: \(employee.characterAppearance.accessory)")
        print("   표정: \(employee.characterAppearance.expression)")

        companyStore.addEmployee(employee, toDepartment: deptId)

        // 온보딩 질문 생성 (나중에 답변할 수 있도록)
        let onboarding = EmployeeOnboarding(
            employeeId: employee.id,
            questions: OnboardingTemplate.questions(for: dept.type)
        )
        companyStore.addOnboarding(onboarding)

        // 바로 창 닫기 (온보딩 팝업 없이)
        dismiss()
    }
}

struct AppearancePickerWithName: View {
    let title: String
    @Binding var value: Int
    let max: Int
    let getName: (Int) -> String
    var appearance: CharacterAppearance
    var aiType: AIType
    var attributeType: AppearanceAttributeType

    enum AppearanceAttributeType {
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
    AddEmployeeView()
        .environmentObject(CompanyStore())
}
