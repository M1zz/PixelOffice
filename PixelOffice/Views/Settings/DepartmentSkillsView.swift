import SwiftUI

/// 부서별 스킬 설정 뷰
struct DepartmentSkillsView: View {
    @EnvironmentObject var companyStore: CompanyStore
    @State private var selectedDepartment: DepartmentType = .planning
    @State private var editingSkills: DepartmentSkillSet?
    @State private var showingResetAlert = false

    var currentSkills: DepartmentSkillSet {
        companyStore.getDepartmentSkills(for: selectedDepartment)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text("부서별 스킬 설정")
                    .font(.title2.bold())
                Spacer()
                Button("기본값으로 초기화") {
                    showingResetAlert = true
                }
                .foregroundStyle(.red)
            }
            .padding()

            Divider()

            HStack(spacing: 0) {
                // 왼쪽: 부서 목록
                VStack(alignment: .leading, spacing: 8) {
                    Text("부서 선택")
                        .font(.headline)
                        .padding(.bottom, 4)

                    ForEach(DepartmentType.allCases.filter { $0 != .general }, id: \.self) { dept in
                        DepartmentSkillRow(
                            department: dept,
                            isSelected: selectedDepartment == dept
                        ) {
                            selectedDepartment = dept
                            editingSkills = nil
                        }
                    }

                    Spacer()
                }
                .padding()
                .frame(width: 200)
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                // 오른쪽: 스킬 상세
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // 부서 헤더
                        HStack {
                            Image(systemName: selectedDepartment.icon)
                                .font(.title)
                                .foregroundStyle(selectedDepartment.color)
                            Text("\(selectedDepartment.rawValue)팀 스킬")
                                .font(.title2.bold())
                            Spacer()
                            Button(editingSkills == nil ? "수정" : "취소") {
                                if editingSkills == nil {
                                    editingSkills = currentSkills
                                } else {
                                    editingSkills = nil
                                }
                            }
                        }

                        if let editing = Binding($editingSkills) {
                            // 편집 모드
                            DepartmentSkillEditView(skills: editing) {
                                if let skills = editingSkills {
                                    companyStore.updateDepartmentSkills(for: selectedDepartment, skills: skills)
                                }
                                editingSkills = nil
                            }
                        } else {
                            // 보기 모드
                            DepartmentSkillDetailView(skills: currentSkills)
                        }
                    }
                    .padding()
                }
            }
        }
        .alert("스킬 초기화", isPresented: $showingResetAlert) {
            Button("취소", role: .cancel) {}
            Button("초기화", role: .destructive) {
                companyStore.resetDepartmentSkills(for: selectedDepartment)
            }
        } message: {
            Text("\(selectedDepartment.rawValue)팀의 스킬을 기본값으로 초기화하시겠습니까?")
        }
    }
}

/// 부서 스킬 행
struct DepartmentSkillRow: View {
    let department: DepartmentType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: department.icon)
                    .foregroundStyle(department.color)
                    .frame(width: 24)
                Text(department.rawValue)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

/// 스킬 상세 보기 뷰
struct DepartmentSkillDetailView: View {
    let skills: DepartmentSkillSet

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 역할 이름
            VStack(alignment: .leading, spacing: 4) {
                Text("역할")
                    .font(.headline)
                Text(skills.roleName)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // 전문 분야
            VStack(alignment: .leading, spacing: 4) {
                Text("전문 분야")
                    .font(.headline)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(skills.expertise, id: \.self) { exp in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(exp)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // 작업 스타일
            VStack(alignment: .leading, spacing: 4) {
                Text("작업 스타일")
                    .font(.headline)
                Text(skills.workStyle)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // 커스텀 프롬프트
            if !skills.customPrompt.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("추가 설정")
                        .font(.headline)
                    Text(skills.customPrompt)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            // 미리보기
            VStack(alignment: .leading, spacing: 4) {
                Text("시스템 프롬프트 미리보기")
                    .font(.headline)
                ScrollView {
                    Text(skills.fullPrompt)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 200)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

/// 스킬 편집 뷰
struct DepartmentSkillEditView: View {
    @Binding var skills: DepartmentSkillSet
    let onSave: () -> Void

    @State private var newExpertise = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 역할 이름
            VStack(alignment: .leading, spacing: 4) {
                Text("역할")
                    .font(.headline)
                TextField("역할 이름", text: $skills.roleName)
                    .textFieldStyle(.roundedBorder)
            }

            // 전문 분야
            VStack(alignment: .leading, spacing: 4) {
                Text("전문 분야")
                    .font(.headline)

                ForEach(skills.expertise.indices, id: \.self) { index in
                    HStack {
                        TextField("전문 분야", text: $skills.expertise[index])
                            .textFieldStyle(.roundedBorder)
                        Button {
                            skills.expertise.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    TextField("새 전문 분야 추가", text: $newExpertise)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        if !newExpertise.isEmpty {
                            skills.expertise.append(newExpertise)
                            newExpertise = ""
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                    .disabled(newExpertise.isEmpty)
                }
            }

            // 작업 스타일
            VStack(alignment: .leading, spacing: 4) {
                Text("작업 스타일")
                    .font(.headline)
                TextEditor(text: $skills.workStyle)
                    .frame(minHeight: 80)
                    .padding(4)
                    .background(Color(NSColor.textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.2))
                    )
            }

            // 커스텀 프롬프트
            VStack(alignment: .leading, spacing: 4) {
                Text("추가 설정 (선택)")
                    .font(.headline)
                TextEditor(text: $skills.customPrompt)
                    .frame(minHeight: 60)
                    .padding(4)
                    .background(Color(NSColor.textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.secondary.opacity(0.2))
                    )
                Text("AI 직원에게 추가로 전달할 지시사항을 입력하세요")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // 저장 버튼
            HStack {
                Spacer()
                Button("저장") {
                    onSave()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

#Preview {
    DepartmentSkillsView()
        .environmentObject(CompanyStore())
        .frame(width: 800, height: 600)
}
