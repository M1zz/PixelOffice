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

    /// 부서별 인테리어 장식
    @ViewBuilder
    var decorationsForDepartment: some View {
        Group {
            switch department.type {
            case .planning:
                // 기획팀: 왼쪽에 화분, 오른쪽 상단에 시계
                PixelPlant()
                    .offset(x: 20, y: 35)
                PixelClock()
                    .offset(x: 310, y: 25)
                PixelLaptop()
                    .offset(x: 150, y: 250)
                PixelWaterBottle()
                    .offset(x: 280, y: 260)

            case .design:
                // 디자인팀: 화분 여러개, 포스터
                PixelPlant()
                    .offset(x: 25, y: 35)
                PixelPoster()
                    .offset(x: 300, y: 25)
                PixelPlant()
                    .offset(x: 150, y: 250)
                PixelWaterBottle()
                    .offset(x: 280, y: 260)

            case .development:
                // 개발팀: 커피머신, 물병
                PixelCoffeeMachine()
                    .offset(x: 20, y: 30)
                PixelWaterBottle()
                    .offset(x: 310, y: 40)
                PixelWaterBottle()
                    .offset(x: 150, y: 250)
                PixelLaptop()
                    .offset(x: 280, y: 250)

            case .qa:
                // QA팀: 시계, 책장
                PixelClock()
                    .offset(x: 300, y: 25)
                PixelBookshelf()
                    .offset(x: 15, y: 20)
                PixelLaptop()
                    .offset(x: 150, y: 250)
                PixelWaterBottle()
                    .offset(x: 280, y: 260)

            case .marketing:
                // 마케팅팀: 포스터, 책장, 화분
                PixelPoster()
                    .offset(x: 300, y: 25)
                PixelBookshelf()
                    .offset(x: 15, y: 20)
                PixelPlant()
                    .offset(x: 150, y: 250)
                PixelWaterBottle()
                    .offset(x: 280, y: 260)

            case .general:
                PixelPlant()
                    .offset(x: 25, y: 35)
            }
        }
    }

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

            // Desk Area with Decorations
            ZStack(alignment: .topLeading) {
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

                // Department-specific decorations
                decorationsForDepartment
            }
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

                VStack(spacing: 2) {
                    // 와이드 모니터
                    VStack(spacing: 1) {
                        // 모니터 화면과 프레임
                        ZStack {
                            // 화면
                            RoundedRectangle(cornerRadius: 2)
                                .fill(employee.status == .working ?
                                      LinearGradient(colors: [Color.cyan.opacity(0.7), Color.blue.opacity(0.5)],
                                                   startPoint: .top, endPoint: .bottom) :
                                      LinearGradient(colors: [Color(white: 0.45), Color(white: 0.35)],
                                                   startPoint: .top, endPoint: .bottom))
                                .frame(width: 55, height: 32)

                            // 베젤
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(Color(white: 0.2), lineWidth: 2)
                                .frame(width: 55, height: 32)

                            // 화면 글로우
                            if employee.status == .working {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.cyan.opacity(0.4))
                                    .frame(width: 55, height: 32)
                                    .blur(radius: 3)
                            }
                        }

                        // 모니터 스탠드
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(Color(white: 0.3))
                                .frame(width: 4, height: 6)
                            Rectangle()
                                .fill(Color(white: 0.25))
                                .frame(width: 20, height: 3)
                        }
                    }
                    .offset(y: -10)

                    // 캐릭터 (작업 중일 때만)
                    if employee.status != .idle {
                        PixelCharacter(
                            appearance: employee.characterAppearance,
                            status: employee.status,
                            aiType: employee.aiType
                        )
                        .scaleEffect(0.75)
                        .offset(y: -8)
                    }

                    // 커피 (휴식 중일 때)
                    if employee.status == .idle {
                        Text("☕️")
                            .font(.title3)
                            .offset(x: 20, y: -15)
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
