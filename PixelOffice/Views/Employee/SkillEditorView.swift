//
//  SkillEditorView.swift
//  PixelOffice
//
//  Created by Pipeline on 2026-02-15.
//
//  직원 스킬 편집 뷰
//

import SwiftUI

struct SkillEditorView: View {
    @Binding var skills: [EmployeeSkill]
    let departmentType: DepartmentType
    
    @State private var showingAddSkill = false
    @State private var newEmployeeSkillCategory: EmployeeSkillCategory = .communication
    @State private var newSkillLevel: SkillLevel = .intermediate
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 헤더
            HStack {
                Label("보유 스킬", systemImage: "star.circle")
                    .font(.headline)
                
                Spacer()
                
                Button(action: { showingAddSkill = true }) {
                    Image(systemName: "plus.circle")
                }
            }
            
            // 스킬 목록
            if skills.isEmpty {
                Text("등록된 스킬이 없습니다")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(skills) { skill in
                    SkillRow(skill: skill, onDelete: {
                        skills.removeAll { $0.id == skill.id }
                    }, onLevelChange: { newLevel in
                        if let index = skills.firstIndex(where: { $0.id == skill.id }) {
                            skills[index].level = newLevel
                        }
                    })
                }
            }
        }
        .sheet(isPresented: $showingAddSkill) {
            AddSkillSheet(
                departmentType: departmentType,
                onAdd: { category, level in
                    let newSkill = EmployeeSkill(
                        name: category.rawValue,
                        category: category,
                        level: level,
                        description: "\(category.rawValue) 업무 수행"
                    )
                    skills.append(newSkill)
                }
            )
        }
    }
}

struct SkillRow: View {
    let skill: EmployeeSkill
    let onDelete: () -> Void
    let onLevelChange: (SkillLevel) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 아이콘
            Image(systemName: skill.category.icon)
                .foregroundColor(skill.category.color)
                .frame(width: 24)
            
            // 스킬 이름
            Text(skill.name)
                .font(.subheadline)
            
            Spacer()
            
            // 레벨 선택
            Picker("", selection: Binding(
                get: { skill.level },
                set: { onLevelChange($0) }
            )) {
                ForEach(SkillLevel.allCases, id: \.self) { level in
                    Text(level.rawValue).tag(level)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 80)
            
            // 별점 표시
            Text(skill.level.stars)
                .font(.caption)
                .foregroundColor(skill.level.color)
            
            // 삭제 버튼
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

struct AddSkillSheet: View {
    let departmentType: DepartmentType
    let onAdd: (EmployeeSkillCategory, SkillLevel) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: EmployeeSkillCategory = .communication
    @State private var selectedLevel: SkillLevel = .intermediate
    
    var availableCategories: [EmployeeSkillCategory] {
        EmployeeSkillCategory.categories(for: departmentType) + [.communication, .documentation, .leadership]
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("스킬 추가")
                .font(.headline)
            
            // 카테고리 선택
            VStack(alignment: .leading) {
                Text("스킬 종류")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Picker("카테고리", selection: $selectedCategory) {
                    ForEach(availableCategories, id: \.self) { category in
                        HStack {
                            Image(systemName: category.icon)
                            Text(category.rawValue)
                        }
                        .tag(category)
                    }
                }
                .pickerStyle(.menu)
            }
            
            // 레벨 선택
            VStack(alignment: .leading) {
                Text("숙련도")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Picker("레벨", selection: $selectedLevel) {
                    ForEach(SkillLevel.allCases, id: \.self) { level in
                        HStack {
                            Text(level.stars)
                            Text(level.rawValue)
                        }
                        .tag(level)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // 버튼
            HStack {
                Button("취소") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("추가") {
                    onAdd(selectedCategory, selectedLevel)
                    dismiss()
                }
                .keyboardShortcut(.return)
            }
        }
        .padding()
        .frame(width: 300)
        .onAppear {
            if let first = availableCategories.first {
                selectedCategory = first
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SkillEditorView(
        skills: .constant([
            EmployeeSkill(name: "iOS 개발", category: .ios, level: .expert, description: ""),
            EmployeeSkill(name: "SwiftUI", category: .ios, level: .advanced, description: "")
        ]),
        departmentType: .development
    )
    .padding()
    .frame(width: 400)
}
