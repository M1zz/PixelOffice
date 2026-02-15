import SwiftUI

/// 터미널 스타일 로그 스트림 뷰
struct LogStreamView: View {
    let logs: [SubAgentLog]
    @Binding var filter: AgentDashboardView.LogFilterOption
    @Binding var selectedAgentId: UUID?
    
    @State private var autoScroll: Bool = true
    @State private var searchText: String = ""
    @State private var showOnlyErrors: Bool = false
    @State private var fontSize: CGFloat = 12
    
    private var filteredLogs: [SubAgentLog] {
        var result = logs
        
        // 검색 필터
        if !searchText.isEmpty {
            result = result.filter { $0.message.localizedCaseInsensitiveContains(searchText) }
        }
        
        return result
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 툴바
            toolbarView
            
            Divider()
            
            // 로그 스트림
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(filteredLogs) { log in
                            LogEntryView(log: log, fontSize: fontSize)
                                .id(log.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color(nsColor: .textBackgroundColor).opacity(0.95))
                .onChange(of: logs.count) { _, newCount in
                    if autoScroll, let lastLog = logs.last {
                        withAnimation {
                            proxy.scrollTo(lastLog.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // 상태 바
            statusBarView
        }
    }
    
    // MARK: - Toolbar
    
    private var toolbarView: some View {
        HStack(spacing: 12) {
            // 검색
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("검색...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
            .frame(maxWidth: 250)
            
            // 필터
            Picker("필터", selection: $filter) {
                ForEach(AgentDashboardView.LogFilterOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
            
            Spacer()
            
            // 폰트 크기
            HStack(spacing: 4) {
                Button(action: { fontSize = max(10, fontSize - 1) }) {
                    Image(systemName: "textformat.size.smaller")
                }
                .buttonStyle(.plain)
                
                Text("\(Int(fontSize))pt")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 30)
                
                Button(action: { fontSize = min(18, fontSize + 1) }) {
                    Image(systemName: "textformat.size.larger")
                }
                .buttonStyle(.plain)
            }
            
            Divider()
                .frame(height: 20)
            
            // 자동 스크롤
            Toggle(isOn: $autoScroll) {
                Label("자동 스크롤", systemImage: autoScroll ? "arrow.down.circle.fill" : "arrow.down.circle")
            }
            .toggleStyle(.button)
            .buttonStyle(.borderless)
            
            // 지우기
            Button(action: {}) {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Status Bar
    
    private var statusBarView: some View {
        HStack {
            // 로그 수
            Text("\(filteredLogs.count)개 로그")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if !searchText.isEmpty {
                Text("(필터링됨)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 마지막 업데이트 시간
            if let lastLog = logs.last {
                Text("마지막: \(formatTime(lastLog.timestamp))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
}

// MARK: - Log Entry View

struct LogEntryView: View {
    let log: SubAgentLog
    let fontSize: CGFloat
    
    @State private var isHovering: Bool = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // 타임스탬프
            Text(formatTime(log.timestamp))
                .font(.system(size: fontSize, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 90, alignment: .leading)
            
            // 레벨 아이콘
            Image(systemName: log.level.icon)
                .font(.system(size: fontSize))
                .foregroundColor(log.level.color)
                .frame(width: 16)
            
            // 메시지
            Text(log.message)
                .font(.system(size: fontSize, design: .monospaced))
                .foregroundColor(colorForLevel(log.level))
                .textSelection(.enabled)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovering ? Color(nsColor: .selectedTextBackgroundColor).opacity(0.3) : Color.clear)
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            Button("복사") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(log.message, forType: .string)
            }
            
            Button("전체 복사 (타임스탬프 포함)") {
                let fullText = "[\(formatTime(log.timestamp))] \(log.message)"
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(fullText, forType: .string)
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    private func colorForLevel(_ level: SubAgentLogLevel) -> Color {
        switch level {
        case .debug:
            return .secondary
        case .info:
            return .primary
        case .success:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}

// MARK: - Pipeline Log Stream

/// 파이프라인 로그 스트림 뷰 (기존 PipelineLogEntry 호환)
struct PipelineLogStreamView: View {
    let logs: [PipelineLogEntry]
    @State private var autoScroll: Bool = true
    @State private var searchText: String = ""
    @State private var fontSize: CGFloat = 12
    @State private var levelFilter: PipelineLogLevel?
    
    private var filteredLogs: [PipelineLogEntry] {
        var result = logs
        
        // 검색 필터
        if !searchText.isEmpty {
            result = result.filter { $0.message.localizedCaseInsensitiveContains(searchText) }
        }
        
        // 레벨 필터
        if let level = levelFilter {
            result = result.filter { $0.level == level }
        }
        
        return result
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 툴바
            HStack(spacing: 12) {
                // 검색
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("검색...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(6)
                .frame(maxWidth: 200)
                
                // 레벨 필터
                Menu {
                    Button("전체") { levelFilter = nil }
                    Divider()
                    ForEach([PipelineLogLevel.debug, .info, .success, .warning, .error], id: \.self) { level in
                        Button(level.rawValue) { levelFilter = level }
                    }
                } label: {
                    Label(levelFilter?.rawValue ?? "전체", systemImage: "line.3.horizontal.decrease.circle")
                }
                
                Spacer()
                
                // 자동 스크롤
                Toggle(isOn: $autoScroll) {
                    Image(systemName: autoScroll ? "arrow.down.circle.fill" : "arrow.down.circle")
                }
                .toggleStyle(.button)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            // 로그 스트림
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(filteredLogs) { log in
                            PipelineLogEntryView(log: log, fontSize: fontSize)
                                .id(log.id)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color(nsColor: .textBackgroundColor).opacity(0.95))
                .onChange(of: logs.count) { _, _ in
                    if autoScroll, let lastLog = logs.last {
                        withAnimation {
                            proxy.scrollTo(lastLog.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // 상태 바
            HStack {
                Text("\(filteredLogs.count)개 로그")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }
}

// MARK: - Pipeline Log Entry View

struct PipelineLogEntryView: View {
    let log: PipelineLogEntry
    let fontSize: CGFloat
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // 타임스탬프
            Text(formatTime(log.timestamp))
                .font(.system(size: fontSize, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .leading)
            
            // Phase 배지 (있는 경우)
            if let phase = log.phase {
                Text(phase.name)
                    .font(.system(size: fontSize - 2))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(phase.color.opacity(0.2))
                    .foregroundColor(phase.color)
                    .cornerRadius(3)
            }
            
            // 레벨 아이콘
            Image(systemName: log.level.icon)
                .font(.system(size: fontSize))
                .foregroundColor(log.level.color)
                .frame(width: 14)
            
            // 메시지
            Text(log.message)
                .font(.system(size: fontSize, design: .monospaced))
                .foregroundColor(log.level.color == .primary ? .primary : log.level.color)
                .textSelection(.enabled)
        }
        .padding(.vertical, 2)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview("Log Stream") {
    let sampleLogs = [
        SubAgentLog(message: "🎭 오케스트레이션 시작", level: .info),
        SubAgentLog(message: "📋 요구사항 분석 중...", level: .debug),
        SubAgentLog(message: "✅ 3개 태스크로 분해 완료", level: .success),
        SubAgentLog(message: "⚠️ 메모리 사용량이 높습니다", level: .warning),
        SubAgentLog(message: "❌ 빌드 실패: 컴파일 에러", level: .error)
    ]
    
    LogStreamView(
        logs: sampleLogs,
        filter: .constant(.all),
        selectedAgentId: .constant(nil)
    )
    .frame(width: 800, height: 400)
}
