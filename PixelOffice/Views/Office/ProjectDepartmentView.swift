import SwiftUI

/// 프로젝트 내 부서 뷰
struct ProjectDepartmentView: View {
    let department: ProjectDepartment
    let projectId: UUID
    let isSelected: Bool
    let onSelect: () -> Void
    let onEmployeeSelect: (ProjectEmployee) -> Void

    @EnvironmentObject var companyStore: CompanyStore
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 0) {
            // Department Header
            VStack(spacing: 6) {
                HStack {
                    Image(systemName: department.type.icon)
                        .font(.title3)
                        .foregroundStyle(department.type.color)
                    Text(department.name)
                        .font(.title3.bold())
                    Spacer()
                    Text("\(department.employees.count)/\(department.maxCapacity)")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                // 워크플로우 단계 표시
                HStack {
                    Text(department.type.workflowStageName)
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !department.type.nextDepartments.isEmpty {
                        HStack(spacing: 4) {
                            Text("→")
                            ForEach(department.type.nextDepartments.prefix(2), id: \.self) { next in
                                Image(systemName: next.icon)
                                    .font(.body)
                                    .foregroundStyle(next.color)
                            }
                        }
                        .font(.body)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.red.opacity(0.3))

            // Desk Area
            VStack(spacing: 12) {
                // Desks Grid (2x2)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(0..<department.maxCapacity, id: \.self) { index in
                        if index < department.employees.count {
                            let employee = department.employees[index]
                            ProjectDeskView(
                                employee: employee,
                                deskIndex: index,
                                onSelect: { onEmployeeSelect(employee) }
                            )
                        } else {
                            EmptyDeskView(deskIndex: index)
                        }
                    }
                }
            }
            .padding(16)
        }
        .frame(width: 360, height: 380)
        .background(Color.red.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.red : Color.red.opacity(0.5), lineWidth: 5)
        )
        .shadow(color: isHovering ? department.type.color.opacity(0.3) : .clear, radius: 10)
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
}

/// 프로젝트 직원용 책상 뷰
struct ProjectDeskView: View {
    let employee: ProjectEmployee
    let deskIndex: Int
    let onSelect: () -> Void

    @State private var isHovering = false

    var body: some View {
        Rectangle()
            .fill(Color.blue)
            .frame(width: 120, height: 120)
            .overlay(
                VStack(spacing: 8) {
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 80, height: 30)
                        .overlay(
                            Text("컴퓨터")
                                .font(.headline.bold())
                                .foregroundStyle(.white)
                        )

                    Rectangle()
                        .fill(Color.yellow)
                        .frame(width: 80, height: 30)
                        .overlay(
                            Text("책상")
                                .font(.headline.bold())
                                .foregroundStyle(.black)
                        )

                    Text(employee.name)
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(Color.black)
                }
            )
            .border(Color.purple, width: 5)
            .fixedSize()
            .scaleEffect(isHovering ? 1.05 : 1.0)
            .onTapGesture(perform: onSelect)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }
    }
}

#Preview {
    HStack {
        ProjectDepartmentView(
            department: ProjectDepartment(
                type: .development,
                employees: [
                    ProjectEmployee(name: "Claude-1", aiType: .claude, status: .working, departmentType: .development),
                    ProjectEmployee(name: "GPT-1", aiType: .gpt, status: .idle, departmentType: .development)
                ]
            ),
            projectId: UUID(),
            isSelected: false,
            onSelect: {},
            onEmployeeSelect: { _ in }
        )

        ProjectDepartmentView(
            department: ProjectDepartment(type: .design),
            projectId: UUID(),
            isSelected: true,
            onSelect: {},
            onEmployeeSelect: { _ in }
        )
    }
    .padding()
    .background(Color(NSColor.windowBackgroundColor))
}
