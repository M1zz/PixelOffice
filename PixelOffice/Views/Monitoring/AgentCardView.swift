import SwiftUI

/// 개별 agent 카드 뷰
struct AgentCardView: View {
    let agent: SubAgent
    let isSelected: Bool
    let onSelect: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    
    @State private var isHovering: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 헤더
            HStack {
                // 상태 인디케이터
                Circle()
                    .fill(agent.status.color)
                    .frame(width: 10, height: 10)
                    .overlay {
                        if agent.status == .running {
                            Circle()
                                .stroke(agent.status.color.opacity(0.5), lineWidth: 2)
                                .scaleEffect(1.5)
                                .opacity(isHovering ? 0 : 1)
                                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: agent.status)
                        }
                    }
                
                // 이름
                Text(agent.name)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                // 태스크 유형 아이콘
                Image(systemName: agent.task.type.icon)
                    .foregroundColor(agent.task.type.color)
                    .font(.caption)
            }
            
            // 태스크 제목
            Text(agent.task.title)
                .font(.subheadline)
                .foregroundColor(.primary)
                .lineLimit(2)
            
            // 진행률 바
            if agent.status == .running || agent.progress > 0 {
                ProgressView(value: agent.progress)
                    .progressViewStyle(.linear)
                    .tint(agent.status.color)
            }
            
            // 현재 작업 (실행 중일 때)
            if agent.status == .running && !agent.currentAction.isEmpty {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.6)
                    
                    Text(agent.currentAction)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            // 하단 정보
            HStack {
                // 담당자
                if let assignee = agent.assignedEmployeeName {
                    Label(assignee, systemImage: "person.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 소요 시간
                if let duration = agent.duration {
                    Text(formatDuration(duration))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                // 제어 버튼 (호버 시)
                if isHovering {
                    HStack(spacing: 4) {
                        if agent.status == .running {
                            Button(action: onPause) {
                                Image(systemName: "pause.fill")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.orange)
                        } else if agent.status == .paused {
                            Button(action: onResume) {
                                Image(systemName: "play.fill")
                                    .font(.caption)
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.green)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            onSelect()
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .animation(.easeInOut(duration: 0.2), value: isHovering)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let seconds = Int(duration)
        if seconds < 60 {
            return "\(seconds)초"
        } else {
            return "\(seconds / 60)분"
        }
    }
}

// MARK: - Compact Agent Card

/// 컴팩트한 agent 카드 (목록용)
struct CompactAgentCardView: View {
    let agent: SubAgent
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        HStack(spacing: 10) {
            // 상태 인디케이터
            ZStack {
                Circle()
                    .fill(agent.status.color.opacity(0.2))
                    .frame(width: 32, height: 32)
                
                Image(systemName: agent.status.icon)
                    .foregroundColor(agent.status.color)
                    .font(.system(size: 14))
            }
            
            // 정보
            VStack(alignment: .leading, spacing: 2) {
                Text(agent.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(agent.task.title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 진행률
            if agent.status == .running {
                Text("\(Int(agent.progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .onTapGesture {
            onSelect()
        }
    }
}

// MARK: - Agent Status Badge

/// Agent 상태 배지
struct AgentStatusBadge: View {
    let status: SubAgentStatus
    let size: BadgeSize
    
    enum BadgeSize {
        case small, medium, large
        
        var font: Font {
            switch self {
            case .small: return .caption2
            case .medium: return .caption
            case .large: return .subheadline
            }
        }
        
        var padding: EdgeInsets {
            switch self {
            case .small: return EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6)
            case .medium: return EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
            case .large: return EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
            }
        }
        
        var iconSize: CGFloat {
            switch self {
            case .small: return 8
            case .medium: return 10
            case .large: return 12
            }
        }
    }
    
    init(_ status: SubAgentStatus, size: BadgeSize = .medium) {
        self.status = status
        self.size = size
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(status.color)
                .frame(width: size.iconSize, height: size.iconSize)
            
            Text(status.rawValue)
                .font(size.font)
        }
        .padding(size.padding)
        .background(status.color.opacity(0.15))
        .foregroundColor(status.color)
        .cornerRadius(size == .small ? 4 : 6)
    }
}

// MARK: - Preview

#Preview("Agent Card") {
    VStack(spacing: 16) {
        AgentCardView(
            agent: SubAgent(
                name: "Agent-1",
                task: SubAgentTask(
                    title: "메인 화면 UI 구현",
                    description: "메인 화면 레이아웃과 컴포넌트를 구현합니다.",
                    type: .codeGeneration
                ),
                status: .running,
                assignedEmployeeName: "김개발",
                progress: 0.6,
                currentAction: "SwiftUI 뷰 생성 중..."
            ),
            isSelected: false,
            onSelect: {},
            onPause: {},
            onResume: {}
        )
        
        AgentCardView(
            agent: SubAgent(
                name: "Agent-2",
                task: SubAgentTask(
                    title: "API 연동",
                    description: "서버 API와 연동합니다.",
                    type: .codeGeneration
                ),
                status: .completed,
                progress: 1.0
            ),
            isSelected: true,
            onSelect: {},
            onPause: {},
            onResume: {}
        )
        
        AgentCardView(
            agent: SubAgent(
                name: "Agent-3",
                task: SubAgentTask(
                    title: "테스트 작성",
                    description: "단위 테스트를 작성합니다.",
                    type: .testing
                ),
                status: .failed,
                error: "빌드 에러 발생"
            ),
            isSelected: false,
            onSelect: {},
            onPause: {},
            onResume: {}
        )
    }
    .padding()
    .frame(width: 320)
}
