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
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 16)], spacing: 16) {
                        ForEach(filteredEmployees) { employee in
                            EmployeeDirectoryCard(employee: employee) {
                                selectedEmployee = employee
                            }
                        }
                    }
                    .padding()
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

/// 직원 디렉토리 카드
struct EmployeeDirectoryCard: View {
    let employee: EmployeeInfo
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // 캐릭터
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(employee.departmentType.color.opacity(0.2))
                        .frame(width: 80, height: 80)

                    PixelCharacter(
                        appearance: employee.appearance,
                        status: employee.status,
                        aiType: employee.aiType
                    )
                    .scaleEffect(0.9)

                    // 상태 표시
                    Circle()
                        .fill(employee.status.color)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white, lineWidth: 2)
                        )
                }

                VStack(spacing: 4) {
                    // 이름
                    Text(employee.name)
                        .font(.headline)

                    // 사원번호
                    Text(employee.employeeNumber)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    // 부서 & AI 유형
                    HStack(spacing: 6) {
                        HStack(spacing: 3) {
                            Image(systemName: employee.departmentType.icon)
                            Text(employee.departmentType.rawValue)
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(employee.departmentType.color.opacity(0.15))
                        .foregroundStyle(employee.departmentType.color)
                        .cornerRadius(8)

                        Image(systemName: employee.aiType.icon)
                            .font(.caption)
                            .foregroundStyle(employee.aiType.color)
                    }

                    // 프로젝트 (있으면)
                    if let project = employee.projectName {
                        HStack(spacing: 3) {
                            Image(systemName: "folder.fill")
                            Text(project)
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }

                    Divider()
                        .padding(.horizontal)

                    // 직무
                    Text(employee.jobRoles.map { $0.rawValue }.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 8)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    EmployeeDirectoryView()
        .environmentObject(CompanyStore())
}
