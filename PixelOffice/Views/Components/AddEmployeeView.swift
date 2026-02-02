import SwiftUI

struct AddEmployeeView: View {
    var preselectedDepartment: Department?
    var preselectedDepartmentId: UUID?  // WindowGroup용

    @EnvironmentObject var companyStore: CompanyStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var aiType: AIType = .claude
    @State private var selectedDepartmentId: UUID?
    @State private var appearance = CharacterAppearance.random()
    
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        selectedDepartmentId != nil
    }
    
    var selectedDepartment: Department? {
        guard let id = selectedDepartmentId else { return nil }
        return companyStore.getDepartment(byId: id)
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
                .formStyle(.grouped)
                .frame(width: 300)
                
                Divider()
                
                // Character Preview
                VStack(spacing: 20) {
                    Text("캐릭터 미리보기")
                        .font(.headline)
                    
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.secondary.opacity(0.1))
                            .frame(width: 150, height: 150)

                        PixelCharacter(
                            appearance: appearance,
                            status: .idle,
                            aiType: aiType
                        )
                        .scaleEffect(2)
                    }
                    
                    // Appearance customization
                    VStack(alignment: .leading, spacing: 12) {
                        AppearancePicker(title: "피부색", value: $appearance.skinTone, max: 3)
                        AppearancePicker(title: "헤어 스타일", value: $appearance.hairStyle, max: 4)
                        AppearancePicker(title: "헤어 색상", value: $appearance.hairColor, max: 5)
                        AppearancePicker(title: "셔츠 색상", value: $appearance.shirtColor, max: 7)
                        AppearancePicker(title: "악세서리", value: $appearance.accessory, max: 3)
                    }
                    .padding()
                    
                    Button("랜덤 생성") {
                        withAnimation {
                            appearance = CharacterAppearance.random()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(width: 250)
                .padding()
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
        .frame(width: 600, height: 550)
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

        let employee = Employee(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            aiType: aiType,
            status: .idle,
            characterAppearance: appearance
        )

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

struct AppearancePicker: View {
    let title: String
    @Binding var value: Int
    let max: Int
    
    var body: some View {
        HStack {
            Text(title)
                .font(.callout)
                .frame(width: 80, alignment: .leading)
            
            HStack(spacing: 4) {
                ForEach(0...max, id: \.self) { i in
                    Button {
                        value = i
                    } label: {
                        Circle()
                            .fill(value == i ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

#Preview {
    AddEmployeeView()
        .environmentObject(CompanyStore())
}
