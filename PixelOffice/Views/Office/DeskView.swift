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
            ZStack {
                // Desk
                DeskShape()
                    .fill(Color(red: 0.4, green: 0.25, blue: 0.15))
                    .frame(width: 100, height: 50)
                    .offset(y: 20)

                // Pixel Computer on desk
                PixelComputer()
                    .offset(y: 5)

                // Screen glow when working
                if employee.isWorking {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.cyan.opacity(0.4), .blue.opacity(0.2)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 24, height: 20)
                        .offset(y: 3)
                        .blur(radius: 3)
                }

                // Keyboard and mouse (pixel art)
                HStack(spacing: 6) {
                    // Keyboard
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color(white: 0.6))
                        .frame(width: 20, height: 6)

                    // Mouse
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(white: 0.65))
                        .frame(width: 6, height: 8)
                }
                .offset(y: 18)

                // Character (휴식 중일 때는 걸어다니므로 숨김)
                if employee.status != .idle {
                    PixelCharacter(
                        appearance: employee.characterAppearance,
                        status: employee.status,
                        aiType: employee.aiType
                    )
                    .offset(y: -20)
                }

                // 물음표 표시 (온보딩 질문이 있을 때)
                if hasPendingQuestions {
                    QuestionMarkBubble()
                        .offset(x: 25, y: -45)
                        .offset(y: questionBounce ? -3 : 0)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                                questionBounce = true
                            }
                        }
                }
            }
            
            // Name and status
            VStack(spacing: 4) {
                Text(employee.name)
                    .font(.body.bold())
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Circle()
                        .fill(employee.status.color)
                        .frame(width: 8, height: 8)
                    Text(employee.status.rawValue)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 120, height: 120)
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Color.black.opacity(0.05) : Color.clear)
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
