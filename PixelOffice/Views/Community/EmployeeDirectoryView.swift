import SwiftUI

/// 전체 사원 디렉토리 뷰
struct EmployeeDirectoryView: View {
    @EnvironmentObject var companyStore: CompanyStore
    @State private var searchText = ""
    @State private var selectedDepartment: DepartmentType? = nil
    @State private var selectedEmployee: EmployeeInfo? = nil

    /// 모든 직원 정보 (회사 + 프로젝트)
    var allEmployeeInfo: [EmployeeInfo] {
        var employees: [EmployeeInfo] = []

        // 회사 직원
        for dept in companyStore.company.departments {
            for employee in dept.employees {
                employees.append(EmployeeInfo(
                    id: employee.id,
                    name: employee.name,
                    employeeNumber: employee.employeeNumber,
                    aiType: employee.aiType,
                    departmentType: dept.type,
                    departmentName: dept.name,
                    jobRoles: employee.jobRoles,
                    personality: employee.personality,
                    strengths: employee.strengths,
                    workStyle: employee.workStyle,
                    status: employee.status,
                    appearance: employee.characterAppearance,
                    hireDate: employee.createdAt,
                    projectName: nil,
                    statistics: employee.statistics
                ))
            }
        }

        // 프로젝트 직원
        for project in companyStore.company.projects {
            for employee in project.allEmployees {
                employees.append(EmployeeInfo(
                    id: employee.id,
                    name: employee.name,
                    employeeNumber: employee.employeeNumber,
                    aiType: employee.aiType,
                    departmentType: employee.departmentType,
                    departmentName: employee.departmentType.rawValue,
                    jobRoles: employee.jobRoles,
                    personality: employee.personality,
                    strengths: employee.strengths,
                    workStyle: employee.workStyle,
                    status: employee.status,
                    appearance: employee.characterAppearance,
                    hireDate: employee.createdAt,
                    projectName: project.name,
                    statistics: employee.statistics
                ))
            }
        }

        return employees
    }

    /// 필터링된 직원
    var filteredEmployees: [EmployeeInfo] {
        var result = allEmployeeInfo

        // 검색 필터
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.employeeNumber.localizedCaseInsensitiveContains(searchText) ||
                $0.jobRoles.contains { $0.rawValue.localizedCaseInsensitiveContains(searchText) }
            }
        }

        // 부서 필터
        if let dept = selectedDepartment {
            result = result.filter { $0.departmentType == dept }
        }

        return result.sorted { $0.employeeNumber < $1.employeeNumber }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 검색 & 필터
            HStack(spacing: 12) {
                // 검색
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("이름, 사원번호, 직무 검색...", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(6)

                // 부서 필터
                Menu {
                    Button("전체 부서") {
                        selectedDepartment = nil
                    }
                    Divider()
                    ForEach(DepartmentType.allCases, id: \.self) { dept in
                        Button {
                            selectedDepartment = dept
                        } label: {
                            HStack {
                                Image(systemName: dept.icon)
                                Text(dept.rawValue)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text(selectedDepartment?.rawValue ?? "전체 부서")
                    }
                    .font(.callout)
                }
                .menuStyle(.borderlessButton)

                // 직원 수
                Text("\(filteredEmployees.count)명")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // 직원 그리드
            if filteredEmployees.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text("검색 결과가 없습니다")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 20)], spacing: 20) {
                        ForEach(filteredEmployees) { employee in
                            EmployeeDirectoryCard(employee: employee) {
                                selectedEmployee = employee
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .sheet(item: $selectedEmployee) { employee in
            EmployeeIDCardView(employee: employee)
        }
    }
}

/// 직원 정보 통합 구조체
struct EmployeeInfo: Identifiable, Hashable {
    let id: UUID
    let name: String
    let employeeNumber: String
    let aiType: AIType
    let departmentType: DepartmentType
    let departmentName: String
    let jobRoles: [JobRole]
    let personality: String
    let strengths: [String]
    let workStyle: String
    let status: EmployeeStatus
    let appearance: CharacterAppearance
    let hireDate: Date
    let projectName: String?
    let statistics: EmployeeStatistics
}

/// 플립 가능한 직원 카드
struct EmployeeDirectoryCard: View {
    let employee: EmployeeInfo
    let onTap: () -> Void

    @State private var isFlipped = false
    @State private var isHovering = false

    var body: some View {
        ZStack {
            // 뒷면 (통계)
            CardBackView(employee: employee)
                .rotation3DEffect(
                    .degrees(isFlipped ? 0 : 180),
                    axis: (x: 0, y: 1, z: 0)
                )
                .opacity(isFlipped ? 1 : 0)

            // 앞면 (기본 정보)
            CardFrontView(employee: employee)
                .rotation3DEffect(
                    .degrees(isFlipped ? -180 : 0),
                    axis: (x: 0, y: 1, z: 0)
                )
                .opacity(isFlipped ? 0 : 1)
        }
        .frame(width: 200, height: 280)
        .onTapGesture {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isFlipped.toggle()
            }
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovering)
        .contextMenu {
            Button {
                onTap()
            } label: {
                Label("사원증 보기", systemImage: "person.text.rectangle")
            }

            Button {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    isFlipped.toggle()
                }
            } label: {
                Label(isFlipped ? "앞면 보기" : "뒷면 보기", systemImage: "arrow.triangle.2.circlepath")
            }
        }
    }
}

/// 카드 앞면 - 기본 정보
struct CardFrontView: View {
    let employee: EmployeeInfo

    var body: some View {
        VStack(spacing: 10) {
            // 상단 헤더 (부서 색상)
            ZStack {
                LinearGradient(
                    colors: [employee.departmentType.color.opacity(0.7), employee.departmentType.color],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 50)

                HStack {
                    Image(systemName: employee.departmentType.icon)
                    Text(employee.departmentType.rawValue)
                    Spacer()
                    // 상태 표시
                    Circle()
                        .fill(employee.status.color)
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(0.8), lineWidth: 1.5)
                        )
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
            }

            // 캐릭터
            ZStack {
                Circle()
                    .fill(employee.departmentType.color.opacity(0.15))
                    .frame(width: 70, height: 70)

                PixelCharacter(
                    appearance: employee.appearance,
                    status: employee.status,
                    aiType: employee.aiType
                )
                .scaleEffect(0.8)
            }

            VStack(spacing: 6) {
                // 이름
                Text(employee.name)
                    .font(.headline)

                // 사원번호
                Text(employee.employeeNumber)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)

                // AI 유형
                HStack(spacing: 4) {
                    Image(systemName: employee.aiType.icon)
                    Text(employee.aiType.rawValue)
                }
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(employee.aiType.color.opacity(0.15))
                .foregroundStyle(employee.aiType.color)
                .cornerRadius(6)

                // 프로젝트
                if let project = employee.projectName {
                    HStack(spacing: 3) {
                        Image(systemName: "folder.fill")
                        Text(project)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                // 플립 힌트
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("클릭하여 뒤집기")
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}

/// 카드 뒷면 - 업무 통계
struct CardBackView: View {
    let employee: EmployeeInfo

    var body: some View {
        VStack(spacing: 8) {
            // 상단 헤더
            ZStack {
                LinearGradient(
                    colors: [employee.departmentType.color, employee.departmentType.color.opacity(0.7)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 40)

                HStack {
                    Text(employee.name)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("통계")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.white.opacity(0.2))
                        .cornerRadius(4)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
            }

            // 통계 그리드
            VStack(spacing: 8) {
                // 대화
                CardStatRow(
                    icon: "bubble.left.and.bubble.right.fill",
                    label: "대화",
                    value: "\(employee.statistics.conversationCount)회",
                    color: .blue
                )

                // 완료 태스크
                CardStatRow(
                    icon: "checkmark.circle.fill",
                    label: "완료 태스크",
                    value: "\(employee.statistics.tasksCompleted)개",
                    color: .green
                )

                // 작성 문서
                CardStatRow(
                    icon: "doc.text.fill",
                    label: "작성 문서",
                    value: "\(employee.statistics.documentsCreated)개",
                    color: .orange
                )

                // 협업
                CardStatRow(
                    icon: "person.2.fill",
                    label: "협업",
                    value: "\(employee.statistics.collaborationCount)회",
                    color: .purple
                )

                Divider()
                    .padding(.horizontal)

                // 토큰 사용량
                VStack(spacing: 4) {
                    HStack {
                        Image(systemName: "cpu.fill")
                            .foregroundStyle(.pink)
                        Text("토큰 사용")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(formatTokens(employee.statistics.totalTokensUsed))
                                .font(.title3.bold())
                            Text("총 사용")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("$\(calculateCost())")
                                .font(.callout.bold())
                                .foregroundStyle(.green)
                            Text("예상 비용")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()

                // 입사일
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption2)
                    Text("입사: \(employee.hireDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2)
                }
                .foregroundStyle(.tertiary)
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 8)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }

    private func formatTokens(_ tokens: Int) -> String {
        if tokens >= 1_000_000 {
            return String(format: "%.1fM", Double(tokens) / 1_000_000)
        } else if tokens >= 1_000 {
            return String(format: "%.1fK", Double(tokens) / 1_000)
        } else {
            return "\(tokens)"
        }
    }

    private func calculateCost() -> String {
        let inputCost = Double(employee.statistics.inputTokens) / 1_000_000.0 * 3.0
        let outputCost = Double(employee.statistics.outputTokens) / 1_000_000.0 * 15.0
        let totalCost = inputCost + outputCost
        return String(format: "%.3f", totalCost)
    }
}

/// 카드 통계 행
struct CardStatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.bold())
        }
        .padding(.horizontal)
    }
}

#Preview {
    EmployeeDirectoryView()
        .environmentObject(CompanyStore())
}
