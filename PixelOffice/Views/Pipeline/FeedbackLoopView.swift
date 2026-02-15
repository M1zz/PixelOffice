import SwiftUI

/// 피드백 입력 → 다음 스프린트 자동 생성
struct FeedbackLoopView: View {
    let projectId: UUID
    let projectName: String
    let lastRun: PipelineRun?
    
    @EnvironmentObject var companyStore: CompanyStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var feedbackText: String = ""
    @State private var feedbackType: FeedbackType = .improvement
    @State private var priority: TaskPriority = .medium
    @State private var isGenerating: Bool = false
    @State private var generatedTasks: [DecomposedTask] = []
    @State private var showingConfirmation: Bool = false
    @State private var errorMessage: String?
    
    /// 피드백 유형
    enum FeedbackType: String, CaseIterable {
        case bug = "🐛 버그 수정"
        case improvement = "✨ 개선"
        case feature = "🚀 새 기능"
        case design = "🎨 디자인 변경"
        case performance = "⚡ 성능 개선"
        
        var prompt: String {
            switch self {
            case .bug: return "다음 버그를 수정해주세요:"
            case .improvement: return "다음 부분을 개선해주세요:"
            case .feature: return "다음 기능을 추가해주세요:"
            case .design: return "다음과 같이 디자인을 변경해주세요:"
            case .performance: return "다음 성능 문제를 해결해주세요:"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            header
            
            Divider()
            
            // 메인 콘텐츠
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 이전 실행 정보
                    if let lastRun = lastRun {
                        previousRunInfo(lastRun)
                    }
                    
                    // 피드백 입력
                    feedbackInput
                    
                    // 생성된 태스크 미리보기
                    if !generatedTasks.isEmpty {
                        generatedTasksPreview
                    }
                    
                    // 에러 메시지
                    if let error = errorMessage {
                        errorView(error)
                    }
                }
                .padding(24)
            }
            
            Divider()
            
            // 하단 버튼
            bottomButtons
        }
        .frame(width: 700, height: 600)
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("💬 피드백 → 다음 스프린트")
                    .font(.title2.bold())
                Text(projectName)
                    .font(.subheadline)
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
    }
    
    // MARK: - Previous Run Info
    
    private func previousRunInfo(_ run: PipelineRun) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: run.isBuildSuccessful ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(run.isBuildSuccessful ? .green : .red)
                    Text("이전 실행: \(run.requirement.prefix(50))...")
                        .lineLimit(1)
                    Spacer()
                    if let completedAt = run.completedAt {
                        Text(completedAt, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // 완료된 태스크 요약
                let completedCount = run.decomposedTasks.filter { $0.status == .completed }.count
                let totalCount = run.decomposedTasks.count
                Text("완료: \(completedCount)/\(totalCount) 태스크")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } label: {
            Label("이전 실행", systemImage: "clock.arrow.circlepath")
                .font(.headline)
        }
    }
    
    // MARK: - Feedback Input
    
    private var feedbackInput: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("피드백 입력")
                .font(.headline)
            
            // 피드백 유형 선택
            HStack {
                Text("유형:")
                    .foregroundStyle(.secondary)
                
                Picker("", selection: $feedbackType) {
                    ForEach(FeedbackType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            
            // 우선순위 선택
            HStack {
                Text("우선순위:")
                    .foregroundStyle(.secondary)
                
                Picker("", selection: $priority) {
                    Text("🔴 높음").tag(TaskPriority.high)
                    Text("🟡 보통").tag(TaskPriority.medium)
                    Text("🟢 낮음").tag(TaskPriority.low)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            
            // 피드백 텍스트
            VStack(alignment: .leading, spacing: 8) {
                Text(feedbackType.prompt)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                TextEditor(text: $feedbackText)
                    .font(.body)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
            }
            
            // 예시 피드백
            exampleFeedbacks
        }
    }
    
    // MARK: - Example Feedbacks
    
    private var exampleFeedbacks: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("예시 (클릭하여 사용)")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(examplesForType, id: \.self) { example in
                        Button {
                            feedbackText = example
                        } label: {
                            Text(example)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    private var examplesForType: [String] {
        switch feedbackType {
        case .bug:
            return [
                "앱이 종료될 때 데이터가 저장되지 않음",
                "다크모드에서 텍스트가 안 보임",
                "검색 결과가 정확하지 않음"
            ]
        case .improvement:
            return [
                "목록 정렬 기능 추가",
                "로딩 속도 개선",
                "에러 메시지를 더 친절하게"
            ]
        case .feature:
            return [
                "통계 대시보드 추가",
                "마크다운 내보내기",
                "알림 기능 추가"
            ]
        case .design:
            return [
                "버튼 색상을 파란색으로 변경",
                "폰트 크기 키우기",
                "여백 조정"
            ]
        case .performance:
            return [
                "앱 시작 속도 개선",
                "스크롤 버벅임 해결",
                "메모리 사용량 줄이기"
            ]
        }
    }
    
    // MARK: - Generated Tasks Preview
    
    private var generatedTasksPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("생성된 태스크 (\(generatedTasks.count)개)")
                    .font(.headline)
                
                Spacer()
                
                Button("다시 생성") {
                    Task { await generateTasks() }
                }
                .buttonStyle(.bordered)
            }
            
            ForEach(generatedTasks) { task in
                HStack {
                    Image(systemName: task.department.icon)
                        .foregroundStyle(task.department.color)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.title)
                            .font(.subheadline.bold())
                        Text(task.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    Text(task.department.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(task.department.color.opacity(0.1))
                        .clipShape(Capsule())
                }
                .padding(12)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    
    // MARK: - Error View
    
    private func errorView(_ error: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(error)
                .font(.subheadline)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Bottom Buttons
    
    private var bottomButtons: some View {
        HStack {
            Button("취소") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            
            Spacer()
            
            if generatedTasks.isEmpty {
                // 태스크 생성
                Button {
                    Task { await generateTasks() }
                } label: {
                    HStack {
                        if isGenerating {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                        Text(isGenerating ? "분석 중..." : "태스크 생성")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)
            } else {
                // 스프린트 시작
                Button {
                    showingConfirmation = true
                } label: {
                    Label("스프린트 시작", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .padding()
        .alert("스프린트 시작", isPresented: $showingConfirmation) {
            Button("취소", role: .cancel) { }
            Button("시작") {
                startSprint()
            }
        } message: {
            Text("\(generatedTasks.count)개 태스크로 새 스프린트를 시작하시겠습니까?")
        }
    }
    
    // MARK: - Actions
    
    private func generateTasks() async {
        guard !feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isGenerating = true
        errorMessage = nil
        
        let fullRequirement = "\(feedbackType.prompt)\n\n\(feedbackText)"
        
        do {
            let decomposer = RequirementDecomposer()
            let result = try await decomposer.decompose(
                requirement: fullRequirement,
                projectInfo: nil,
                projectContext: "",
                autoApprove: true
            )
            
            // 우선순위 적용
            generatedTasks = result.tasks.map { task in
                var modifiedTask = task
                modifiedTask.priority = priority
                return modifiedTask
            }
            
            if generatedTasks.isEmpty {
                errorMessage = "태스크를 생성하지 못했습니다. 피드백을 더 구체적으로 작성해주세요."
            }
        } catch {
            errorMessage = "오류: \(error.localizedDescription)"
        }
        
        isGenerating = false
    }
    
    private func startSprint() {
        // 칸반에 태스크 추가 및 파이프라인 시작
        guard let project = companyStore.company.projects.first(where: { $0.id == projectId }) else {
            return
        }
        
        // 새 스프린트 생성
        let sprintName = "피드백 스프린트 - \(Date().formatted(date: .abbreviated, time: .shortened))"
        let sprint = Sprint(name: sprintName, startDate: Date())
        
        // 프로젝트에 스프린트 추가
        companyStore.addSprint(sprint, toProject: projectId)
        
        // 태스크를 ProjectTask로 변환하여 추가
        for task in generatedTasks {
            let projectTask = ProjectTask(
                title: task.title,
                description: task.description,
                status: .todo,
                priority: task.priority,
                departmentType: task.department,
                sprintId: sprint.id
            )
            companyStore.addTask(projectTask, toProject: projectId)
        }
        
        // 파이프라인 시작 알림 발송
        NotificationCenter.default.post(
            name: .startPipelineWithSprint,
            object: nil,
            userInfo: [
                "projectId": projectId,
                "sprintId": sprint.id,
                "requirement": feedbackText
            ]
        )
        
        dismiss()
    }
}

// MARK: - Notification

extension Notification.Name {
    static let startPipelineWithSprint = Notification.Name("startPipelineWithSprint")
}

// MARK: - Preview

#Preview {
    FeedbackLoopView(
        projectId: UUID(),
        projectName: "테스트 프로젝트",
        lastRun: nil
    )
    .environmentObject(CompanyStore())
}
