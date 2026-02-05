import SwiftUI

/// 토론 메인 뷰 — 토론 생성 + 진행 + 결과 확인
struct DebateView: View {
    @EnvironmentObject var companyStore: CompanyStore
    @StateObject private var debateService = StructuredDebateService.shared

    @State private var showNewDebate = false

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            header

            Divider()

            if debateService.activeDebates.isEmpty && debateService.debateHistory.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // 진행 중인 토론
                        if !debateService.activeDebates.isEmpty {
                            Section {
                                ForEach(debateService.activeDebates) { debate in
                                    DebateCard(debate: debate, isActive: true)
                                }
                            } header: {
                                Text("진행 중")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // 완료된 토론
                        if !debateService.debateHistory.isEmpty {
                            Section {
                                ForEach(debateService.debateHistory) { debate in
                                    DebateCard(debate: debate, isActive: false)
                                }
                            } header: {
                                Text("완료")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .sheet(isPresented: $showNewDebate) {
            NewDebateSheet()
                .environmentObject(companyStore)
        }
    }

    // MARK: - 헤더

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("🏛️ 구조화된 토론")
                    .font(.title2.bold())
                Text("AI 직원들이 구조화된 토론을 통해 인사이트를 도출합니다")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                showNewDebate = true
            } label: {
                Label("새 토론", systemImage: "plus.circle.fill")
                    .font(.callout.weight(.medium))
            }
            .buttonStyle(.borderedProminent)
            .disabled(debateService.isRunning)
        }
        .padding(20)
    }

    // MARK: - 빈 상태

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("아직 토론이 없습니다")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("새 토론을 시작하면 AI 직원들이\n구조화된 토론을 통해 인사이트를 도출합니다")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Button {
                showNewDebate = true
            } label: {
                Label("첫 토론 시작하기", systemImage: "plus.circle.fill")
                    .font(.callout.weight(.medium))
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 토론 카드

struct DebateCard: View {
    let debate: Debate
    let isActive: Bool

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 토론 헤더
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: debate.status.icon)
                            .foregroundStyle(debate.status.color)
                        Text(debate.topic)
                            .font(.headline)
                        Text(debate.status.rawValue)
                            .font(.callout)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(debate.status.color.opacity(0.15))
                            .foregroundStyle(debate.status.color)
                            .clipShape(Capsule())
                    }

                    HStack(spacing: 12) {
                        // 참여자
                        HStack(spacing: 4) {
                            Image(systemName: "person.2.fill")
                                .font(.callout)
                            Text(debate.participants.map { $0.employeeName }.joined(separator: ", "))
                                .font(.callout)
                        }
                        .foregroundStyle(.secondary)

                        // 날짜
                        Text(debate.createdAt, style: .relative)
                            .font(.callout)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                // 진행률 (진행 중일 때)
                if isActive {
                    ProgressView(value: debate.progress)
                        .frame(width: 80)
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // 페이즈 인디케이터
            phaseIndicator

            // 확장 시 상세 내용
            if isExpanded {
                Divider()
                debateDetail
            }
        }
        .padding(16)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - 페이즈 인디케이터

    private var phaseIndicator: some View {
        HStack(spacing: 4) {
            ForEach(DebatePhaseType.allCases, id: \.rawValue) { phaseType in
                let isCompleted = debate.phases.contains { $0.type == phaseType && $0.isCompleted }
                let isCurrent = debate.currentPhaseType == phaseType && debate.status == .inProgress

                HStack(spacing: 4) {
                    Image(systemName: phaseType.icon)
                        .font(.callout)
                    Text(phaseType.rawValue)
                        .font(.callout)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    isCurrent ? phaseType.color.opacity(0.2) :
                    isCompleted ? phaseType.color.opacity(0.1) :
                    Color.secondary.opacity(0.05)
                )
                .foregroundStyle(
                    isCurrent ? phaseType.color :
                    isCompleted ? phaseType.color.opacity(0.7) :
                    .secondary.opacity(0.5)
                )
                .clipShape(Capsule())

                if phaseType != .synthesis {
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary.opacity(0.3))
                }
            }
        }
    }

    // MARK: - 상세 내용

    @ViewBuilder
    private var debateDetail: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 배경 정보
            if !debate.context.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("배경")
                        .font(.callout.weight(.semibold))
                    Text(debate.context)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            // 페이즈별 의견
            ForEach(debate.phases.filter { !$0.opinions.isEmpty }) { phase in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: phase.type.icon)
                            .foregroundStyle(phase.type.color)
                        Text(phase.type.rawValue)
                            .font(.callout.weight(.semibold))
                    }

                    ForEach(phase.opinions) { opinion in
                        OpinionCard(opinion: opinion)
                    }
                }
            }

            // 종합 결과
            if let synthesis = debate.synthesis {
                SynthesisCard(synthesis: synthesis)
            }
        }
    }
}

// MARK: - 의견 카드

struct OpinionCard: View {
    let opinion: DebateOpinion
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: opinion.departmentType.icon)
                    .foregroundStyle(opinion.departmentType.color)
                Text(opinion.employeeName)
                    .font(.callout.weight(.medium))
                Text("(\(opinion.departmentType.rawValue)팀)")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    withAnimation { isExpanded.toggle() }
                } label: {
                    Text(isExpanded ? "접기" : "펼치기")
                        .font(.callout)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                Text(opinion.content)
                    .font(.callout)
                    .textSelection(.enabled)
                    .padding(12)
                    .background(Color.secondary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Text(opinion.content.prefix(150) + (opinion.content.count > 150 ? "..." : ""))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(opinion.departmentType.color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - 종합 결과 카드

struct SynthesisCard: View {
    let synthesis: DebateSynthesis

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "lightbulb.max.fill")
                    .foregroundStyle(.green)
                Text("종합 결과")
                    .font(.headline)
            }

            // 핵심 요약
            VStack(alignment: .leading, spacing: 4) {
                Text("핵심 요약")
                    .font(.callout.weight(.semibold))
                Text(synthesis.summary)
                    .font(.callout)
            }

            // 합의 사항
            if !synthesis.agreements.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("✅ 합의 사항")
                        .font(.callout.weight(.semibold))
                    ForEach(synthesis.agreements, id: \.self) { item in
                        Text("• \(item)")
                            .font(.callout)
                    }
                }
            }

            // 쟁점
            if !synthesis.disagreements.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("⚠️ 쟁점")
                        .font(.callout.weight(.semibold))
                    ForEach(synthesis.disagreements, id: \.self) { item in
                        Text("• \(item)")
                            .font(.callout)
                    }
                }
            }

            // 액션 아이템
            if !synthesis.actionItems.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("📋 액션 아이템")
                        .font(.callout.weight(.semibold))
                    ForEach(synthesis.actionItems) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Text(item.priority.rawValue)
                                .font(.callout)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(item.priority.color.opacity(0.15))
                                .foregroundStyle(item.priority.color)
                                .clipShape(Capsule())
                            Text(item.title)
                                .font(.callout)
                        }
                    }
                }
            }

            // 인사이트
            if !synthesis.keyInsights.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("💡 핵심 인사이트")
                        .font(.callout.weight(.semibold))
                    ForEach(synthesis.keyInsights, id: \.self) { item in
                        Text("• \(item)")
                            .font(.callout)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.green.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - 새 토론 시트

struct NewDebateSheet: View {
    @EnvironmentObject var companyStore: CompanyStore
    @Environment(\.dismiss) private var dismiss

    @State private var topic = ""
    @State private var context = ""
    @State private var selectedParticipants: Set<UUID> = []
    @State private var selectedProjectId: UUID?
    @State private var crossReviewRounds = 1
    @State private var autoPostToCommunity = true
    @State private var saveToWiki = true
    @State private var useProjectEmployees = false

    private var availableEmployees: [(Employee, DepartmentType)] {
        companyStore.company.departments.flatMap { dept in
            dept.employees.map { ($0, dept.type) }
        }
    }

    private var availableProjectEmployees: [(ProjectEmployee, UUID)] {
        guard let projectId = selectedProjectId,
              let project = companyStore.company.projects.first(where: { $0.id == projectId }) else { return [] }
        return project.allEmployees.map { ($0, projectId) }
    }

    private var canStart: Bool {
        !topic.isEmpty && selectedParticipants.count >= 2
    }

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text("새 토론 시작")
                    .font(.title2.bold())
                Spacer()
                Button("취소") { dismiss() }
                    .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 주제
                    VStack(alignment: .leading, spacing: 8) {
                        Text("토론 주제")
                            .font(.callout.weight(.semibold))
                        TextField("예: 신규 기능 우선순위 결정", text: $topic)
                            .textFieldStyle(.roundedBorder)
                            .font(.callout)
                    }

                    // 배경
                    VStack(alignment: .leading, spacing: 8) {
                        Text("배경 정보 (선택)")
                            .font(.callout.weight(.semibold))
                        TextEditor(text: $context)
                            .font(.callout)
                            .frame(height: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    }

                    // 프로젝트 선택
                    VStack(alignment: .leading, spacing: 8) {
                        Text("프로젝트 (선택)")
                            .font(.callout.weight(.semibold))

                        Picker("프로젝트", selection: $selectedProjectId) {
                            Text("전사").tag(nil as UUID?)
                            ForEach(companyStore.company.projects) { project in
                                Text(project.name).tag(project.id as UUID?)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: selectedProjectId) { _, _ in
                            selectedParticipants.removeAll()
                            useProjectEmployees = selectedProjectId != nil
                        }
                    }

                    // 참여자 선택
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("참여자 (최소 2명)")
                                .font(.callout.weight(.semibold))
                            Spacer()
                            Text("\(selectedParticipants.count)명 선택")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }

                        if useProjectEmployees && selectedProjectId != nil {
                            // 프로젝트 직원 목록
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 8) {
                                ForEach(availableProjectEmployees, id: \.0.id) { (employee, projectId) in
                                    participantChip(
                                        id: employee.id,
                                        name: employee.name,
                                        department: employee.departmentType,
                                        isSelected: selectedParticipants.contains(employee.id)
                                    )
                                }
                            }
                        } else {
                            // 전사 직원 목록
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 8) {
                                ForEach(availableEmployees, id: \.0.id) { (employee, deptType) in
                                    participantChip(
                                        id: employee.id,
                                        name: employee.name,
                                        department: deptType,
                                        isSelected: selectedParticipants.contains(employee.id)
                                    )
                                }
                            }
                        }
                    }

                    Divider()

                    // 설정
                    VStack(alignment: .leading, spacing: 12) {
                        Text("설정")
                            .font(.callout.weight(.semibold))

                        Stepper("교차 검토 라운드: \(crossReviewRounds)", value: $crossReviewRounds, in: 1...3)
                            .font(.callout)

                        Toggle("완료 후 커뮤니티에 게시", isOn: $autoPostToCommunity)
                            .font(.callout)

                        Toggle("위키에 회의록 저장", isOn: $saveToWiki)
                            .font(.callout)
                    }
                }
                .padding(20)
            }

            Divider()

            // 시작 버튼
            HStack {
                Spacer()
                Button {
                    startDebate()
                } label: {
                    Label("토론 시작", systemImage: "play.fill")
                        .font(.callout.weight(.medium))
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canStart)
            }
            .padding(20)
        }
        .frame(width: 600, height: 700)
    }

    // MARK: - 참여자 칩

    private func participantChip(id: UUID, name: String, department: DepartmentType, isSelected: Bool) -> some View {
        Button {
            if isSelected {
                selectedParticipants.remove(id)
            } else {
                selectedParticipants.insert(id)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: department.icon)
                    .font(.callout)
                VStack(alignment: .leading, spacing: 0) {
                    Text(name)
                        .font(.callout.weight(.medium))
                    Text(department.rawValue)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? department.color.opacity(0.15) : Color.secondary.opacity(0.05))
            .foregroundStyle(isSelected ? department.color : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? department.color : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 토론 시작

    private func startDebate() {
        let debateService = StructuredDebateService.shared
        let settings = DebateSettings(
            crossReviewRounds: crossReviewRounds,
            autoPostToCommunity: autoPostToCommunity,
            saveToWiki: saveToWiki && selectedProjectId != nil
        )

        // 참여자 생성
        var participants: [DebateParticipant] = []

        if useProjectEmployees, let projectId = selectedProjectId,
           let project = companyStore.company.projects.first(where: { $0.id == projectId }) {
            for employee in project.allEmployees where selectedParticipants.contains(employee.id) {
                participants.append(debateService.makeParticipant(from: employee, projectId: projectId))
            }
        } else {
            for dept in companyStore.company.departments {
                for employee in dept.employees where selectedParticipants.contains(employee.id) {
                    participants.append(debateService.makeParticipant(from: employee, departmentType: dept.type))
                }
            }
        }

        let debate = debateService.createDebate(
            topic: topic,
            context: context,
            participants: participants,
            projectId: selectedProjectId,
            settings: settings
        )

        // 백그라운드 실행
        Task {
            await debateService.runDebate(debate.id)
        }

        dismiss()
    }
}
