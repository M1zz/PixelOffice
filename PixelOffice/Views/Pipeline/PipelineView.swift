import SwiftUI

/// 파이프라인 메인 뷰
struct PipelineView: View {
    let projectId: UUID
    @EnvironmentObject var companyStore: CompanyStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var coordinator = PipelineCoordinator()

    @State private var requirement: String = ""
    @State private var showingLogs = false
    @State private var showingHistory = false
    @State private var selectedTab: PipelineTab = .current
    @State private var selectedEmployeeId: UUID?
    @State private var historyRefreshId = UUID()  // 히스토리 새로고침용
    @State private var showingKanbanPicker = false  // 칸반에서 가져오기
    @State private var selectedKanbanTasks: Set<UUID> = []

    enum PipelineTab: String, CaseIterable {
        case current = "현재 실행"
        case activity = "활동 현황"
        case history = "히스토리"
    }

    var project: Project? {
        companyStore.company.projects.first { $0.id == projectId }
    }

    /// 프로젝트의 모든 직원 목록
    var projectEmployees: [ProjectEmployee] {
        project?.departments.flatMap { $0.employees } ?? []
    }

    /// 선택된 담당자
    var selectedEmployee: ProjectEmployee? {
        projectEmployees.first { $0.id == selectedEmployeeId }
    }

    /// 이 프로젝트의 파이프라인 히스토리 (historyUpdateId 관찰로 자동 새로고침)
    var pipelineHistory: [PipelineRun] {
        // historyUpdateId를 참조하여 변경 시 뷰 새로고침 트리거
        _ = coordinator.historyUpdateId
        return coordinator.loadPipelineHistory(for: projectId)
    }

    /// 재개 가능한 실행
    var resumableRuns: [PipelineRun] {
        pipelineHistory.filter { $0.state.canResume }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            PipelineHeaderView(
                projectName: project?.name ?? "프로젝트",
                isRunning: coordinator.isRunning,
                onClose: { dismiss() }
            )

            // 탭 선택
            Picker("", selection: $selectedTab) {
                ForEach(PipelineTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .onChange(of: selectedTab) { _, newTab in
                if newTab == .history {
                    historyRefreshId = UUID()  // 히스토리 탭 전환 시 새로고침
                }
            }
            .sheet(isPresented: $showingKanbanPicker) {
                KanbanTaskPickerSheet(
                    tasks: project?.tasks ?? [],
                    selectedTaskIds: $selectedKanbanTasks,
                    onConfirm: { tasks in
                        fetchFromKanban(tasks)
                    }
                )
            }

            Divider()

            // 메인 콘텐츠
            switch selectedTab {
            case .current:
                currentExecutionView
            case .activity:
                activityView
            case .history:
                historyView
                    .id(historyRefreshId)  // 새로고침 트리거
            }

            Divider()

            // 하단 버튼
            bottomButtons
        }
        .frame(minWidth: 900, minHeight: 650)
        .overlay(alignment: .top) {
            // 알림 배너
            if let message = coordinator.notificationMessage {
                PipelineNotificationBanner(
                    message: message,
                    type: coordinator.notificationType,
                    onDismiss: { coordinator.dismissNotification() }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.3), value: coordinator.notificationMessage)
                .padding(.top, 50)
            }
        }
        .onAppear {
            coordinator.setCompanyStore(companyStore)
        }
        .sheet(isPresented: $showingLogs) {
            if let run = coordinator.currentRun {
                PipelineLogView(logs: run.logs)
            }
        }
    }

    // MARK: - 현재 실행 뷰

    var currentExecutionView: some View {
        HStack(spacing: 0) {
            // 왼쪽: 입력 & 결과
            ScrollView {
                VStack(spacing: 20) {
                    // 요구사항 입력 및 담당자 선택
                    RequirementInputView(
                        requirement: $requirement,
                        selectedEmployeeId: $selectedEmployeeId,
                        employees: projectEmployees,
                        isDisabled: coordinator.isRunning
                    )

                    // 재개 가능한 실행이 있으면 표시
                    if !resumableRuns.isEmpty && coordinator.currentRun == nil {
                        ResumableRunsCard(
                            runs: resumableRuns,
                            onResume: { run in resumePipeline(run) }
                        )
                    }

                    // 진행 상황
                    if let run = coordinator.currentRun {
                        PipelineProgressView(
                            run: run,
                            progress: coordinator.progress,
                            currentPhaseDescription: coordinator.currentPhaseDescription
                        )

                        // 분해된 태스크 목록
                        if !run.decomposedTasks.isEmpty {
                            DecomposedTasksView(tasks: run.decomposedTasks)
                        }

                        // 빌드 결과
                        if let lastAttempt = run.lastBuildAttempt {
                            BuildResultView(attempt: lastAttempt)
                        }
                    }
                }
                .padding()
            }
            .frame(maxWidth: .infinity)

            // 오른쪽: 실시간 TODO 패널 (실행 중일 때만)
            if coordinator.isRunning || coordinator.currentRun != nil {
                Divider()

                PipelineTodoPanel(
                    todoItems: coordinator.todoItems,
                    currentAction: coordinator.currentAction,
                    currentTaskIndex: coordinator.currentTaskIndex,
                    currentTaskName: coordinator.currentTaskName,
                    logs: coordinator.currentRun?.logs ?? []
                )
                .frame(width: 320)
            }
        }
    }

    // MARK: - 활동 현황 뷰

    var activityView: some View {
        PipelineActivityView(
            projectEmployees: projectEmployees,
            companyStore: companyStore,
            onSelectEmployee: { employee in
                // 직원 선택 시 해당 직원의 대화창으로 이동하거나 상세 보기
            }
        )
    }

    // MARK: - 히스토리 뷰

    var historyView: some View {
        PipelineHistoryView(
            history: pipelineHistory,
            onSelect: { run in
                coordinator.currentRun = run
                selectedTab = .current
            },
            onResume: { run in
                resumePipeline(run)
                selectedTab = .current
            }
        )
    }

    // MARK: - 하단 버튼

    var bottomButtons: some View {
        HStack {
            // 로그 보기
            Button {
                showingLogs.toggle()
            } label: {
                Label("로그", systemImage: "doc.text")
            }
            .disabled(coordinator.currentRun == nil)

            // 리포트 열기
            if let reportPath = coordinator.lastReportPath {
                Button {
                    openReport(at: reportPath)
                } label: {
                    Label("리포트 열기", systemImage: "doc.richtext")
                }
            }

            Spacer()

            // 완료 상태 표시
            if let run = coordinator.currentRun, !coordinator.isRunning {
                HStack(spacing: 6) {
                    Image(systemName: run.state.icon)
                        .foregroundStyle(run.state.color)
                    Text(run.state.rawValue)
                        .font(.subheadline.weight(.medium))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(run.state.color.opacity(0.1))
                .clipShape(Capsule())

                // 재개 버튼 (일시정지/실패 상태일 때)
                if run.state.canResume {
                    Button {
                        resumePipeline(run)
                    } label: {
                        Label("재개", systemImage: "play.circle")
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                }
            }

            if coordinator.isRunning {
                Button("일시정지") {
                    coordinator.cancelPipeline()
                }
                .buttonStyle(.bordered)
            } else {
                // 칸반에서 가져오기
                Button {
                    showingKanbanPicker = true
                } label: {
                    Label("칸반에서 가져오기", systemImage: "tray.and.arrow.down")
                }
                .buttonStyle(.bordered)
                .disabled((project?.tasks ?? []).isEmpty)

                Button {
                    startPipeline()
                } label: {
                    Label("새 파이프라인", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(requirement.isEmpty)
            }
        }
        .padding()
    }

    // MARK: - Actions

    private func startPipeline() {
        guard let project = project else { return }
        Task {
            await coordinator.startPipeline(
                requirement: requirement,
                project: project,
                assignedEmployee: selectedEmployee
            )
        }
    }

    private func resumePipeline(_ run: PipelineRun) {
        guard let project = project else { return }
        Task {
            await coordinator.resumePipeline(run: run, project: project)
        }
    }

    private func openReport(at path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.open(url)
    }

    private func fetchFromKanban(_ tasks: [ProjectTask]) {
        guard let project = project else { return }
        // 선택된 칸반 태스크들을 파이프라인으로 처리
        Task {
            await coordinator.startPipelineWithKanbanTasks(
                tasks: tasks,
                project: project,
                assignedEmployee: selectedEmployee
            )
        }
        coordinator.showNotification("\(tasks.count)개의 태스크를 파이프라인으로 가져왔습니다.", type: .info)
    }
}

// MARK: - 재개 가능한 실행 카드

struct ResumableRunsCard: View {
    let runs: [PipelineRun]
    let onResume: (PipelineRun) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("재개 가능한 파이프라인", systemImage: "arrow.clockwise.circle")
                .font(.headline)
                .foregroundStyle(.orange)

            ForEach(runs.prefix(3)) { run in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(run.requirement)
                            .font(.body)
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            Image(systemName: run.state.icon)
                                .foregroundStyle(run.state.color)
                            Text(run.state.rawValue)
                                .font(.caption)

                            Text("•")
                                .foregroundStyle(.secondary)

                            Text("Phase \(run.resumePhase.rawValue): \(run.resumePhase.name)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if let lastSaved = run.lastSavedAt {
                                Text("•")
                                    .foregroundStyle(.secondary)
                                Text(lastSaved, style: .relative)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Spacer()

                    Button("재개") {
                        onResume(run)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                }
                .padding(12)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - 히스토리 뷰

struct PipelineHistoryView: View {
    let history: [PipelineRun]
    let onSelect: (PipelineRun) -> Void
    let onResume: (PipelineRun) -> Void

    var body: some View {
        if history.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("파이프라인 히스토리가 없습니다")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("새 파이프라인을 실행하면 여기에 기록됩니다")
                    .font(.body)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(history) { run in
                        PipelineHistoryRow(
                            run: run,
                            onSelect: { onSelect(run) },
                            onResume: { onResume(run) }
                        )
                    }
                }
                .padding()
            }
        }
    }
}

struct PipelineHistoryRow: View {
    let run: PipelineRun
    let onSelect: () -> Void
    let onResume: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 헤더
            HStack {
                Image(systemName: run.state.icon)
                    .foregroundStyle(run.state.color)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(run.requirement)
                        .font(.body.weight(.medium))
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Text(run.state.rawValue)
                            .font(.caption)
                            .foregroundStyle(run.state.color)

                        if !run.projectName.isEmpty {
                            Text("•")
                                .foregroundStyle(.secondary)
                            Text(run.projectName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let employeeName = run.assignedEmployeeName {
                            Text("•")
                                .foregroundStyle(.secondary)
                            Label(employeeName, systemImage: "person.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text("•")
                            .foregroundStyle(.secondary)

                        Text(run.createdAt, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(run.createdAt, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // 버튼들
                HStack(spacing: 8) {
                    if run.state.canResume {
                        Button("재개") {
                            onResume()
                        }
                        .buttonStyle(.bordered)
                        .tint(.orange)
                    }

                    Button("상세") {
                        onSelect()
                    }
                    .buttonStyle(.bordered)
                }
            }

            // 진행 정보
            HStack(spacing: 16) {
                Label("\(run.decomposedTasks.count)개 태스크", systemImage: "list.bullet")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Label("\(run.buildAttempts.count)회 빌드", systemImage: "hammer")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let duration = run.duration {
                    Label(formatDuration(duration), systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // 완료된 Phase 표시
                HStack(spacing: 4) {
                    ForEach(PipelinePhase.allCases, id: \.self) { phase in
                        Circle()
                            .fill(run.completedPhases.contains(phase) ? phase.color : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
            }

            // 로그 요약
            if let lastLog = run.logs.last {
                HStack(spacing: 6) {
                    Image(systemName: lastLog.level.icon)
                        .font(.caption2)
                        .foregroundStyle(lastLog.level.color)
                    Text(lastLog.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(run.state.canResume ? Color.orange.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return "\(minutes)분 \(seconds)초"
        } else {
            return "\(seconds)초"
        }
    }
}

// MARK: - Pipeline Header

struct PipelineHeaderView: View {
    let projectName: String
    let isRunning: Bool
    let onClose: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("자동 개발 파이프라인")
                    .font(.title2.bold())
                Text(projectName)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isRunning {
                ProgressView()
                    .scaleEffect(0.8)
                    .padding(.trailing, 8)
            }

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
}

// MARK: - Requirement Input

struct RequirementInputView: View {
    @Binding var requirement: String
    @Binding var selectedEmployeeId: UUID?
    let employees: [ProjectEmployee]
    let isDisabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 요구사항 입력
            VStack(alignment: .leading, spacing: 8) {
                Label("요구사항", systemImage: "text.alignleft")
                    .font(.headline)

                TextEditor(text: $requirement)
                    .font(.body)
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3))
                    )
                    .disabled(isDisabled)

                Text("예: 로그인 화면에 소셜 로그인(Google, Apple) 기능을 추가해주세요")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // 담당자 선택
            VStack(alignment: .leading, spacing: 8) {
                Label("담당자", systemImage: "person.circle")
                    .font(.headline)

                Picker("담당자 선택", selection: $selectedEmployeeId) {
                    Text("지정하지 않음").tag(nil as UUID?)
                    ForEach(employees, id: \.id) { employee in
                        HStack {
                            Text(employee.name)
                            Text("(\(employee.departmentType.rawValue))")
                                .foregroundStyle(.secondary)
                        }
                        .tag(employee.id as UUID?)
                    }
                }
                .pickerStyle(.menu)
                .disabled(isDisabled)

                Text("파이프라인 실행 중 모르는 것이 있을 때 담당자에게 질문합니다")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Pipeline Progress

struct PipelineProgressView: View {
    let run: PipelineRun
    let progress: Double
    let currentPhaseDescription: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 상태 배너
            HStack {
                Image(systemName: run.state.icon)
                    .foregroundStyle(run.state.color)
                Text(run.state.rawValue)
                    .font(.headline)

                // 담당자 표시
                if let employeeName = run.assignedEmployeeName {
                    Divider()
                        .frame(height: 16)
                    Label(employeeName, systemImage: "person.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
                if let duration = run.duration {
                    Text(formatDuration(duration))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            // 진행률 바
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: progress)
                Text(currentPhaseDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // 단계별 상태
            HStack(spacing: 0) {
                ForEach(PipelinePhase.allCases, id: \.self) { phase in
                    PhaseIndicator(
                        phase: phase,
                        isActive: run.currentPhase == phase && run.state.isActive,
                        isCompleted: run.currentPhase.rawValue > phase.rawValue || run.state == .completed
                    )
                    if phase != PipelinePhase.allCases.last {
                        Rectangle()
                            .fill(run.currentPhase.rawValue > phase.rawValue ? phase.color : Color.secondary.opacity(0.3))
                            .frame(height: 2)
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct PhaseIndicator: View {
    let phase: PipelinePhase
    let isActive: Bool
    let isCompleted: Bool

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isCompleted ? phase.color : (isActive ? phase.color.opacity(0.3) : Color.secondary.opacity(0.2)))
                    .frame(width: 36, height: 36)

                if isActive {
                    ProgressView()
                        .scaleEffect(0.6)
                } else {
                    Image(systemName: isCompleted ? "checkmark" : phase.icon)
                        .font(.body)
                        .foregroundStyle(isCompleted ? .white : .secondary)
                }
            }
            Text(phase.name)
                .font(.caption2)
                .foregroundStyle(isActive || isCompleted ? .primary : .secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Decomposed Tasks

struct DecomposedTasksView: View {
    let tasks: [DecomposedTask]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("분해된 태스크 (\(tasks.count))", systemImage: "list.bullet")
                .font(.headline)

            ForEach(tasks) { task in
                DecomposedTaskRow(task: task)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct DecomposedTaskRow: View {
    let task: DecomposedTask

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: task.status.icon)
                .foregroundStyle(task.status.color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.body.weight(.medium))
                Text(task.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            HStack(spacing: 8) {
                Label(task.department.rawValue, systemImage: task.department.icon)
                    .font(.caption)
                    .foregroundStyle(task.department.color)

                if let duration = task.duration {
                    Text(String(format: "%.1fs", duration))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(NSColor.textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Build Result

struct BuildResultView: View {
    let attempt: BuildAttempt

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(
                    attempt.success ? "빌드 성공" : "빌드 실패",
                    systemImage: attempt.success ? "checkmark.circle.fill" : "xmark.circle.fill"
                )
                .font(.headline)
                .foregroundStyle(attempt.success ? .green : .red)

                Spacer()

                Text(String(format: "%.1fs", attempt.duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if !attempt.errors.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("에러 목록")
                        .font(.subheadline.weight(.medium))

                    ForEach(attempt.errors.prefix(10)) { error in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: error.severity.icon)
                                .foregroundStyle(error.severity.color)
                                .frame(width: 16)

                            VStack(alignment: .leading, spacing: 2) {
                                if !error.location.isEmpty {
                                    Text(error.location)
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                                Text(error.message)
                                    .font(.caption)
                            }
                        }
                    }

                    if attempt.errors.count > 10 {
                        Text("...외 \(attempt.errors.count - 10)개")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(attempt.success ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Pipeline Logs

struct PipelineLogView: View {
    let logs: [PipelineLogEntry]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("파이프라인 로그")
                    .font(.headline)
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
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(logs) { log in
                        HStack(alignment: .top, spacing: 8) {
                            Text(log.timestamp, style: .time)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 70, alignment: .leading)

                            Image(systemName: log.level.icon)
                                .font(.caption)
                                .foregroundStyle(log.level.color)
                                .frame(width: 16)

                            Text(log.message)
                                .font(.caption)
                                .foregroundStyle(log.level.color)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 2)
                    }
                }
                .padding(.vertical)
            }
            .background(Color(NSColor.textBackgroundColor))
        }
        .frame(width: 600, height: 400)
    }
}

// MARK: - Pipeline TODO Panel (Claude Code 스타일)

struct PipelineTodoPanel: View {
    let todoItems: [PipelineTodoItem]
    let currentAction: String
    let currentTaskIndex: Int
    let currentTaskName: String
    let logs: [PipelineLogEntry]

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Image(systemName: "checklist")
                Text("진행 상황")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(.ultraThinMaterial)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 현재 작업 (Claude Code 스타일)
                    if !currentAction.isEmpty {
                        CurrentActionView(action: currentAction)
                    }

                    // TODO 리스트
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(todoItems) { item in
                            TodoItemRow(item: item)
                        }
                    }

                    // 현재 태스크 (개발 단계일 때)
                    if currentTaskIndex > 0 && !currentTaskName.isEmpty {
                        CurrentTaskInfoView(
                            index: currentTaskIndex,
                            name: currentTaskName
                        )
                    }

                    Divider()

                    // 최근 로그 (실시간)
                    RecentLogsView(logs: logs)
                }
                .padding()
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

/// 현재 작업 표시 (Claude Code 스타일)
struct CurrentActionView: View {
    let action: String

    var body: some View {
        HStack(spacing: 8) {
            if action.hasPrefix("✓") || action.hasPrefix("✗") {
                // 완료/실패 아이콘
                Text(action)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(action.hasPrefix("✓") ? .green : .red)
            } else {
                // 진행 중 스피너
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 16, height: 16)

                Text(action)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.blue)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// TODO 아이템 행
struct TodoItemRow: View {
    let item: PipelineTodoItem

    var body: some View {
        HStack(spacing: 12) {
            // 상태 아이콘
            Group {
                if item.status == .inProgress {
                    ProgressView()
                        .scaleEffect(0.6)
                } else {
                    Image(systemName: item.status.icon)
                        .foregroundStyle(item.status.color)
                }
            }
            .frame(width: 20, height: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(item.status == .completed ? .secondary : .primary)
                    .strikethrough(item.status == .completed)

                Text(item.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Phase 번호
            Text("\(item.phase.rawValue)")
                .font(.caption.bold())
                .foregroundStyle(item.phase.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(item.phase.color.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
}

/// 현재 태스크 정보
struct CurrentTaskInfoView: View {
    let index: Int
    let name: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("현재 태스크", systemImage: "chevron.left.forwardslash.chevron.right")
                .font(.subheadline.weight(.semibold))

            HStack {
                Text("#\(index)")
                    .font(.caption.monospacedDigit())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .clipShape(Capsule())

                Text(name)
                    .font(.body)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// 최근 로그 뷰
struct RecentLogsView: View {
    let logs: [PipelineLogEntry]

    var recentLogs: [PipelineLogEntry] {
        Array(logs.suffix(10).reversed())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("최근 로그", systemImage: "list.bullet.rectangle")
                .font(.subheadline.weight(.semibold))

            if recentLogs.isEmpty {
                Text("로그가 없습니다")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(recentLogs) { log in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: log.level.icon)
                                .font(.caption2)
                                .foregroundStyle(log.level.color)
                                .frame(width: 12)

                            Text(log.message)
                                .font(.caption)
                                .foregroundStyle(log.level.color)
                                .lineLimit(2)
                        }
                    }
                }
                .padding(8)
                .background(Color(NSColor.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }
}

// MARK: - Notification Banner

/// 파이프라인 알림 배너
struct PipelineNotificationBanner: View {
    let message: String
    let type: PipelineCoordinator.NotificationType
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .font(.title3)
                .foregroundStyle(type.color)

            Text(message)
                .font(.subheadline.weight(.medium))

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(type.color.opacity(0.15))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(type.color.opacity(0.3), lineWidth: 1)
                }
        }
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        .padding(.horizontal, 20)
    }
}

// MARK: - 활동 현황 뷰

struct PipelineActivityView: View {
    let projectEmployees: [ProjectEmployee]
    let companyStore: CompanyStore
    let onSelectEmployee: (ProjectEmployee) -> Void

    /// 현재 작업 중인 직원들
    var workingEmployees: [ProjectEmployee] {
        projectEmployees.filter { employee in
            companyStore.getEmployeeStatus(employee.id) == .working ||
            companyStore.getEmployeeStatus(employee.id) == .thinking
        }
    }

    /// 대기 중인 직원들
    var idleEmployees: [ProjectEmployee] {
        projectEmployees.filter { employee in
            companyStore.getEmployeeStatus(employee.id) == .idle
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // 현재 작업 중인 직원들
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "person.wave.2.fill")
                            .foregroundStyle(.blue)
                        Text("현재 작업 중")
                            .font(.headline)
                        Text("(\(workingEmployees.count)명)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if workingEmployees.isEmpty {
                        HStack {
                            Image(systemName: "moon.zzz")
                                .foregroundStyle(.secondary)
                            Text("현재 작업 중인 직원이 없습니다")
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        ForEach(workingEmployees) { employee in
                            EmployeeActivityRow(
                                employee: employee,
                                status: companyStore.getEmployeeStatus(employee.id),
                                statistics: companyStore.getEmployeeStatistics(employee.id),
                                onSelect: { onSelectEmployee(employee) }
                            )
                        }
                    }
                }

                Divider()

                // 대기 중인 직원들
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "person.3.fill")
                            .foregroundStyle(.secondary)
                        Text("대기 중")
                            .font(.headline)
                        Text("(\(idleEmployees.count)명)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if idleEmployees.isEmpty {
                        Text("모든 직원이 작업 중입니다")
                            .foregroundStyle(.secondary)
                            .padding()
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 8) {
                            ForEach(idleEmployees) { employee in
                                IdleEmployeeCard(
                                    employee: employee,
                                    onSelect: { onSelectEmployee(employee) }
                                )
                            }
                        }
                    }
                }

                // 토큰 사용량 요약
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "chart.bar.fill")
                            .foregroundStyle(.green)
                        Text("오늘의 토큰 사용량")
                            .font(.headline)
                    }

                    TokenUsageSummaryCard(employees: projectEmployees, companyStore: companyStore)
                }
            }
            .padding()
        }
    }
}

/// 작업 중인 직원 행
struct EmployeeActivityRow: View {
    let employee: ProjectEmployee
    let status: EmployeeStatus
    let statistics: EmployeeStatistics?
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // 상태 표시
                Circle()
                    .fill(status.color)
                    .frame(width: 10, height: 10)
                    .overlay {
                        if status == .working || status == .thinking {
                            Circle()
                                .stroke(status.color, lineWidth: 2)
                                .scaleEffect(1.5)
                                .opacity(0.5)
                        }
                    }

                // 직원 정보
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(employee.name)
                            .font(.headline)
                        Text("(\(employee.departmentType.rawValue))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 8) {
                        Label(status.rawValue, systemImage: status.icon)
                            .font(.caption)
                            .foregroundStyle(status.color)

                        if let stats = statistics {
                            Text("•")
                                .foregroundStyle(.secondary)
                            Text("\(stats.totalTokensUsed.formatted()) 토큰")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                // 실시간 토큰 사용량 (작업 중일 때)
                if status == .working || status == .thinking {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("처리중...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(status.color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/// 대기 중인 직원 카드
struct IdleEmployeeCard: View {
    let employee: ProjectEmployee
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Text(employee.name)
                    .font(.subheadline)
                Text("(\(employee.departmentType.rawValue))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

/// 토큰 사용량 요약 카드
struct TokenUsageSummaryCard: View {
    let employees: [ProjectEmployee]
    let companyStore: CompanyStore

    var todaysTotalTokens: Int {
        employees.reduce(0) { total, employee in
            total + (companyStore.getEmployeeStatistics(employee.id)?.tokensLast24Hours ?? 0)
        }
    }

    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("오늘 총 사용")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(todaysTotalTokens.formatted())")
                    .font(.title2.bold())
                Text("토큰")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()
                .frame(height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text("활성 직원")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(employees.count)")
                    .font(.title2.bold())
                Text("명")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - 칸반 태스크 선택 시트

struct KanbanTaskPickerSheet: View {
    let tasks: [ProjectTask]
    @Binding var selectedTaskIds: Set<UUID>
    let onConfirm: ([ProjectTask]) -> Void
    @Environment(\.dismiss) private var dismiss

    /// 처리 가능한 태스크 (완료되지 않은 태스크)
    var availableTasks: [ProjectTask] {
        tasks.filter { $0.status != .done }
    }

    /// 선택된 태스크들
    var selectedTasks: [ProjectTask] {
        tasks.filter { selectedTaskIds.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("칸반에서 태스크 가져오기")
                        .font(.title2.bold())
                    Text("파이프라인으로 처리할 태스크를 선택하세요")
                        .font(.body)
                        .foregroundStyle(.secondary)
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

            // 태스크 목록
            if availableTasks.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "tray")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("처리할 태스크가 없습니다")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("칸반 보드에 태스크를 추가해주세요")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(availableTasks) { task in
                            KanbanTaskRow(
                                task: task,
                                isSelected: selectedTaskIds.contains(task.id),
                                onToggle: {
                                    if selectedTaskIds.contains(task.id) {
                                        selectedTaskIds.remove(task.id)
                                    } else {
                                        selectedTaskIds.insert(task.id)
                                    }
                                }
                            )
                        }
                    }
                    .padding()
                }
            }

            Divider()

            // 하단 버튼
            HStack {
                Text("\(selectedTasks.count)개 선택됨")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("취소") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button {
                    onConfirm(selectedTasks)
                    dismiss()
                } label: {
                    Label("파이프라인 시작", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedTasks.isEmpty)
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 500)
    }
}

/// 칸반 태스크 선택 행
struct KanbanTaskRow: View {
    let task: ProjectTask
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // 선택 체크박스
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .font(.title3)

                // 태스크 정보
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(task.title)
                            .font(.headline)
                            .lineLimit(1)

                        Spacer()

                        // 우선순위
                        Label(task.priority.rawValue, systemImage: task.priority.icon)
                            .font(.caption)
                            .foregroundStyle(task.priority.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(task.priority.color.opacity(0.1))
                            .clipShape(Capsule())
                    }

                    HStack(spacing: 8) {
                        // 부서
                        Label(task.departmentType.rawValue, systemImage: "building.2")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        // 상태
                        Label(task.status.rawValue, systemImage: task.status.icon)
                            .font(.caption)
                            .foregroundStyle(task.status.color)
                    }

                    if !task.description.isEmpty {
                        Text(task.description)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(2)
                    }
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    PipelineView(projectId: UUID())
        .environmentObject(CompanyStore())
}
