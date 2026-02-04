import SwiftUI

struct DeskView: View {
    let employee: Employee
    let deskIndex: Int
    let onSelect: () -> Void
    var hasPendingQuestions: Bool = false  // 답변 안 한 질문이 있는지

    @State private var isHovering = false
    @State private var questionBounce = false

    var body: some View {
        VStack(spacing: 4) {
            // 컴퓨터 - 파란색
            ZStack {
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: 80, height: 40)

                Text("컴퓨터")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
            }

            // 책상 - 빨간색
            ZStack {
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 90, height: 30)

                Text("책상")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
            }

            // 캐릭터 - 노란색 또는 이모지
            if employee.status != .idle {
                ZStack {
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 35, height: 35)

                    Text("AI")
                        .font(.caption.bold())
                        .foregroundStyle(.black)
                }
            } else {
                Text("💤💤💤")
                    .font(.title)
            }

            // 이름 - 검은 배경에 흰 글씨
            ZStack {
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 25)

                Text(employee.name)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            // 상태 - 초록 배경
            ZStack {
                Rectangle()
                    .fill(Color.green)
                    .frame(height: 20)

                Text(employee.status.rawValue)
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 100, height: 160)
        .background(Color.white)
        .border(Color.black, width: 3)
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
