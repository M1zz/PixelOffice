import SwiftUI

struct DeskView: View {
    let employee: Employee
    let deskIndex: Int
    let onSelect: () -> Void
    var hasPendingQuestions: Bool = false  // 답변 안 한 질문이 있는지

    @State private var isHovering = false
    @State private var questionBounce = false

    var body: some View {
        VStack(spacing: 6) {
            // 책상 영역
            VStack(spacing: 3) {
                // 컴퓨터 (파란 테두리)
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(Color.blue, lineWidth: 2)
                    .background(RoundedRectangle(cornerRadius: 3).fill(Color.cyan.opacity(0.3)))
                    .frame(width: 50, height: 30)

                // 책상 (갈색, 진하게)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.brown)
                    .frame(width: 70, height: 15)

                // 캐릭터 표시
                if employee.status != .idle {
                    Circle()
                        .fill(employee.aiType.color)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.black, lineWidth: 1)
                        )
                } else {
                    Text("💤")
                        .font(.title2)
                }
            }
            .frame(height: 80)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(0.5))

            Divider()

            // 이름과 상태
            VStack(spacing: 3) {
                Text(employee.name)
                    .font(.caption.bold())
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                HStack(spacing: 3) {
                    Circle()
                        .fill(employee.status.color)
                        .frame(width: 8, height: 8)
                    Text(employee.status.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.primary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 4)
        }
        .frame(width: 110, height: 140)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isHovering ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: isHovering ? 2 : 1)
        )
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

struct DeskShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Desk top
        path.addRoundedRect(
            in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height * 0.3),
            cornerSize: CGSize(width: 4, height: 4)
        )
        
        // Desk front panel
        path.addRect(CGRect(
            x: rect.width * 0.1,
            y: rect.height * 0.3,
            width: rect.width * 0.8,
            height: rect.height * 0.7
        ))
        
        return path
    }
}

struct MonitorShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Screen
        path.addRoundedRect(
            in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height * 0.8),
            cornerSize: CGSize(width: 2, height: 2)
        )
        
        // Stand
        path.addRect(CGRect(
            x: rect.width * 0.4,
            y: rect.height * 0.8,
            width: rect.width * 0.2,
            height: rect.height * 0.15
        ))
        
        // Base
        path.addRoundedRect(
            in: CGRect(
                x: rect.width * 0.25,
                y: rect.height * 0.9,
                width: rect.width * 0.5,
                height: rect.height * 0.1
            ),
            cornerSize: CGSize(width: 1, height: 1)
        )
        
        return path
    }
}

/// 물음표 말풍선 (온보딩 질문이 있을 때 표시)
struct QuestionMarkBubble: View {
    var body: some View {
        ZStack {
            // 말풍선 배경
            Capsule()
                .fill(Color.orange)
                .frame(width: 22, height: 22)
                .shadow(color: .orange.opacity(0.5), radius: 4)

            // 물음표
            Text("?")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        DeskView(
            employee: Employee(name: "Claude-1", aiType: .claude, status: .working),
            deskIndex: 0,
            onSelect: {}
        )
        
        DeskView(
            employee: Employee(name: "GPT-1", aiType: .gpt, status: .idle),
            deskIndex: 1,
            onSelect: {}
        )
    }
    .padding()
    .background(Color(NSColor.windowBackgroundColor))
}
