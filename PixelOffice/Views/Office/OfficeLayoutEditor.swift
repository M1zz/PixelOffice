import SwiftUI

/// 오피스 레이아웃 편집 뷰
struct OfficeLayoutEditor: View {
    @EnvironmentObject var companyStore: CompanyStore
    @Binding var layout: OfficeLayout
    @Binding var isPresented: Bool

    @State private var selectedDepartmentId: UUID?
    @State private var draggedDepartment: Department?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("오피스 레이아웃 편집")
                    .font(.title2.bold())

                Spacer()

                Button("완료") {
                    companyStore.saveCompany()
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(.ultraThinMaterial)

            HSplitView {
                // 왼쪽: 레이아웃 편집 영역
                layoutEditorView
                    .frame(minWidth: 600)

                // 오른쪽: 설정 패널
                settingsPanel
                    .frame(width: 300)
            }
        }
        .frame(minWidth: 900, minHeight: 600)
    }

    // MARK: - Layout Editor View

    private var layoutEditorView: some View {
        ScrollView([.horizontal, .vertical]) {
            ZStack(alignment: .topLeading) {
                // 배경
                Rectangle()
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .frame(width: 1200, height: 800)

                // 그리드 가이드
                if layout.mode == .custom {
                    gridGuideView
                }

                // 부서 배치
                if layout.mode == .grid {
                    gridLayoutView
                } else {
                    customLayoutView
                }
            }
            .padding(40)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var gridGuideView: some View {
        Canvas { context, size in
            let gridSize: CGFloat = 40
            context.stroke(
                Path { path in
                    for x in stride(from: 0, through: 1200, by: gridSize) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: 800))
                    }
                    for y in stride(from: 0, through: 800, by: gridSize) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: 1200, y: y))
                    }
                },
                with: .color(.gray.opacity(0.2)),
                lineWidth: 1
            )
        }
        .frame(width: 1200, height: 800)
    }

    private var gridLayoutView: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: layout.gridColumns),
            spacing: 20
        ) {
            ForEach(companyStore.company.departments) { department in
                departmentCard(department)
                    .aspectRatio(1.2, contentMode: .fit)
            }
        }
        .padding()
    }

    private var customLayoutView: some View {
        ForEach(companyStore.company.departments) { department in
            let position = layout.departmentPositions[department.id] ?? DeskPosition(row: 0, column: 0)

            departmentCard(department)
                .frame(width: 280, height: 200)
                .position(
                    x: CGFloat(position.column * 300 + 140),
                    y: CGFloat(position.row * 220 + 100)
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            draggedDepartment = department
                        }
                        .onEnded { value in
                            // 그리드에 스냅
                            let newColumn = Int((value.location.x - 140) / 300)
                            let newRow = Int((value.location.y - 100) / 220)
                            layout.departmentPositions[department.id] = DeskPosition(
                                row: max(0, newRow),
                                column: max(0, newColumn)
                            )
                            draggedDepartment = nil
                        }
                )
        }
    }

    private func departmentCard(_ department: Department) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: department.type.icon)
                    .font(.title2)
                    .foregroundColor(department.type.color)

                Text(department.name)
                    .font(.headline)

                Spacer()

                if selectedDepartmentId == department.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }

            HStack {
                Label("\(department.employees.count)/\(department.maxCapacity)", systemImage: "person.3.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(department.type.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(department.type.color.opacity(0.2))
                    .cornerRadius(4)
            }
        }
        .padding()
        .background(selectedDepartmentId == department.id ? Color.blue.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(selectedDepartmentId == department.id ? Color.blue : Color.gray.opacity(0.3), lineWidth: selectedDepartmentId == department.id ? 2 : 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 4)
        .onTapGesture {
            selectedDepartmentId = department.id
        }
    }

    // MARK: - Settings Panel

    private var settingsPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 레이아웃 모드
                VStack(alignment: .leading, spacing: 8) {
                    Text("레이아웃 모드")
                        .font(.headline)

                    Picker("", selection: $layout.mode) {
                        Text("그리드").tag(OfficeLayout.LayoutMode.grid)
                        Text("커스텀").tag(OfficeLayout.LayoutMode.custom)
                    }
                    .pickerStyle(.segmented)
                }

                Divider()

                // 그리드 설정
                if layout.mode == .grid {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("그리드 열 수")
                            .font(.headline)

                        Stepper("\(layout.gridColumns)열", value: $layout.gridColumns, in: 1...4)
                    }

                    Divider()
                }

                // 선택된 부서 설정
                if let departmentId = selectedDepartmentId,
                   let department = companyStore.company.departments.first(where: { $0.id == departmentId }) {

                    VStack(alignment: .leading, spacing: 12) {
                        Text("부서 설정")
                            .font(.headline)

                        // 부서 이름 편집
                        VStack(alignment: .leading, spacing: 4) {
                            Text("부서 이름")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            TextField("부서 이름", text: Binding(
                                get: { department.name },
                                set: { newValue in
                                    if let index = companyStore.company.departments.firstIndex(where: { $0.id == departmentId }) {
                                        companyStore.company.departments[index].name = newValue
                                    }
                                }
                            ))
                            .textFieldStyle(.roundedBorder)
                        }

                        // 부서 타입 선택
                        VStack(alignment: .leading, spacing: 4) {
                            Text("부서 타입")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Picker("부서 타입", selection: Binding(
                                get: { department.type },
                                set: { newValue in
                                    if let index = companyStore.company.departments.firstIndex(where: { $0.id == departmentId }) {
                                        companyStore.company.departments[index].type = newValue
                                    }
                                }
                            )) {
                                ForEach(DepartmentType.allCases, id: \.self) { type in
                                    HStack {
                                        Image(systemName: type.icon)
                                        Text(type.rawValue)
                                    }
                                    .tag(type)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        // 최대 인원
                        Stepper("최대 인원: \(department.maxCapacity)명", value: Binding(
                            get: { department.maxCapacity },
                            set: { newValue in
                                if let index = companyStore.company.departments.firstIndex(where: { $0.id == departmentId }) {
                                    companyStore.company.departments[index].maxCapacity = newValue
                                }
                            }
                        ), in: 1...20)

                        if layout.mode == .custom {
                            // 위치 정보
                            let position = layout.departmentPositions[departmentId] ?? DeskPosition(row: 0, column: 0)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("위치")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                HStack {
                                    Text("행: \(position.row)")
                                    Spacer()
                                    Text("열: \(position.column)")
                                }
                                .font(.caption)
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    Divider()
                }

                // 부서 추가
                Button {
                    addDepartment()
                } label: {
                    Label("부서 추가", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                // 선택된 부서 제거
                if let departmentId = selectedDepartmentId {
                    Button(role: .destructive) {
                        removeDepartment(departmentId)
                    } label: {
                        Label("부서 제거", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                Divider()

                // 프리셋
                VStack(alignment: .leading, spacing: 8) {
                    Text("프리셋")
                        .font(.headline)

                    Button("기본 레이아웃으로 리셋") {
                        resetToDefault()
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
            }
            .padding()
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Actions

    private func addDepartment() {
        let newDepartment = Department(
            name: "새 부서",
            type: .general,
            position: DeskPosition(row: 0, column: companyStore.company.departments.count)
        )
        companyStore.company.departments.append(newDepartment)
        selectedDepartmentId = newDepartment.id
    }

    private func removeDepartment(_ id: UUID) {
        companyStore.company.departments.removeAll { $0.id == id }
        layout.departmentPositions.removeValue(forKey: id)
        selectedDepartmentId = nil
    }

    private func resetToDefault() {
        layout = .default
        companyStore.company.departments = Department.defaultDepartments
        selectedDepartmentId = nil
    }
}
