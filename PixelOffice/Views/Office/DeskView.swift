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
            // 책상과 컴퓨터 영역
            ZStack {
                // 책상 (갈색)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(red: 0.55, green: 0.35, blue: 0.2))
                    .frame(width: 90, height: 45)
                    .shadow(color: .black.opacity(0.2), radius: 2, y: 2)

                VStack(spacing: 2) {
                    // 와이드 모니터
                    VStack(spacing: 1) {
                        // 모니터 화면과 프레임
                        ZStack {
                            // 화면
                            RoundedRectangle(cornerRadius: 2)
                                .fill(employee.status == .working ?
                                      LinearGradient(colors: [Color.cyan.opacity(0.7), Color.blue.opacity(0.5)],
                                                   startPoint: .top, endPoint: .bottom) :
                                      LinearGradient(colors: [Color(white: 0.45), Color(white: 0.35)],
                                                   startPoint: .top, endPoint: .bottom))
                                .frame(width: 55, height: 32)

                            // 베젤
                            RoundedRectangle(cornerRadius: 2)
                                .stroke(Color(white: 0.2), lineWidth: 2)
                                .frame(width: 55, height: 32)

                            // 화면 글로우
                            if employee.status == .working {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.cyan.opacity(0.4))
                                    .frame(width: 55, height: 32)
                                    .blur(radius: 3)
                            }
                        }

                        // 모니터 스탠드
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(Color(white: 0.3))
                                .frame(width: 4, height: 6)
                            Rectangle()
                                .fill(Color(white: 0.25))
                                .frame(width: 20, height: 3)
                        }
                    }
                    .offset(y: -10)

                    // 캐릭터 (작업 중일 때만)
                    if employee.status != .idle {
                        PixelCharacter(
                            appearance: employee.characterAppearance,
                            status: employee.status,
                            aiType: employee.aiType
                        )
                        .scaleEffect(0.75)
                        .offset(y: -8)
                    }

                    // 커피 (휴식 중일 때)
                    if employee.status == .idle {
                        Text("☕️")
                            .font(.title3)
                            .offset(x: 20, y: -15)
                    }
                }
            }
            .frame(height: 80)

            // 이름표
            HStack(spacing: 4) {
                Circle()
                    .fill(employee.status.color)
                    .frame(width: 6, height: 6)

                Text(employee.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color(white: 0.95))
                    .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
            )
        }
        .frame(width: 110, height: 120)
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Color.black.opacity(0.05) : Color.clear)
        )
        .scaleEffect(isHovering ? 1.05 : 1.0)
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
