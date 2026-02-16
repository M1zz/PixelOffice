import SwiftUI

/// 프로젝트(입주사)별 부서 관리 뷰
struct DepartmentManagerView: View {
    let projectId: UUID
    @EnvironmentObject var companyStore: CompanyStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingAddDepartment = false
    @State private var editingDepartment: ProjectDepartment?
    
    var project: Project? {
        companyStore.company.projects.first { $0.id == projectId }
    }
    
    var availableDepartmentTypes: [DepartmentType] {
        guard let project = project else { return DepartmentType.allCases.filter { $0 != .general } }
        let existingTypes = Set(project.departments.map { $0.type })
        return DepartmentType.allCases.filter { $0 != .general && !existingTypes.contains($0) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("부서 관리")
                        .font(.title2.bold())
                    if let project = project {
                        Text(project.name)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Button("완료") {
                    dismiss()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
            .padding()
            
            Divider()
            
            // Department List
            if let project = project {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(project.departments) { department in
                            DepartmentRow(
                                department: department,
                                onEdit: {
                                    editingDepartment = department
                                },
                                onDelete: {
                                    deleteDepartment(department)
                                }
                            )
                        }
                        
                        // Add Department Button (항상 표시 - 커스텀 부서는 무제한 추가 가능)
                        Button {
                            showingAddDepartment = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                Text("부서 추가")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                }
            }
        }
        .frame(width: 500, height: 500)
        .sheet(isPresented: $showingAddDepartment) {
            AddDepartmentSheet(
                projectId: projectId,
                availableTypes: availableDepartmentTypes
            )
        }
        .sheet(item: $editingDepartment) { department in
            EditDepartmentSheet(
                projectId: projectId,
                department: department
            )
        }
    }
    
    private func deleteDepartment(_ department: ProjectDepartment) {
        companyStore.removeDepartmentById(department.id, fromProject: projectId)
    }
}

// MARK: - Department Row

private struct DepartmentRow: View {
    let department: ProjectDepartment
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var showingDeleteConfirm = false
    
    var canDelete: Bool {
        department.employees.isEmpty
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(department.color.opacity(0.2))
                    .frame(width: 50, height: 50)
                Image(systemName: department.icon)
                    .font(.title2)
                    .foregroundStyle(department.color)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(department.name)
                    .font(.headline)
                
                HStack(spacing: 12) {
                    Label("\(department.employees.count)/\(department.maxCapacity)명",
                          systemImage: "person.2.fill")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    
                    if department.isFull {
                        Text("만석")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    }
                }
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 8) {
                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.bordered)
                .help("부서 설정 편집")
                
                Button {
                    showingDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(!canDelete)
                .help(canDelete ? "부서 삭제" : "직원이 있는 부서는 삭제할 수 없습니다")
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .alert("부서 삭제", isPresented: $showingDeleteConfirm) {
            Button("취소", role: .cancel) { }
            Button("삭제", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("'\(department.name)' 부서를 삭제하시겠습니까?")
        }
    }
}

// MARK: - Add Department Sheet

private struct AddDepartmentSheet: View {
    let projectId: UUID
    let availableTypes: [DepartmentType]
    
    @EnvironmentObject var companyStore: CompanyStore
    @Environment(\.dismiss) private var dismiss
    
    enum DepartmentMode: String, CaseIterable {
        case preset = "기본 부서"
        case custom = "커스텀 부서"
    }
    
    @State private var mode: DepartmentMode
    @State private var selectedType: DepartmentType?
    @State private var maxCapacity: Int = 4
    
    init(projectId: UUID, availableTypes: [DepartmentType]) {
        self.projectId = projectId
        self.availableTypes = availableTypes
        // 기본 부서가 다 추가됐으면 커스텀 모드로 시작
        self._mode = State(initialValue: availableTypes.isEmpty ? .custom : .preset)
    }
    
    // 커스텀 부서용
    @State private var customName: String = ""
    @State private var selectedIcon: String = "briefcase.fill"
    @State private var selectedColorIndex: Int = 0
    
    let availableIcons = [
        "briefcase.fill", "building.2.fill", "person.3.fill",
        "chart.bar.fill", "doc.text.fill", "folder.fill",
        "star.fill", "heart.fill", "bolt.fill",
        "gear", "wrench.fill", "hammer.fill",
        "cart.fill", "bag.fill", "creditcard.fill",
        "phone.fill", "envelope.fill", "globe",
        "book.fill", "graduationcap.fill", "lightbulb.fill"
    ]
    
    let availableColors: [(name: String, hex: String)] = [
        ("파랑", "007AFF"),
        ("초록", "34C759"),
        ("주황", "FF9500"),
        ("빨강", "FF3B30"),
        ("보라", "AF52DE"),
        ("분홍", "FF2D55"),
        ("청록", "5AC8FA"),
        ("노랑", "FFCC00"),
        ("민트", "00C7BE"),
        ("인디고", "5856D6")
    ]
    
    var isValid: Bool {
        if mode == .preset {
            return selectedType != nil
        } else {
            return !customName.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("부서 추가")
                    .font(.title3.bold())
                Spacer()
                Button("취소") {
                    dismiss()
                }
            }
            .padding()
            
            Divider()
            
            Form {
                // 모드 선택
                Section {
                    Picker("부서 유형", selection: $mode) {
                        ForEach(DepartmentMode.allCases, id: \.self) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                if mode == .preset {
                    // 기본 부서 선택
                    Section("부서 선택") {
                        if availableTypes.isEmpty {
                            Text("모든 기본 부서가 이미 추가되어 있습니다")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(availableTypes, id: \.self) { type in
                                Button {
                                    selectedType = type
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: selectedType == type ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(selectedType == type ? .blue : .secondary)
                                        
                                        Image(systemName: type.icon)
                                            .foregroundStyle(type.color)
                                            .frame(width: 24)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(type.rawValue)
                                                .font(.body)
                                                .foregroundStyle(.primary)
                                            Text(type.description)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)
                                .padding(.vertical, 4)
                            }
                        }
                    }
                } else {
                    // 커스텀 부서
                    Section("부서 이름") {
                        TextField("예: 고객지원팀, 인사팀, 재무팀", text: $customName)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    Section("아이콘") {
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(44)), count: 7), spacing: 8) {
                            ForEach(availableIcons, id: \.self) { icon in
                                Button {
                                    selectedIcon = icon
                                } label: {
                                    Image(systemName: icon)
                                        .font(.title3)
                                        .frame(width: 40, height: 40)
                                        .background(selectedIcon == icon ? Color.accentColor.opacity(0.2) : Color.clear)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(selectedIcon == icon ? Color.accentColor : Color.clear, lineWidth: 2)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    Section("색상") {
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(44)), count: 5), spacing: 8) {
                            ForEach(Array(availableColors.enumerated()), id: \.offset) { index, colorInfo in
                                Button {
                                    selectedColorIndex = index
                                } label: {
                                    Circle()
                                        .fill(Color(hex: colorInfo.hex))
                                        .frame(width: 36, height: 36)
                                        .overlay(
                                            Circle()
                                                .stroke(selectedColorIndex == index ? Color.primary : Color.clear, lineWidth: 3)
                                        )
                                }
                                .buttonStyle(.plain)
                                .help(colorInfo.name)
                            }
                        }
                    }
                    
                    // 미리보기
                    Section("미리보기") {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color(hex: availableColors[selectedColorIndex].hex).opacity(0.2))
                                    .frame(width: 44, height: 44)
                                Image(systemName: selectedIcon)
                                    .font(.title2)
                                    .foregroundStyle(Color(hex: availableColors[selectedColorIndex].hex))
                            }
                            
                            Text(customName.isEmpty ? "부서 이름" : customName)
                                .font(.headline)
                                .foregroundStyle(customName.isEmpty ? .secondary : .primary)
                        }
                    }
                }
                
                Section("정원 설정") {
                    Stepper("최대 \(maxCapacity)명", value: $maxCapacity, in: 1...10)
                    
                    Text("부서에 배치할 수 있는 최대 직원 수")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            
            Divider()
            
            HStack {
                Spacer()
                Button("취소") {
                    dismiss()
                }
                Button("추가") {
                    addDepartment()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 450, height: mode == .custom ? 620 : 450)
    }
    
    private func addDepartment() {
        let department: ProjectDepartment
        
        if mode == .preset, let type = selectedType {
            department = ProjectDepartment(
                type: type,
                maxCapacity: maxCapacity,
                position: DeskPosition(row: 0, column: 0)
            )
        } else {
            // 커스텀 부서
            department = ProjectDepartment(
                type: .general,
                maxCapacity: maxCapacity,
                position: DeskPosition(row: 0, column: 0),
                customName: customName.trimmingCharacters(in: .whitespaces),
                customIcon: selectedIcon,
                customColorHex: availableColors[selectedColorIndex].hex
            )
        }
        
        companyStore.addDepartment(department, toProject: projectId)
        dismiss()
    }
}

// MARK: - Edit Department Sheet

private struct EditDepartmentSheet: View {
    let projectId: UUID
    let department: ProjectDepartment
    
    @EnvironmentObject var companyStore: CompanyStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var maxCapacity: Int
    @State private var customName: String
    
    init(projectId: UUID, department: ProjectDepartment) {
        self.projectId = projectId
        self.department = department
        self._maxCapacity = State(initialValue: department.maxCapacity)
        self._customName = State(initialValue: department.customName ?? "")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: department.type.icon)
                        .foregroundStyle(department.type.color)
                    Text("\(department.type.rawValue) 설정")
                        .font(.title3.bold())
                }
                Spacer()
                Button("취소") {
                    dismiss()
                }
            }
            .padding()
            
            Divider()
            
            Form {
                Section("부서 이름") {
                    TextField("커스텀 이름 (선택)", text: $customName)
                        .textFieldStyle(.roundedBorder)
                    
                    Text("비워두면 기본 이름(\(department.type.rawValue))을 사용합니다")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                
                Section("정원 설정") {
                    Stepper("최대 \(maxCapacity)명", value: $maxCapacity, in: max(department.employees.count, 1)...10)
                    
                    if department.employees.count > 0 {
                        Text("현재 \(department.employees.count)명의 직원이 있어 그 이하로 줄일 수 없습니다")
                            .font(.callout)
                            .foregroundStyle(.orange)
                    }
                }
                
                Section("부서 정보") {
                    LabeledContent("유형", value: department.type.rawValue)
                    LabeledContent("현재 직원", value: "\(department.employees.count)명")
                    LabeledContent("빈 자리", value: "\(department.availableSlots)명")
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
                    saveDepartment()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 400, height: 400)
    }
    
    private func saveDepartment() {
        var updated = department
        updated.maxCapacity = maxCapacity
        updated.customName = customName.isEmpty ? nil : customName
        
        companyStore.updateDepartment(updated, inProject: projectId)
        dismiss()
    }
}

#Preview {
    DepartmentManagerView(projectId: UUID())
        .environmentObject(CompanyStore())
}
