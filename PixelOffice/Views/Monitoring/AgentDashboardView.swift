import SwiftUI

/// Agent 모니터링 메인 대시보드
struct AgentDashboardView: View {
    @ObservedObject var coordinator: SubAgentCoordinator
    @State private var selectedAgentId: UUID?
    @State private var showLogStream: Bool = false
    @State private var showTaskGraph: Bool = false
    @State private var logFilter: LogFilterOption = .all
    
    enum LogFilterOption: String, CaseIterable {
        case all = "전체"
        case error = "에러만"
        case info = "정보"
        case success = "성공"
        
        var levels: [SubAgentLogLevel] {
            switch self {
            case .all: return SubAgentLogLevel.allCases
            case .error: return [.error, .warning]
            case .info: return [.info, .debug]
            case .success: return [.success]
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            headerView
            
            Divider()
            
            // 메인 콘텐츠
            HStack(spacing: 0) {
                // 왼쪽: Agent 목록
                agentListView
                    .frame(width: 320)
                
                Divider()
                
                // 오른쪽: 상세 정보 또는 그래프
                if showTaskGraph {
                    TaskGraphView(agents: coordinator.subAgents)
                } else if showLogStream {
                    LogStreamView(
                        logs: filteredLogs,
                        filter: $logFilter,
                        selectedAgentId: $selectedAgentId
                    )
                } else if let selectedId = selectedAgentId,
                          let agent = coordinator.subAgents.first(where: { $0.id == selectedId }) {
                    AgentDetailView(agent: agent, coordinator: coordinator)
                } else {
                    // 기본: 요약 뷰
                    summaryView
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack(spacing: 16) {
            // 상태 인디케이터
            HStack(spacing: 8) {
                Circle()
                    .fill(coordinator.isRunning ? Color.blue : Color.secondary)
                    .frame(width: 12, height: 12)
                
                Text(coordinator.isRunning ? "실행 중" : "대기 중")
                    .font(.headline)
            }
            
            Spacer()
            
            // 진행률
            if coordinator.isRunning {
                ProgressView(value: coordinator.progress)
                    .frame(width: 200)
                
                Text("\(Int(coordinator.progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .trailing)
            }
            
            // 토큰 사용량
            tokenUsageView
            
            Spacer()
            
            // 뷰 전환 버튼
            HStack(spacing: 8) {
                Button(action: { showTaskGraph = false; showLogStream = false; selectedAgentId = nil }) {
                    Label("요약", systemImage: "chart.pie")
                }
                .buttonStyle(.bordered)
                .tint((!showTaskGraph && !showLogStream && selectedAgentId == nil) ? .blue : nil)
                
                Button(action: { showLogStream.toggle(); showTaskGraph = false }) {
                    Label("로그", systemImage: "terminal")
                }
                .buttonStyle(.bordered)
                .tint(showLogStream ? .blue : nil)
                
                Button(action: { showTaskGraph.toggle(); showLogStream = false }) {
                    Label("그래프", systemImage: "point.3.connected.trianglepath.dotted")
                }
                .buttonStyle(.bordered)
                .tint(showTaskGraph ? .blue : nil)
            }
            
            // 제어 버튼
            if coordinator.isRunning {
                Button(action: { coordinator.cancel() }) {
                    Label("중지", systemImage: "stop.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .padding()
    }
    
    // MARK: - Token Usage
    
    private var tokenUsageView: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("토큰")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(formatNumber(coordinator.totalInputTokens + coordinator.totalOutputTokens))
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("비용")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("$\(String(format: "%.4f", coordinator.totalCostUSD))")
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
    
    // MARK: - Agent List
    
    private var agentListView: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text("Sub-Agents")
                    .font(.headline)
                
                Spacer()
                
                Text("\(coordinator.subAgents.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(4)
            }
            .padding()
            
            Divider()
            
            // 상태 요약
            statusSummaryView
                .padding(.horizontal)
                .padding(.vertical, 8)
            
            Divider()
            
            // Agent 목록
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(coordinator.subAgents) { agent in
                        AgentCardView(
                            agent: agent,
                            isSelected: selectedAgentId == agent.id,
                            onSelect: {
                                selectedAgentId = agent.id
                                showLogStream = false
                                showTaskGraph = false
                            },
                            onPause: {
                                coordinator.pauseAgent(agent.id)
                            },
                            onResume: {
                                coordinator.resumeAgent(agent.id, projectInfo: nil)
                            }
                        )
                    }
                }
                .padding()
            }
        }
    }
    
    // MARK: - Status Summary
    
    private var statusSummaryView: some View {
        HStack(spacing: 16) {
            statusBadge(count: runningCount, label: "실행 중", color: .blue)
            statusBadge(count: completedCount, label: "완료", color: .green)
            statusBadge(count: failedCount, label: "실패", color: .red)
            statusBadge(count: pendingCount, label: "대기", color: .secondary)
        }
    }
    
    private func statusBadge(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Summary View
    
    private var summaryView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 전체 진행률
                overallProgressView
                
                // 현재 작업
                if coordinator.isRunning {
                    currentActionView
                }
                
                // 최근 로그
                recentLogsView
            }
            .padding()
        }
    }
    
    private var overallProgressView: some View {
        VStack(spacing: 16) {
            Text("전체 진행 현황")
                .font(.headline)
            
            // 원형 진행률
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 20)
                
                Circle()
                    .trim(from: 0, to: coordinator.progress)
                    .stroke(
                        coordinator.isRunning ? Color.blue : Color.green,
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: coordinator.progress)
                
                VStack {
                    Text("\(Int(coordinator.progress * 100))%")
                        .font(.system(size: 36, weight: .bold))
                    
                    Text("완료")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 150, height: 150)
            
            // 통계
            HStack(spacing: 40) {
                VStack {
                    Text("\(completedCount)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("성공")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(failedCount)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                    Text("실패")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text(formatNumber(coordinator.totalInputTokens + coordinator.totalOutputTokens))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("토큰")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var currentActionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("현재 작업")
                .font(.headline)
            
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                
                Text(coordinator.currentAction)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
    
    private var recentLogsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("최근 로그")
                    .font(.headline)
                
                Spacer()
                
                Button("전체 보기") {
                    showLogStream = true
                }
                .font(.caption)
            }
            
            VStack(spacing: 4) {
                ForEach(coordinator.logs.suffix(5).reversed()) { log in
                    HStack(spacing: 8) {
                        Image(systemName: log.level.icon)
                            .foregroundColor(log.level.color)
                            .frame(width: 16)
                        
                        Text(log.message)
                            .font(.caption)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(formatTime(log.timestamp))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
    
    // MARK: - Computed Properties
    
    private var runningCount: Int {
        coordinator.subAgents.filter { $0.status == .running }.count
    }
    
    private var completedCount: Int {
        coordinator.subAgents.filter { $0.status == .completed }.count
    }
    
    private var failedCount: Int {
        coordinator.subAgents.filter { $0.status == .failed }.count
    }
    
    private var pendingCount: Int {
        coordinator.subAgents.filter { $0.status == .idle || $0.status == .paused }.count
    }
    
    private var filteredLogs: [SubAgentLog] {
        coordinator.logs.filter { logFilter.levels.contains($0.level) }
    }
    
    // MARK: - Helpers
    
    private func formatNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

// MARK: - Agent Detail View

struct AgentDetailView: View {
    let agent: SubAgent
    @ObservedObject var coordinator: SubAgentCoordinator
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 헤더
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(agent.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(agent.task.title)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // 상태 배지
                    HStack(spacing: 4) {
                        Image(systemName: agent.status.icon)
                        Text(agent.status.rawValue)
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(agent.status.color.opacity(0.2))
                    .foregroundColor(agent.status.color)
                    .cornerRadius(8)
                }
                
                Divider()
                
                // 태스크 정보
                GroupBox("태스크 정보") {
                    VStack(alignment: .leading, spacing: 8) {
                        detailRow("유형", value: agent.task.type.rawValue)
                        detailRow("우선순위", value: agent.task.priority.rawValue)
                        
                        if let assignee = agent.assignedEmployeeName {
                            detailRow("담당자", value: assignee)
                        }
                        
                        if !agent.task.skillIds.isEmpty {
                            detailRow("스킬", value: agent.task.skillIds.joined(separator: ", "))
                        }
                        
                        Text("설명")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(agent.task.description)
                            .font(.body)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // 진행률
                GroupBox("진행 상황") {
                    VStack(alignment: .leading, spacing: 8) {
                        ProgressView(value: agent.progress)
                        
                        HStack {
                            Text("\(Int(agent.progress * 100))% 완료")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            if let duration = agent.duration {
                                Text("소요시간: \(formatDuration(duration))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if !agent.currentAction.isEmpty {
                            Text(agent.currentAction)
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                // 토큰 사용량
                GroupBox("토큰 사용량") {
                    HStack(spacing: 20) {
                        VStack {
                            Text("\(agent.inputTokens)")
                                .font(.title3)
                                .fontWeight(.medium)
                            Text("입력")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack {
                            Text("\(agent.outputTokens)")
                                .font(.title3)
                                .fontWeight(.medium)
                            Text("출력")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack {
                            Text("$\(String(format: "%.4f", agent.costUSD))")
                                .font(.title3)
                                .fontWeight(.medium)
                            Text("비용")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                
                // 결과 (완료된 경우)
                if let result = agent.result {
                    GroupBox("결과") {
                        VStack(alignment: .leading, spacing: 8) {
                            if let summary = result.summary {
                                Text(summary)
                                    .font(.subheadline)
                            }
                            
                            if !result.createdFiles.isEmpty {
                                Text("생성된 파일:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                ForEach(result.createdFiles, id: \.self) { file in
                                    Text("• \(file)")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                            
                            if !result.modifiedFiles.isEmpty {
                                Text("수정된 파일:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                ForEach(result.modifiedFiles, id: \.self) { file in
                                    Text("• \(file)")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                // 에러 (실패한 경우)
                if let error = agent.error {
                    GroupBox("에러") {
                        Text(error)
                            .font(.body)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                Spacer()
            }
            .padding()
        }
    }
    
    private func detailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            
            Text(value)
                .font(.body)
        }
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

// MARK: - Extension for allCases

extension SubAgentLogLevel: CaseIterable {
    static var allCases: [SubAgentLogLevel] {
        [.debug, .info, .success, .warning, .error]
    }
}

#Preview {
    AgentDashboardView(coordinator: SubAgentCoordinator())
        .frame(width: 1000, height: 700)
}
