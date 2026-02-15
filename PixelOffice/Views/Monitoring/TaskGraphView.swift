import SwiftUI

/// 태스크 의존성 그래프 뷰
struct TaskGraphView: View {
    let agents: [SubAgent]
    
    @State private var selectedAgentId: UUID?
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var dragOffset: CGSize = .zero
    
    // 레이아웃 상수
    private let nodeWidth: CGFloat = 160
    private let nodeHeight: CGFloat = 80
    private let horizontalSpacing: CGFloat = 80
    private let verticalSpacing: CGFloat = 120
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 배경
                Color(nsColor: .textBackgroundColor)
                
                // 그래프
                ScrollView([.horizontal, .vertical]) {
                    ZStack {
                        // 엣지 (의존성 연결선)
                        ForEach(edges, id: \.0) { edge in
                            EdgeView(
                                from: nodePosition(for: edge.0),
                                to: nodePosition(for: edge.1),
                                color: edgeColor(from: edge.0, to: edge.1)
                            )
                        }
                        
                        // 노드 (에이전트)
                        ForEach(agents) { agent in
                            TaskNodeView(
                                agent: agent,
                                isSelected: selectedAgentId == agent.id,
                                onSelect: { selectedAgentId = agent.id }
                            )
                            .position(nodePosition(for: agent.id))
                        }
                    }
                    .frame(width: graphWidth, height: graphHeight)
                    .scaleEffect(scale)
                    .offset(x: offset.width + dragOffset.width, y: offset.height + dragOffset.height)
                }
                
                // 컨트롤 오버레이
                VStack {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        // 줌 컨트롤
                        VStack(spacing: 8) {
                            Button(action: { scale = min(2.0, scale + 0.2) }) {
                                Image(systemName: "plus.magnifyingglass")
                            }
                            .buttonStyle(.bordered)
                            
                            Text("\(Int(scale * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button(action: { scale = max(0.5, scale - 0.2) }) {
                                Image(systemName: "minus.magnifyingglass")
                            }
                            .buttonStyle(.bordered)
                            
                            Button(action: { scale = 1.0; offset = .zero }) {
                                Image(systemName: "arrow.counterclockwise")
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding()
                        .background(Color(nsColor: .windowBackgroundColor).opacity(0.9))
                        .cornerRadius(12)
                    }
                    .padding()
                }
                
                // 범례
                VStack {
                    legendView
                    Spacer()
                }
                .padding()
            }
        }
    }
    
    // MARK: - Legend
    
    private var legendView: some View {
        HStack(spacing: 16) {
            legendItem(color: .blue, label: "실행 중")
            legendItem(color: .green, label: "완료")
            legendItem(color: .red, label: "실패")
            legendItem(color: .secondary, label: "대기")
            
            Divider()
                .frame(height: 20)
            
            Text("\(agents.count)개 태스크")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.9))
        .cornerRadius(8)
    }
    
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Layout
    
    /// 노드 위치 계산 (레벨 기반 레이아웃)
    private func nodePosition(for agentId: UUID) -> CGPoint {
        guard let index = agents.firstIndex(where: { $0.id == agentId }) else {
            return .zero
        }
        
        let agent = agents[index]
        let level = calculateLevel(for: agent)
        let levelAgents = agents.filter { calculateLevel(for: $0) == level }
        let levelIndex = levelAgents.firstIndex(where: { $0.id == agentId }) ?? 0
        
        let x = CGFloat(level) * (nodeWidth + horizontalSpacing) + nodeWidth / 2 + 50
        let y = CGFloat(levelIndex) * (nodeHeight + verticalSpacing) + nodeHeight / 2 + 50
        
        return CGPoint(x: x, y: y)
    }
    
    /// 에이전트의 레벨 계산 (의존성 깊이)
    private func calculateLevel(for agent: SubAgent) -> Int {
        if agent.dependencies.isEmpty {
            return 0
        }
        
        var maxDepth = 0
        for depId in agent.dependencies {
            if let depAgent = agents.first(where: { $0.id == depId }) {
                let depLevel = calculateLevel(for: depAgent)
                maxDepth = max(maxDepth, depLevel + 1)
            }
        }
        return maxDepth
    }
    
    /// 그래프 너비
    private var graphWidth: CGFloat {
        let maxLevel = agents.map { calculateLevel(for: $0) }.max() ?? 0
        return CGFloat(maxLevel + 1) * (nodeWidth + horizontalSpacing) + 100
    }
    
    /// 그래프 높이
    private var graphHeight: CGFloat {
        let maxPerLevel = (0...10).map { level in
            agents.filter { calculateLevel(for: $0) == level }.count
        }.max() ?? 0
        return CGFloat(maxPerLevel) * (nodeHeight + verticalSpacing) + 100
    }
    
    /// 엣지 목록 (from, to)
    private var edges: [(UUID, UUID)] {
        var result: [(UUID, UUID)] = []
        for agent in agents {
            for depId in agent.dependencies {
                result.append((depId, agent.id))
            }
        }
        return result
    }
    
    /// 엣지 색상
    private func edgeColor(from: UUID, to: UUID) -> Color {
        guard let fromAgent = agents.first(where: { $0.id == from }),
              let toAgent = agents.first(where: { $0.id == to }) else {
            return .secondary
        }
        
        if fromAgent.status == .completed && toAgent.status == .running {
            return .blue
        } else if fromAgent.status == .completed && toAgent.status == .completed {
            return .green
        } else if fromAgent.status == .failed {
            return .red
        }
        
        return .secondary.opacity(0.5)
    }
}

// MARK: - Task Node View

struct TaskNodeView: View {
    let agent: SubAgent
    let isSelected: Bool
    let onSelect: () -> Void
    
    @State private var isHovering: Bool = false
    
    var body: some View {
        VStack(spacing: 6) {
            // 헤더
            HStack {
                // 상태 아이콘
                Image(systemName: agent.status.icon)
                    .foregroundColor(agent.status.color)
                    .font(.caption)
                
                Text(agent.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Spacer()
                
                // 태스크 타입 아이콘
                Image(systemName: agent.task.type.icon)
                    .foregroundColor(agent.task.type.color)
                    .font(.caption2)
            }
            
            // 태스크 제목
            Text(agent.task.title)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // 진행률 (실행 중일 때)
            if agent.status == .running {
                ProgressView(value: agent.progress)
                    .progressViewStyle(.linear)
                    .tint(.blue)
            }
        }
        .padding(10)
        .frame(width: 160, height: 80)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isSelected ? Color.accentColor :
                    isHovering ? Color.secondary.opacity(0.5) :
                    agent.status.color.opacity(0.3),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .shadow(color: agent.status.color.opacity(0.2), radius: isHovering ? 8 : 2)
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .onTapGesture { onSelect() }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Edge View

struct EdgeView: View {
    let from: CGPoint
    let to: CGPoint
    let color: Color
    
    var body: some View {
        Path { path in
            path.move(to: from)
            
            // 베지어 커브로 부드러운 연결선
            let controlPoint1 = CGPoint(
                x: from.x + (to.x - from.x) / 2,
                y: from.y
            )
            let controlPoint2 = CGPoint(
                x: from.x + (to.x - from.x) / 2,
                y: to.y
            )
            
            path.addCurve(to: to, control1: controlPoint1, control2: controlPoint2)
        }
        .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round))
        .overlay {
            // 화살표
            ArrowHead(from: from, to: to)
                .fill(color)
        }
    }
}

// MARK: - Arrow Head

struct ArrowHead: Shape {
    let from: CGPoint
    let to: CGPoint
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let angle = atan2(to.y - from.y, to.x - from.x)
        let arrowLength: CGFloat = 10
        let arrowAngle: CGFloat = .pi / 6
        
        let arrowPoint1 = CGPoint(
            x: to.x - arrowLength * cos(angle - arrowAngle),
            y: to.y - arrowLength * sin(angle - arrowAngle)
        )
        let arrowPoint2 = CGPoint(
            x: to.x - arrowLength * cos(angle + arrowAngle),
            y: to.y - arrowLength * sin(angle + arrowAngle)
        )
        
        path.move(to: to)
        path.addLine(to: arrowPoint1)
        path.addLine(to: arrowPoint2)
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Preview

#Preview("Task Graph") {
    let agents = [
        SubAgent(
            id: UUID(),
            name: "Agent-1",
            task: SubAgentTask(title: "기획서 작성", description: "", type: .documentation),
            status: .completed
        ),
        SubAgent(
            id: UUID(),
            name: "Agent-2",
            task: SubAgentTask(title: "디자인", description: "", type: .design),
            status: .completed
        ),
        SubAgent(
            id: UUID(),
            name: "Agent-3",
            task: SubAgentTask(title: "개발", description: "", type: .codeGeneration),
            status: .running,
            progress: 0.6
        ),
        SubAgent(
            id: UUID(),
            name: "Agent-4",
            task: SubAgentTask(title: "테스트", description: "", type: .testing),
            status: .idle
        )
    ]
    
    TaskGraphView(agents: agents)
        .frame(width: 800, height: 600)
}
