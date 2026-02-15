import SwiftUI

/// 커뮤니티 뷰 - 직원들의 생각과 소통을 보여줌
struct CommunityView: View {
    @EnvironmentObject var companyStore: CompanyStore
    @State private var selectedFilter: CommunityFilter = .all

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("커뮤니티")
                        .font(.title.bold())
                    Text("직원들의 생각과 소통")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            // 필터 탭
            HStack(spacing: 0) {
                ForEach(CommunityFilter.allCases, id: \.self) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: filter.icon)
                            Text(filter.rawValue)
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedFilter == filter ? Color.accentColor.opacity(0.2) : Color.clear)
                        .foregroundColor(selectedFilter == filter ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

            // 콘텐츠
            ScrollView {
                VStack(spacing: 16) {
                    switch selectedFilter {
                    case .all:
                        allContentSection
                    case .thoughts:
                        thoughtsSection
                    case .meetings:
                        meetingsSection
                    case .communications:
                        communicationsSection
                    case .employees:
                        employeesSection
                    case .guides:
                        guidesSection
                    }
                }
                .padding()
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - All Content

    @ViewBuilder
    private var allContentSection: some View {
        // 협업 기록
        if !companyStore.collaborationRecords.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("최근 협업")
                    .font(.headline)
                    .foregroundColor(.secondary)

                ForEach(Array(companyStore.collaborationRecords.prefix(3)), id: \.id) { record in
                    CommunityCollaborationCard(record: record)
                }
            }
        }

        // 직원 목록
        VStack(alignment: .leading, spacing: 12) {
            Text("우리 팀원들")
                .font(.headline)
                .foregroundColor(.secondary)

            CommunityEmployeeGrid(employees: companyStore.company.allEmployees)
        }
    }

    // MARK: - Thoughts Section (직원들의 게시글)

    @ViewBuilder
    private var thoughtsSection: some View {
        if companyStore.communityPosts.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "thought.bubble")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary.opacity(0.5))
                Text("아직 게시글이 없습니다")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("직원들이 충분한 정보를 축적하면\n자동으로 인사이트를 게시합니다")
                    .font(.subheadline)
                    .foregroundColor(.secondary.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
        } else {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(companyStore.communityPosts) { post in
                    CommunityPostCard(post: post)
                }
            }
        }
    }

    // MARK: - Meetings Section
    
    @ViewBuilder
    private var meetingsSection: some View {
        MeetingsView()
            .environmentObject(companyStore)
    }
    
    // MARK: - Communications Section

    @ViewBuilder
    private var communicationsSection: some View {
        if companyStore.collaborationRecords.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary.opacity(0.5))
                Text("아직 소통 기록이 없습니다")
                    .font(.headline)
                    .foregroundColor(.secondary)
                Text("직원들이 멘션(@)을 통해 협업하면 여기에 표시됩니다")
                    .font(.subheadline)
                    .foregroundColor(.secondary.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
        } else {
            ForEach(companyStore.collaborationRecords, id: \.id) { record in
                CommunityCollaborationCard(record: record)
            }
        }
    }

    // MARK: - Employees Section

    @ViewBuilder
    private var employeesSection: some View {
        EmployeeDirectoryView()
    }

    // MARK: - Guides Section

    @ViewBuilder
    private var guidesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("가이드 & 매뉴얼")
                .font(.headline)
                .foregroundColor(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 16)], spacing: 16) {
                GuideCard(
                    title: "사장님 매뉴얼",
                    description: "AI 직원 관리 및 협업 가이드",
                    icon: "book.fill",
                    color: .blue,
                    filePath: "\(DataPathService.shared.basePath)/_shared/documents/사장님-매뉴얼.md"
                )

                GuideCard(
                    title: "부서별 업무 가이드",
                    description: "기획/디자인/개발/QA/마케팅",
                    icon: "person.3.fill",
                    color: .orange,
                    filePath: "\(DataPathService.shared.basePath)/_shared/documents/사장님-매뉴얼.md"
                )

                GuideCard(
                    title: "문서 폴더 열기",
                    description: "공용 문서 폴더 보기",
                    icon: "folder.fill",
                    color: .green,
                    filePath: "\(DataPathService.shared.basePath)/_shared/documents"
                )
            }
        }
    }
}

// MARK: - Employee Grid

struct CommunityEmployeeGrid: View {
    let employees: [Employee]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 16)], spacing: 16) {
            ForEach(employees, id: \.id) { employee in
                CommunityEmployeeCard(employee: employee)
            }
        }
    }
}

// MARK: - Employee Card

struct CommunityEmployeeCard: View {
    let employee: Employee
    @State private var showingDetail = false

    var body: some View {
        Button {
            showingDetail = true
        } label: {
            VStack(spacing: 10) {
                // 캐릭터와 상태
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(employee.department.color.opacity(0.2))
                        .frame(width: 70, height: 70)
                    PixelCharacter(
                        appearance: employee.characterAppearance,
                        status: employee.status,
                        aiType: employee.aiType
                    )
                    .scaleEffect(0.8)

                    // 상태 표시
                    Circle()
                        .fill(employee.status.color)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white, lineWidth: 2)
                        )
                }

                VStack(spacing: 6) {
                    // 이름과 부서
                    HStack(spacing: 4) {
                        Text(employee.name)
                            .font(.headline)
                        Image(systemName: employee.department.icon)
                            .font(.caption)
                            .foregroundColor(employee.department.color)
                    }

                    // 직무
                    Text(employee.jobRoles.map { $0.rawValue }.joined(separator: ", "))
                        .font(.caption.bold())
                        .foregroundColor(employee.department.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(employee.department.color.opacity(0.15))
                        .clipShape(Capsule())
                        .lineLimit(2)

                    // 사원번호
                    Text(employee.employeeNumber)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Divider()
                        .padding(.horizontal, 8)

                    // 성격
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Text(employee.personality)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .lineLimit(1)

                    // 강점 (첫 번째만)
                    if let firstStrength = employee.strengths.first {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                            Text(firstStrength)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .lineLimit(1)
                    }

                    // 완료 태스크
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                        Text("완료: \(employee.totalTasksCompleted)개")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(12)
            .frame(width: 200)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(employee.department.color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingDetail) {
            CommunityEmployeeDetailView(employee: employee)
        }
    }
}

// MARK: - Employee Detail Popover

struct CommunityEmployeeDetailView: View {
    let employee: Employee
    @State private var showStatistics = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 사원증
                EmployeeBadgeView(
                    name: employee.name,
                    employeeNumber: employee.employeeNumber,
                    departmentType: employee.department,
                    aiType: employee.aiType,
                    appearance: employee.characterAppearance,
                    hireDate: employee.createdAt,
                    jobRoles: employee.jobRoles,
                    personality: employee.personality,
                    strengths: employee.strengths,
                    workStyle: employee.workStyle,
                    statistics: employee.statistics
                )

                Divider()

                // 상세 정보
                VStack(alignment: .leading, spacing: 16) {
                    // 현재 상태
                    InfoSection(
                        title: "현재 상태",
                        icon: "circle.fill",
                        iconColor: employee.status.color
                    ) {
                        Text(employee.status.rawValue)
                            .font(.body)
                    }

                    // 성격
                    InfoSection(
                        title: "성격",
                        icon: "sparkles",
                        iconColor: .orange
                    ) {
                        Text(employee.personality)
                            .font(.body)
                    }

                    // 강점
                    InfoSection(
                        title: "강점",
                        icon: "star.fill",
                        iconColor: .yellow
                    ) {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(employee.strengths, id: \.self) { strength in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color.yellow.opacity(0.3))
                                        .frame(width: 6, height: 6)
                                    Text(strength)
                                        .font(.caption)
                                }
                            }
                        }
                    }

                    // 업무 스타일
                    InfoSection(
                        title: "업무 스타일",
                        icon: "briefcase.fill",
                        iconColor: .blue
                    ) {
                        Text(employee.workStyle)
                            .font(.body)
                    }

                    // 업무 기록 (통계 버튼 포함)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.text.fill")
                                    .foregroundColor(.green)
                                Text("업무 기록")
                                    .font(.headline)
                            }

                            Spacer()

                            Button(action: {
                                withAnimation {
                                    showStatistics.toggle()
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "chart.bar.fill")
                                    Text(showStatistics ? "간단히 보기" : "상세 통계")
                                }
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(employee.department.color.opacity(0.2))
                                .foregroundColor(employee.department.color)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }

                        if showStatistics {
                            // 상세 통계 표시
                            EmployeeStatisticsDetailView(
                                statistics: employee.statistics,
                                departmentColor: employee.department.color
                            )
                        } else {
                            // 간단한 통계
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("완료한 작업:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(employee.totalTasksCompleted)개")
                                        .font(.caption.bold())
                                }

                                HStack {
                                    Text("대화 기록:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(employee.conversationHistory.count)개")
                                        .font(.caption.bold())
                                }

                                HStack {
                                    Text("입사일:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(employee.createdAt.formatted(date: .long, time: .omitted))
                                        .font(.caption.bold())
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(NSColor.windowBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
        .frame(width: 350, height: 600)
    }
}

// MARK: - Info Section Helper

struct InfoSection<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    let content: Content

    init(title: String, icon: String, iconColor: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
            }

            content
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Collaboration Card

struct CommunityCollaborationCard: View {
    let record: CollaborationRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(record.requesterName)
                    .font(.headline)
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(record.responderName)
                    .font(.headline)
                Spacer()
                Text(record.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(record.requestContent)
                .font(.body)
                .lineLimit(2)

            if !record.responseContent.isEmpty {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                    Text(record.responseContent)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Filter Enum

enum CommunityFilter: String, CaseIterable {
    case all = "전체"
    case thoughts = "생각"
    case meetings = "회의"
    case communications = "소통"
    case employees = "사원들"
    case guides = "가이드"

    var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .thoughts: return "thought.bubble"
        case .meetings: return "person.3.fill"
        case .communications: return "bubble.left.and.bubble.right"
        case .employees: return "person.2"
        case .guides: return "book.fill"
        }
    }
}

// MARK: - Conversation Card

struct ConversationCard: View {
    let conversation: CommunityConversation
    let isActive: Bool
    @State private var showingDetail = false
    
    var body: some View {
        Button {
            showingDetail = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                // 헤더
                HStack {
                    // 상태 표시
                    Circle()
                        .fill(isActive ? Color.red : Color.green)
                        .frame(width: 8, height: 8)
                    
                    Text(conversation.topic)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(formatDate(conversation.started))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // 참석자
                HStack(spacing: 4) {
                    Image(systemName: "person.2")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(conversation.participants.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // 메시지 수
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(conversation.messages.count)개 메시지")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let summary = conversation.summary {
                        Spacer()
                        Text(summary)
                            .font(.caption)
                            .foregroundColor(.blue)
                            .lineLimit(1)
                    }
                }
                
                // 마지막 메시지 미리보기
                if let lastMessage = conversation.messages.last {
                    HStack(alignment: .top, spacing: 8) {
                        Text(lastMessage.author)
                            .font(.caption.bold())
                            .foregroundColor(.primary)
                        Text(lastMessage.content)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isActive ? Color.red.opacity(0.3) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingDetail) {
            ConversationDetailView(conversation: conversation)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Conversation Detail View

struct ConversationDetailView: View {
    let conversation: CommunityConversation
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Circle()
                            .fill(conversation.status == .inProgress ? Color.red : Color.green)
                            .frame(width: 10, height: 10)
                        Text(conversation.topic)
                            .font(.title2.bold())
                    }
                    Text("주최: \(conversation.initiator)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            // 참석자
            HStack {
                Image(systemName: "person.3.fill")
                    .foregroundColor(.blue)
                Text("참석자: \(conversation.participants.joined(separator: ", "))")
                    .font(.subheadline)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            
            // 대화 내용
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(conversation.messages, id: \.id) { message in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(message.author)
                                    .font(.subheadline.bold())
                                Spacer()
                                Text(formatTime(message.timestamp))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text(message.content)
                                .font(.body)
                        }
                        .padding()
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding()
            }
            
            // 요약 (완료된 경우)
            if let summary = conversation.summary {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("📋 회의 요약")
                        .font(.headline)
                    Text(summary)
                        .font(.body)
                }
                .padding()
                .background(Color.green.opacity(0.1))
            }
        }
        .frame(width: 500, height: 600)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Community Post Card

struct CommunityPostCard: View {
    let post: CommunityPost
    @EnvironmentObject var companyStore: CompanyStore
    @State private var showingDetail = false

    var body: some View {
        Button {
            showingDetail = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                // 헤더: 작성자 정보
                HStack {
                    ZStack {
                        Circle()
                            .fill(post.departmentType.color.opacity(0.2))
                            .frame(width: 40, height: 40)
                        Image(systemName: post.departmentType.icon)
                            .foregroundColor(post.departmentType.color)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(post.employeeName)
                                .font(.headline)
                                .foregroundColor(.primary)

                            // 자율 소통인 경우 두 번째 직원 표시
                            if post.source == .autonomous, let secondName = post.secondaryEmployeeName {
                                Text("×")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(secondName)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                        }
                        Text("\(post.departmentType.rawValue)팀 · \(post.formattedDate)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // 출처 뱃지
                    HStack(spacing: 4) {
                        Image(systemName: post.source.icon)
                        Text(post.source.rawValue)
                    }
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(post.source.color.opacity(0.15))
                    .foregroundColor(post.source.color)
                    .clipShape(Capsule())
                }

                // 제목
                Text(post.title)
                    .font(.title3.bold())
                    .foregroundColor(.primary)
                    .lineLimit(2)

                // 요약
                Text(post.summary)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(3)

                // 태그
                if !post.tags.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(post.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .clipShape(Capsule())
                        }
                    }
                }

                // 하단: 좋아요, 댓글
                HStack {
                    Button {
                        companyStore.likeCommunityPost(post.id)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "heart")
                            Text("\(post.likes)")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                        Text("\(post.comments.count)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)

                    Spacer()

                    Text("자세히 보기")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingDetail) {
            CommunityPostDetailView(post: post)
        }
    }
}

// MARK: - Community Post Detail View

struct CommunityPostDetailView: View {
    let post: CommunityPost
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var companyStore: CompanyStore
    @State private var newComment = ""

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text(post.title)
                    .font(.title2.bold())
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 작성자 정보
                    HStack {
                        ZStack {
                            Circle()
                                .fill(post.departmentType.color.opacity(0.2))
                                .frame(width: 50, height: 50)
                            Image(systemName: post.departmentType.icon)
                                .font(.title2)
                                .foregroundColor(post.departmentType.color)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(post.employeeName)
                                .font(.headline)
                            Text("\(post.departmentType.rawValue)팀")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text(post.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    // 본문 (마크다운 → HTML 렌더링)
                    HTMLContentView(content: MarkdownToHTMLConverter.convert(post.content))

                    // 태그
                    if !post.tags.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "tag")
                                .foregroundColor(.secondary)
                            ForEach(post.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    Divider()

                    // 좋아요
                    HStack {
                        Button {
                            companyStore.likeCommunityPost(post.id)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "heart.fill")
                                Text("\(post.likes) 좋아요")
                            }
                        }
                        .buttonStyle(.bordered)

                        Spacer()
                    }

                    // 댓글 섹션
                    VStack(alignment: .leading, spacing: 12) {
                        Text("댓글 \(post.comments.count)개")
                            .font(.headline)

                        ForEach(post.comments) { comment in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(comment.employeeName)
                                        .font(.subheadline.bold())
                                    Spacer()
                                    Text(comment.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Text(comment.content)
                                    .font(.body)
                            }
                            .padding()
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 600, height: 700)
    }
}

// MARK: - Guide Card

struct GuideCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let filePath: String

    var body: some View {
        Button {
            openFile()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .padding()
            .frame(minWidth: 200)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func openFile() {
        let url = URL(fileURLWithPath: filePath)
        NSWorkspace.shared.open(url)
    }
}

// MARK: - Employee Statistics Detail View

struct EmployeeStatisticsDetailView: View {
    let statistics: EmployeeStatistics
    let departmentColor: Color

    var body: some View {
        VStack(spacing: 16) {
            // 토큰 사용량
            VStack(alignment: .leading, spacing: 8) {
                Text("토큰 사용량")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                VStack(spacing: 6) {
                    StatRowCompact(
                        icon: "cpu",
                        label: "총 사용",
                        value: formatNumber(statistics.totalTokensUsed),
                        color: .blue
                    )

                    StatRowCompact(
                        icon: "arrow.down.circle",
                        label: "입력",
                        value: formatNumber(statistics.inputTokens),
                        color: .green
                    )

                    StatRowCompact(
                        icon: "arrow.up.circle",
                        label: "출력",
                        value: formatNumber(statistics.outputTokens),
                        color: .orange
                    )

                    StatRowCompact(
                        icon: "speedometer",
                        label: "소비 속도",
                        value: String(format: "%.0f/시간", statistics.tokensPerHour),
                        color: .purple
                    )

                    if statistics.tokensLast24Hours > 0 {
                        StatRowCompact(
                            icon: "clock",
                            label: "최근 24시간",
                            value: formatNumber(statistics.tokensLast24Hours),
                            color: .red
                        )
                    }
                }
            }

            Divider()

            // 생산성
            VStack(alignment: .leading, spacing: 8) {
                Text("생산성")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                VStack(spacing: 6) {
                    StatRowCompact(
                        icon: "doc.text",
                        label: "작성 문서",
                        value: "\(statistics.documentsCreated)개",
                        color: .indigo
                    )

                    StatRowCompact(
                        icon: "checkmark.circle",
                        label: "완료 태스크",
                        value: "\(statistics.tasksCompleted)개",
                        color: .teal
                    )

                    StatRowCompact(
                        icon: "bubble.left.and.bubble.right",
                        label: "대화 횟수",
                        value: "\(statistics.conversationCount)회",
                        color: .cyan
                    )

                    StatRowCompact(
                        icon: "person.2",
                        label: "협업 횟수",
                        value: "\(statistics.collaborationCount)회",
                        color: .pink
                    )
                }
            }

            if statistics.totalActiveTime > 0 {
                Divider()

                // 활동 시간
                VStack(alignment: .leading, spacing: 8) {
                    Text("활동 시간")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    StatRowCompact(
                        icon: "timer",
                        label: "총 활동",
                        value: formatDuration(statistics.totalActiveTime),
                        color: departmentColor
                    )

                    if let lastActive = statistics.lastActiveDate {
                        StatRowCompact(
                            icon: "clock.arrow.circlepath",
                            label: "마지막 활동",
                            value: lastActive.formatted(date: .omitted, time: .shortened),
                            color: .secondary
                        )
                    }
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func formatNumber(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000)
        } else if number >= 1_000 {
            return String(format: "%.1fK", Double(number) / 1_000)
        } else {
            return "\(number)"
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)시간 \(minutes)분"
        } else {
            return "\(minutes)분"
        }
    }
}

/// 컴팩트한 통계 행
struct StatRowCompact: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(color)
                .frame(width: 16)

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.caption.bold())
                .foregroundColor(.primary)
        }
    }
}

#Preview {
    CommunityView()
        .environmentObject(CompanyStore())
        .frame(width: 800, height: 600)
}
