import SwiftUI

/// AI 생각 과정 표시 패널
struct ThinkingPanelView: View {
    let thinking: String
    let isExpanded: Bool
    let onToggle: () -> Void

    /// 생각 과정을 줄별로 분리
    var thinkingLines: [String] {
        thinking
            .components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 헤더
            Button {
                onToggle()
            } label: {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundStyle(.purple)
                    Text("AI 생각 중...")
                        .font(.headline)

                    Spacer()

                    // 타이핑 애니메이션
                    TypingIndicator()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.purple.opacity(0.1))
            }
            .buttonStyle(.plain)

            // 내용 (확장 시)
            if isExpanded && !thinking.isEmpty {
                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(thinkingLines.enumerated()), id: \.offset) { index, line in
                            ThinkingLineView(line: line, index: index)
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: 200)
                .background(Color(NSColor.textBackgroundColor).opacity(0.5))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
}

// MARK: - Thinking Line View

struct ThinkingLineView: View {
    let line: String
    let index: Int

    /// 생각 타입 감지
    var thinkingType: ThinkingType {
        let lowercased = line.lowercased()
        if lowercased.contains("결정") || lowercased.contains("선택") || lowercased.contains("decide") {
            return .decision
        } else if lowercased.contains("?") || lowercased.contains("고민") || lowercased.contains("생각") {
            return .question
        } else if lowercased.contains("검토") || lowercased.contains("확인") || lowercased.contains("분석") {
            return .analysis
        } else if lowercased.contains("결론") || lowercased.contains("따라서") || lowercased.contains("그러므로") {
            return .conclusion
        }
        return .normal
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: thinkingType.icon)
                .foregroundStyle(thinkingType.color)
                .frame(width: 16)

            Text(line)
                .font(.system(.body, design: .default))
                .foregroundStyle(thinkingType.textColor)
        }
        .padding(.vertical, 2)
    }
}

enum ThinkingType {
    case normal
    case question
    case decision
    case analysis
    case conclusion

    var icon: String {
        switch self {
        case .normal: return "circle.fill"
        case .question: return "questionmark.circle.fill"
        case .decision: return "checkmark.circle.fill"
        case .analysis: return "magnifyingglass.circle.fill"
        case .conclusion: return "arrow.right.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .normal: return .secondary
        case .question: return .orange
        case .decision: return .green
        case .analysis: return .blue
        case .conclusion: return .purple
        }
    }

    var textColor: Color {
        switch self {
        case .conclusion: return .purple
        case .decision: return .green
        default: return .primary
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var dotCount = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.purple.opacity(dotCount > index ? 1 : 0.3))
                    .frame(width: 6, height: 6)
            }
        }
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            dotCount = (dotCount + 1) % 4
        }
    }
}

// MARK: - Interrupt Dialog

/// 중요 결정 시 사용자 확인 다이얼로그
struct InterruptDialogView: View {
    let decision: PipelineDecision
    let onApprove: () -> Void
    let onReject: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            // 헤더
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title)
                    .foregroundStyle(.orange)
                Text("확인이 필요합니다")
                    .font(.title2.bold())
            }

            Divider()

            // 결정 내용
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("결정 사항")
                        .font(.headline)
                    Text(decision.decision)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("이유")
                        .font(.headline)
                    Text(decision.reason)
                        .foregroundStyle(.secondary)
                }

                if !decision.alternatives.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("대안")
                            .font(.headline)
                        ForEach(decision.alternatives, id: \.self) { alt in
                            Label(alt, systemImage: "arrow.turn.down.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Divider()

            // 버튼
            HStack(spacing: 16) {
                Button {
                    onReject()
                    dismiss()
                } label: {
                    Label("거부", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)

                Button {
                    onApprove()
                    dismiss()
                } label: {
                    Label("승인", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .padding(24)
        .frame(width: 450)
    }
}

// MARK: - Decision Log View

struct DecisionLogView: View {
    let decisions: [PipelineDecision]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text("🧠 결정 로그")
                    .font(.title2.bold())
                Spacer()
                Text("\(decisions.count)개 결정")
                    .foregroundStyle(.secondary)
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

            if decisions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "brain")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("결정 사항이 없습니다")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 결정 목록
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(decisions) { decision in
                            DecisionCard(decision: decision)
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(width: 600, height: 500)
    }
}

struct DecisionCard: View {
    let decision: PipelineDecision

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 헤더
            HStack {
                if let phase = decision.phase {
                    Label(phase.name, systemImage: phase.icon)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(phase.color.opacity(0.2))
                        .clipShape(Capsule())
                }

                Spacer()

                Text(decision.timestamp, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // 결정 내용
            Text(decision.decision)
                .font(.body.weight(.medium))

            // 이유
            Text(decision.reason)
                .font(.body)
                .foregroundStyle(.secondary)

            // 대안
            if !decision.alternatives.isEmpty {
                HStack {
                    Text("대안:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(decision.alternatives.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        ThinkingPanelView(
            thinking: """
            이 요구사항을 분석해보면...
            사용자가 원하는 것은 로그인 기능의 개선입니다.
            결정: OAuth 2.0을 사용하기로 했습니다.
            검토 결과 보안성이 더 높습니다.
            """,
            isExpanded: true,
            onToggle: {}
        )

        DecisionCard(decision: PipelineDecision(
            decision: "OAuth 2.0 방식 사용",
            reason: "보안성과 사용자 경험 측면에서 우수",
            alternatives: ["Session 기반 인증", "JWT 토큰"],
            phase: .development
        ))
    }
    .padding()
}
