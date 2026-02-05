import SwiftUI

/// 사원증 뷰
struct EmployeeIDCardView: View {
    let employee: EmployeeInfo
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text("사원증")
                    .font(.title2.bold())
                Spacer()
                Button("닫기") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            ScrollView {
                VStack(spacing: 24) {
                    // ID 카드
                    idCard

                    // 상세 정보
                    detailSection

                    // 통계
                    statisticsSection
                }
                .padding()
            }
        }
        .frame(width: 600, height: 700)
    }

    // MARK: - ID 카드

    private var idCard: some View {
        VStack(spacing: 0) {
            // 카드 상단 (회사 로고 영역)
            ZStack {
                LinearGradient(
                    colors: [employee.departmentType.color.opacity(0.8), employee.departmentType.color],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 120)

                VStack(spacing: 4) {
                    Text("PixelOffice")
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    Text("EMPLOYEE ID CARD")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                }
            }

            // 카드 내용
            HStack(spacing: 24) {
                // 왼쪽: 사진
                VStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                            .frame(width: 140, height: 140)
                            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)

                        PixelCharacter(
                            appearance: employee.appearance,
                            status: .idle,
                            aiType: employee.aiType
                        )
                        .scaleEffect(3)
                    }

                    // AI 유형 뱃지
                    HStack(spacing: 4) {
                        Image(systemName: employee.aiType.icon)
                        Text(employee.aiType.rawValue)
                    }
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(employee.aiType.color.opacity(0.15))
                    .foregroundStyle(employee.aiType.color)
                    .cornerRadius(12)
                }

                // 오른쪽: 정보
                VStack(alignment: .leading, spacing: 12) {
                    // 이름
                    VStack(alignment: .leading, spacing: 2) {
                        Text("NAME")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(employee.name)
                            .font(.title.bold())
                    }

                    Divider()

                    // 사원번호
                    InfoRow(label: "사원번호", value: employee.employeeNumber, icon: "number")

                    // 부서
                    HStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "building.2")
                                .font(.caption2)
                            Text("부서")
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .leading)

                        HStack(spacing: 4) {
                            Image(systemName: employee.departmentType.icon)
                            Text(employee.departmentType.rawValue + "팀")
                        }
                        .font(.callout.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(employee.departmentType.color.opacity(0.15))
                        .foregroundStyle(employee.departmentType.color)
                        .cornerRadius(8)
                    }

                    // 직무
                    InfoRow(
                        label: "직무",
                        value: employee.jobRoles.map { $0.rawValue }.joined(separator: ", "),
                        icon: "briefcase"
                    )

                    // 입사일
                    InfoRow(
                        label: "입사일",
                        value: employee.hireDate.formatted(date: .abbreviated, time: .omitted),
                        icon: "calendar"
                    )

                    // 프로젝트 (있으면)
                    if let project = employee.projectName {
                        InfoRow(label: "프로젝트", value: project, icon: "folder")
                    }

                    // 상태
                    HStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "circle")
                                .font(.caption2)
                            Text("상태")
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .leading)

                        HStack(spacing: 4) {
                            Circle()
                                .fill(employee.status.color)
                                .frame(width: 8, height: 8)
                            Text(employee.status.rawValue)
                        }
                        .font(.callout)
                        .foregroundStyle(.primary)
                    }
                }
                .padding(.vertical)

                Spacer()
            }
            .padding(24)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
    }

    // MARK: - 상세 정보

    private var detailSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("프로필")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                DetailRow(icon: "sparkles", title: "성격", value: employee.personality)
                DetailRow(icon: "briefcase", title: "업무 스타일", value: employee.workStyle)

                if !employee.strengths.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                            Text("강점")
                                .font(.callout.weight(.medium))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(employee.strengths, id: \.self) { strength in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color.orange.opacity(0.3))
                                        .frame(width: 6, height: 6)
                                    Text(strength)
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.leading, 20)
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                    .cornerRadius(8)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 통계

    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("활동 통계")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                StatCard(
                    icon: "message.fill",
                    title: "대화 횟수",
                    value: "\(employee.statistics.conversationCount)회",
                    color: .blue
                )

                StatCard(
                    icon: "doc.text.fill",
                    title: "작성 문서",
                    value: "\(employee.statistics.documentsCreated)개",
                    color: .green
                )

                StatCard(
                    icon: "checkmark.circle.fill",
                    title: "완료 태스크",
                    value: "\(employee.statistics.tasksCompleted)개",
                    color: .orange
                )

                StatCard(
                    icon: "person.2.fill",
                    title: "협업 횟수",
                    value: "\(employee.statistics.collaborationCount)회",
                    color: .purple
                )
            }

            // 토큰 사용량
            if employee.statistics.totalTokensUsed > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "cpu.fill")
                            .foregroundStyle(.pink)
                        Text("토큰 사용량")
                            .font(.callout.weight(.medium))
                    }

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("총 사용")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("\(formatNumber(employee.statistics.totalTokensUsed))")
                                .font(.title3.bold())
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 2) {
                            Text("대화당 평균")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("\(formatNumber(Int(employee.statistics.tokensPerConversation)))")
                                .font(.callout.weight(.medium))
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 2) {
                            Text("예상 비용")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("$\(calculateCost())")
                                .font(.callout.weight(.medium))
                                .foregroundStyle(.green)
                        }
                    }
                    .padding()
                    .background(Color.pink.opacity(0.05))
                    .cornerRadius(8)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    private func calculateCost() -> String {
        let inputCost = Double(employee.statistics.inputTokens) / 1_000_000.0 * 3.0
        let outputCost = Double(employee.statistics.outputTokens) / 1_000_000.0 * 15.0
        let totalCost = inputCost + outputCost
        return String(format: "%.4f", totalCost)
    }
}

// MARK: - Supporting Views

struct InfoRow: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(label)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .frame(width: 80, alignment: .leading)

            Text(value)
                .font(.callout)
                .foregroundStyle(.primary)
        }
    }
}

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.orange)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.callout)
                    .foregroundStyle(.primary)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }
}

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2.bold())
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(color.opacity(0.05))
        .cornerRadius(8)
    }
}

#Preview {
    EmployeeIDCardView(employee: EmployeeInfo(
        id: UUID(),
        name: "Claude-기획",
        employeeNumber: "EMP-001",
        aiType: .claude,
        departmentType: .planning,
        departmentName: "기획팀",
        jobRoles: [.strategist, .productManager],
        personality: "전략적이고 분석적인 성향",
        strengths: ["데이터 분석", "전략 수립", "문제 해결"],
        workStyle: "체계적이고 계획적인 업무 스타일",
        status: .working,
        appearance: CharacterAppearance.random(),
        hireDate: Date(),
        projectName: "웹사이트 리뉴얼",
        statistics: EmployeeStatistics()
    ))
}
