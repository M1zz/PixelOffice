import SwiftUI

struct DepartmentView: View {
    let department: Department
    let isSelected: Bool
    let onSelect: () -> Void
    let onEmployeeSelect: (Employee) -> Void

    @EnvironmentObject var companyStore: CompanyStore
    @State private var isHovering = false

    /// 직원이 답변 안 한 온보딩 질문이 있는지 확인
    func hasPendingQuestions(for employee: Employee) -> Bool {
        guard let onboarding = companyStore.getOnboarding(for: employee.id) else {
            return false
        }
        return !onboarding.isCompleted
    }

    /// 부서별 인테리어 장식
    @ViewBuilder
    var decorationsForDepartment: some View {
        Group {
            switch department.type {
            case .planning:
                // 기획팀: 왼쪽 상단에 포스터, 오른쪽에 물병
                PixelPoster()
                    .offset(x: 20, y: 30)
                PixelWaterBottle()
                    .offset(x: 300, y: 50)
                PixelLaptop()
                    .offset(x: 150, y: 230)

            case .design:
                // 디자인팀: 화분, 포스터
                PixelPlant()
                    .offset(x: 30, y: 40)
                PixelPoster()
                    .offset(x: 280, y: 30)
                PixelWaterBottle()
                    .offset(x: 150, y: 240)

            case .development:
                // 개발팀: 커피머신, 물병 여러개
                PixelCoffeeMachine()
                    .offset(x: 25, y: 35)
                PixelWaterBottle()
                    .offset(x: 300, y: 50)
                PixelWaterBottle()
                    .offset(x: 150, y: 235)

            case .qa:
                // QA팀: 시계, 책장
                PixelClock()
                    .offset(x: 280, y: 30)
                PixelBookshelf()
                    .offset(x: 20, y: 25)
                PixelLaptop()
                    .offset(x: 150, y: 230)

            case .marketing:
                // 마케팅팀: 포스터, 책장, 화분
                PixelPoster()
                    .offset(x: 280, y: 30)
                PixelBookshelf()
                    .offset(x: 20, y: 25)
                PixelPlant()
                    .offset(x: 150, y: 235)

            case .general:
                // 일반: 기본 화분
                PixelPlant()
                    .offset(x: 30, y: 40)
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
                // 오피스 바닥 배경
                OfficeFloor()

                VStack(spacing: 12) {
                    // Desks Grid (2x2)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(0..<department.maxCapacity, id: \.self) { index in
                            if index < department.employees.count {
                                let employee = department.employees[index]
                                DeskView(
                                    employee: employee,
                                    deskIndex: index,
                                    onSelect: { onEmployeeSelect(employee) },
                                    hasPendingQuestions: hasPendingQuestions(for: employee)
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
        .background(Color(NSColor.windowBackgroundColor))
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

struct EmptyDeskView: View {
    let deskIndex: Int

    var body: some View {
        VStack {
            // Empty desk visualization
            ZStack {
                // Desk
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(white: 0.85))
                    .frame(width: 100, height: 50)

                // Empty chair indicator
                Image(systemName: "plus.circle.dashed")
                    .font(.title2)
                    .foregroundStyle(.secondary.opacity(0.5))
            }

            Text("빈 자리")
                .font(.body)
                .foregroundStyle(.secondary.opacity(0.5))
        }
        .frame(width: 120, height: 120)
    }
}

#Preview {
    HStack {
        DepartmentView(
            department: Department(
                name: "개발팀",
                type: .development,
                employees: [
                    Employee(name: "Claude-1", aiType: .claude, status: .working),
                    Employee(name: "GPT-1", aiType: .gpt, status: .idle)
                ]
            ),
            isSelected: false,
            onSelect: {},
            onEmployeeSelect: { _ in }
        )
        
        DepartmentView(
            department: Department(name: "디자인팀", type: .design),
            isSelected: true,
            onSelect: {},
            onEmployeeSelect: { _ in }
        )
    }
    .padding()
    .background(Color(NSColor.windowBackgroundColor))
}
