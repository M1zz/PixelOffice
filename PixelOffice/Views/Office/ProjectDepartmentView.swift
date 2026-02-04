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
            .background(department.type.color.opacity(0.15))

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
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? department.type.color : Color.clear, lineWidth: 3)
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
        VStack(spacing: 6) {
            // 책상과 컴퓨터 영역
            ZStack {
                // 책상 (갈색)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(red: 0.55, green: 0.35, blue: 0.2))
                    .frame(width: 90, height: 45)
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 2)

                VStack(spacing: 4) {
                    // 컴퓨터 모니터
                    ZStack {
                        // 모니터 프레임
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(white: 0.25))
                            .frame(width: 50, height: 35)

                        // 화면
                        RoundedRectangle(cornerRadius: 1)
                            .fill(employee.status == .working ?
                                  Color.cyan.opacity(0.6) :
                                  Color(white: 0.4))
                            .frame(width: 44, height: 30)

                        // 화면 글로우 (작업 중일 때)
                        if employee.status == .working {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.cyan.opacity(0.3))
                                .frame(width: 44, height: 30)
                                .blur(radius: 4)
                        }
                    }
                    .offset(y: -8)

                    // 캐릭터 (작업 중일 때만)
                    if employee.status != .idle {
                        PixelCharacter(
                            appearance: employee.characterAppearance,
                            status: employee.status,
                            aiType: employee.aiType
                        )
                        .scaleEffect(0.8)
                        .offset(y: -5)
                    } else {
                        // 휴식 중일 때는 빈 공간 + 작은 표시
                        Text("💤")
                            .font(.caption)
                            .opacity(0.5)
                            .offset(y: -5)
                    }
                }
            }
            .frame(height: 80)

            // 이름표
            HStack(spacing: 4) {
                Circle()
                    .fill(employee.status.color)
                    .frame(width: 6, height: 6)

                Text(employee.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color(white: 0.95))
                    .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
            )
        }
        .frame(width: 110, height: 120)
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Color.black.opacity(0.05) : Color.clear)
        )
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
