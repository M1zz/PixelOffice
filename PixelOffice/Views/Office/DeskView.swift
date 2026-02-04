import SwiftUI

struct DeskView: View {
    let employee: Employee
    let deskIndex: Int
    let onSelect: () -> Void
    var hasPendingQuestions: Bool = false  // 답변 안 한 질문이 있는지

    @State private var isHovering = false
    @State private var questionBounce = false

    var body: some View {
        Rectangle()
            .fill(Color.blue)
            .frame(width: 120, height: 120)
            .overlay(
                VStack(spacing: 8) {
                    Rectangle()
                        .fill(Color.red)
                        .frame(width: 80, height: 30)
                        .overlay(
                            Text("컴퓨터")
                                .font(.headline.bold())
                                .foregroundStyle(.white)
                        )

                    Rectangle()
                        .fill(Color.yellow)
                        .frame(width: 80, height: 30)
                        .overlay(
                            Text("책상")
                                .font(.headline.bold())
                                .foregroundStyle(.black)
                        )

                    Text(employee.name)
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(Color.black)
                }
            )
            .border(Color.purple, width: 5)
            .fixedSize()
            .onTapGesture(perform: onSelect)
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
