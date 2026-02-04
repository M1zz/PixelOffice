import SwiftUI

struct PixelCharacter: View {
    let appearance: CharacterAppearance
    let status: EmployeeStatus
    let aiType: AIType
    
    @State private var animationFrame = 0
    @State private var typingOffset: CGFloat = 0
    
    let timer = Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // Character body
            PixelBody(appearance: appearance, aiType: aiType)
            
            // Arms animation based on status
            if status == .working {
                TypingArms(frame: animationFrame)
            } else {
                IdleArms()
            }
            
            // Status indicator
            StatusBubble(status: status)
                .offset(x: 20, y: -25)
        }
        .frame(width: 40, height: 50)
        .onReceive(timer) { _ in
            if status == .working {
                withAnimation(.easeInOut(duration: 0.15)) {
                    animationFrame = (animationFrame + 1) % 4
                }
            }
        }
    }
}

struct PixelBody: View {
    let appearance: CharacterAppearance
    let aiType: AIType
    
    var skinColors: [Color] {
        [
            Color(red: 1.0, green: 0.87, blue: 0.77),  // Light
            Color(red: 0.91, green: 0.76, blue: 0.65), // Medium light
            Color(red: 0.76, green: 0.57, blue: 0.45), // Medium
            Color(red: 0.55, green: 0.38, blue: 0.28)  // Dark
        ]
    }
    
    var hairColors: [Color] {
        [
            Color(red: 0.1, green: 0.1, blue: 0.1),    // 0: Black
            Color(red: 0.4, green: 0.26, blue: 0.13),  // 1: Brown
            Color(red: 0.65, green: 0.5, blue: 0.35),  // 2: Light brown
            Color(red: 0.85, green: 0.65, blue: 0.13), // 3: Blonde
            Color(red: 0.6, green: 0.2, blue: 0.2),    // 4: Red
            Color(red: 0.5, green: 0.5, blue: 0.6),    // 5: Gray
            Color(red: 0.8, green: 0.8, blue: 0.85),   // 6: Silver
            Color(red: 0.2, green: 0.7, blue: 0.7),    // 7: Cyan
            Color(red: 0.6, green: 0.3, blue: 0.7)     // 8: Purple
        ]
    }
    
    var shirtColors: [Color] {
        [
            .white,                                    // 0: White
            .blue,                                     // 1: Blue
            .red,                                      // 2: Red
            .green,                                    // 3: Green
            .purple,                                   // 4: Purple
            .orange,                                   // 5: Orange
            .pink,                                     // 6: Pink
            Color(white: 0.3),                         // 7: Dark gray
            Color(red: 0.53, green: 0.81, blue: 0.92), // 8: Sky blue
            Color(red: 0.95, green: 0.90, blue: 0.25), // 9: Yellow
            Color(red: 0.0, green: 0.2, blue: 0.4),    // 10: Navy
            Color(red: 0.6, green: 0.95, blue: 0.85)   // 11: Mint
        ]
    }
    
    var skinColor: Color {
        skinColors[min(appearance.skinTone, skinColors.count - 1)]
    }
    
    var hairColor: Color {
        hairColors[min(appearance.hairColor, hairColors.count - 1)]
    }
    
    var shirtColor: Color {
        shirtColors[min(appearance.shirtColor, shirtColors.count - 1)]
    }
    
    var body: some View {
        Canvas { context, size in
            let pixelSize: CGFloat = 3
            let centerX = size.width / 2
            let startY: CGFloat = 5
            
            // Hair (different styles)
            drawHair(context: context, centerX: centerX, startY: startY, pixelSize: pixelSize)
            
            // Head
            drawPixelRect(context: context, x: centerX - pixelSize * 2, y: startY + pixelSize * 2, width: 4, height: 4, pixelSize: pixelSize, color: skinColor)
            
            // Eyes (표정에 따라 다르게)
            drawExpression(context: context, centerX: centerX, startY: startY, pixelSize: pixelSize)

            // Accessory
            drawAccessory(context: context, centerX: centerX, startY: startY, pixelSize: pixelSize)
            
            // Body/Shirt
            drawPixelRect(context: context, x: centerX - pixelSize * 2.5, y: startY + pixelSize * 6, width: 5, height: 5, pixelSize: pixelSize, color: shirtColor)
            
            // AI Type badge on shirt
            let badgeColor = aiType.color
            drawPixel(context: context, x: centerX, y: startY + pixelSize * 7, pixelSize: pixelSize, color: badgeColor)
        }
    }
    
    private func drawHair(context: GraphicsContext, centerX: CGFloat, startY: CGFloat, pixelSize: CGFloat) {
        switch appearance.hairStyle {
        case 0: // 숏컷
            drawPixelRect(context: context, x: centerX - pixelSize * 2, y: startY, width: 4, height: 2, pixelSize: pixelSize, color: hairColor)
        case 1: // 미디엄
            drawPixelRect(context: context, x: centerX - pixelSize * 2.5, y: startY, width: 5, height: 2, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX - pixelSize * 2.5, y: startY + pixelSize * 2, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX + pixelSize * 2.5, y: startY + pixelSize * 2, pixelSize: pixelSize, color: hairColor)
        case 2: // 롱헤어
            drawPixelRect(context: context, x: centerX - pixelSize * 2.5, y: startY, width: 5, height: 2, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX - pixelSize * 2.5, y: startY + pixelSize * 2, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX + pixelSize * 2.5, y: startY + pixelSize * 2, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX - pixelSize * 2.5, y: startY + pixelSize * 3, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX + pixelSize * 2.5, y: startY + pixelSize * 3, pixelSize: pixelSize, color: hairColor)
        case 3: // 스파이키
            drawPixelRect(context: context, x: centerX - pixelSize * 2, y: startY + pixelSize, width: 4, height: 1, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX - pixelSize, y: startY, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX + pixelSize, y: startY, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX, y: startY - pixelSize, pixelSize: pixelSize, color: hairColor)
        case 4: // 민머리
            break
        case 5: // 포니테일
            drawPixelRect(context: context, x: centerX - pixelSize * 2, y: startY, width: 4, height: 2, pixelSize: pixelSize, color: hairColor)
            // 뒤쪽 포니테일
            drawPixel(context: context, x: centerX + pixelSize * 3, y: startY + pixelSize * 2, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX + pixelSize * 3.5, y: startY + pixelSize * 3, pixelSize: pixelSize, color: hairColor)
        case 6: // 보브컷
            drawPixelRect(context: context, x: centerX - pixelSize * 2.5, y: startY, width: 5, height: 3, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX - pixelSize * 2, y: startY + pixelSize * 3, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX + pixelSize * 2, y: startY + pixelSize * 3, pixelSize: pixelSize, color: hairColor)
        case 7: // 모히칸
            drawPixel(context: context, x: centerX, y: startY - pixelSize, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX, y: startY, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX, y: startY + pixelSize, pixelSize: pixelSize, color: hairColor)
        case 8: // 곱슬
            drawPixelRect(context: context, x: centerX - pixelSize * 2.5, y: startY, width: 5, height: 2, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX - pixelSize * 3, y: startY + pixelSize, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX + pixelSize * 3, y: startY + pixelSize, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX - pixelSize * 2.5, y: startY + pixelSize * 2, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX + pixelSize * 2.5, y: startY + pixelSize * 2, pixelSize: pixelSize, color: hairColor)
        case 9: // 투블럭
            drawPixelRect(context: context, x: centerX - pixelSize * 2, y: startY, width: 4, height: 1, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX - pixelSize, y: startY + pixelSize, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX, y: startY + pixelSize, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX + pixelSize, y: startY + pixelSize, pixelSize: pixelSize, color: hairColor)
        case 10: // 울프컷
            drawPixelRect(context: context, x: centerX - pixelSize * 2.5, y: startY, width: 5, height: 2, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX - pixelSize * 3, y: startY + pixelSize * 2, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX + pixelSize * 3, y: startY + pixelSize * 2, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX - pixelSize * 2.5, y: startY + pixelSize * 3, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX + pixelSize * 2.5, y: startY + pixelSize * 3, pixelSize: pixelSize, color: hairColor)
        case 11: // 언더컷
            drawPixelRect(context: context, x: centerX - pixelSize * 1.5, y: startY, width: 3, height: 2, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX - pixelSize * 2, y: startY + pixelSize, pixelSize: pixelSize, color: hairColor.opacity(0.5))
            drawPixel(context: context, x: centerX + pixelSize * 2, y: startY + pixelSize, pixelSize: pixelSize, color: hairColor.opacity(0.5))
        default:
            break
        }
    }
    
    private func drawExpression(context: GraphicsContext, centerX: CGFloat, startY: CGFloat, pixelSize: CGFloat) {
        let eyeY = startY + pixelSize * 3
        let mouthY = startY + pixelSize * 4.5

        switch appearance.expression {
        case 0: // 기본
            drawPixel(context: context, x: centerX - pixelSize, y: eyeY, pixelSize: pixelSize, color: .black)
            drawPixel(context: context, x: centerX + pixelSize, y: eyeY, pixelSize: pixelSize, color: .black)
        case 1: // 웃음
            drawPixel(context: context, x: centerX - pixelSize, y: eyeY, pixelSize: pixelSize * 0.7, color: .black)
            drawPixel(context: context, x: centerX + pixelSize, y: eyeY, pixelSize: pixelSize * 0.7, color: .black)
            // 웃는 입
            drawPixel(context: context, x: centerX - pixelSize * 0.5, y: mouthY, pixelSize: pixelSize * 0.8, color: .black)
            drawPixel(context: context, x: centerX + pixelSize * 0.5, y: mouthY, pixelSize: pixelSize * 0.8, color: .black)
        case 2: // 진지
            drawPixelRect(context: context, x: centerX - pixelSize * 1.2, y: eyeY - pixelSize * 0.3, width: 1, height: 1, pixelSize: pixelSize * 1.2, color: .black)
            drawPixelRect(context: context, x: centerX + pixelSize * 0.8, y: eyeY - pixelSize * 0.3, width: 1, height: 1, pixelSize: pixelSize * 1.2, color: .black)
            // 일직선 입
            drawPixel(context: context, x: centerX, y: mouthY, pixelSize: pixelSize * 1.5, color: .black)
        case 3: // 피곤
            drawPixel(context: context, x: centerX - pixelSize, y: eyeY + pixelSize * 0.3, pixelSize: pixelSize * 0.5, color: .black)
            drawPixel(context: context, x: centerX + pixelSize, y: eyeY + pixelSize * 0.3, pixelSize: pixelSize * 0.5, color: .black)
            // 아래로 처진 입
            drawPixel(context: context, x: centerX, y: mouthY + pixelSize * 0.3, pixelSize: pixelSize * 0.8, color: .black)
        case 4: // 놀람
            drawPixel(context: context, x: centerX - pixelSize, y: eyeY, pixelSize: pixelSize * 1.3, color: .black)
            drawPixel(context: context, x: centerX + pixelSize, y: eyeY, pixelSize: pixelSize * 1.3, color: .black)
            // O 모양 입
            drawPixel(context: context, x: centerX, y: mouthY, pixelSize: pixelSize * 1.2, color: .black)
        default:
            drawPixel(context: context, x: centerX - pixelSize, y: eyeY, pixelSize: pixelSize, color: .black)
            drawPixel(context: context, x: centerX + pixelSize, y: eyeY, pixelSize: pixelSize, color: .black)
        }
    }

    private func drawAccessory(context: GraphicsContext, centerX: CGFloat, startY: CGFloat, pixelSize: CGFloat) {
        let accessoryColor = Color(white: 0.2)

        switch appearance.accessory {
        case 0: // 없음
            break
        case 1: // 안경
            // Left lens frame
            drawPixel(context: context, x: centerX - pixelSize * 2, y: startY + pixelSize * 3, pixelSize: pixelSize, color: accessoryColor)
            drawPixel(context: context, x: centerX - pixelSize * 2, y: startY + pixelSize * 4, pixelSize: pixelSize, color: accessoryColor)
            // Right lens frame
            drawPixel(context: context, x: centerX + pixelSize * 2, y: startY + pixelSize * 3, pixelSize: pixelSize, color: accessoryColor)
            drawPixel(context: context, x: centerX + pixelSize * 2, y: startY + pixelSize * 4, pixelSize: pixelSize, color: accessoryColor)
            // Bridge
            drawPixel(context: context, x: centerX, y: startY + pixelSize * 3, pixelSize: pixelSize, color: accessoryColor)
        case 2: // 모자
            drawPixelRect(context: context, x: centerX - pixelSize * 3, y: startY - pixelSize * 2, width: 6, height: 1, pixelSize: pixelSize, color: .red)
            drawPixelRect(context: context, x: centerX - pixelSize * 2, y: startY - pixelSize * 3, width: 4, height: 1, pixelSize: pixelSize, color: .red)
        case 3: // 헤드폰
            drawPixelRect(context: context, x: centerX - pixelSize * 3.5, y: startY + pixelSize * 2, width: 1, height: 3, pixelSize: pixelSize, color: .black)
            drawPixelRect(context: context, x: centerX + pixelSize * 3.5, y: startY + pixelSize * 2, width: 1, height: 3, pixelSize: pixelSize, color: .black)
            drawPixelRect(context: context, x: centerX - pixelSize * 2, y: startY - pixelSize, width: 4, height: 1, pixelSize: pixelSize, color: .black)
        case 4: // 선글라스
            drawPixelRect(context: context, x: centerX - pixelSize * 2.5, y: startY + pixelSize * 3, width: 2, height: 1, pixelSize: pixelSize, color: .black)
            drawPixelRect(context: context, x: centerX + pixelSize * 0.5, y: startY + pixelSize * 3, width: 2, height: 1, pixelSize: pixelSize, color: .black)
            drawPixel(context: context, x: centerX, y: startY + pixelSize * 3, pixelSize: pixelSize, color: .black)
        case 5: // 목걸이
            drawPixel(context: context, x: centerX, y: startY + pixelSize * 6, pixelSize: pixelSize, color: .yellow)
            drawPixel(context: context, x: centerX - pixelSize * 0.5, y: startY + pixelSize * 5.5, pixelSize: pixelSize * 0.6, color: accessoryColor)
            drawPixel(context: context, x: centerX + pixelSize * 0.5, y: startY + pixelSize * 5.5, pixelSize: pixelSize * 0.6, color: accessoryColor)
        case 6: // 마스크
            drawPixelRect(context: context, x: centerX - pixelSize * 1.5, y: startY + pixelSize * 3.5, width: 3, height: 2, pixelSize: pixelSize, color: .white)
            drawPixel(context: context, x: centerX - pixelSize * 2.5, y: startY + pixelSize * 4, pixelSize: pixelSize * 0.5, color: accessoryColor)
            drawPixel(context: context, x: centerX + pixelSize * 2.5, y: startY + pixelSize * 4, pixelSize: pixelSize * 0.5, color: accessoryColor)
        case 7: // 귀걸이
            drawPixel(context: context, x: centerX - pixelSize * 2.5, y: startY + pixelSize * 4.5, pixelSize: pixelSize * 0.8, color: .yellow)
            drawPixel(context: context, x: centerX + pixelSize * 2.5, y: startY + pixelSize * 4.5, pixelSize: pixelSize * 0.8, color: .yellow)
        case 8: // 헤어밴드
            drawPixelRect(context: context, x: centerX - pixelSize * 2.5, y: startY + pixelSize * 1.5, width: 5, height: 1, pixelSize: pixelSize, color: .pink)
        case 9: // 리본
            drawPixel(context: context, x: centerX - pixelSize * 3, y: startY + pixelSize, pixelSize: pixelSize * 1.5, color: .pink)
            drawPixel(context: context, x: centerX - pixelSize * 1.5, y: startY + pixelSize, pixelSize: pixelSize, color: .pink)
            drawPixel(context: context, x: centerX, y: startY + pixelSize, pixelSize: pixelSize, color: .pink)
        default:
            break
        }
    }
    
    private func drawPixel(context: GraphicsContext, x: CGFloat, y: CGFloat, pixelSize: CGFloat, color: Color) {
        let rect = CGRect(x: x - pixelSize/2, y: y, width: pixelSize, height: pixelSize)
        context.fill(Path(rect), with: .color(color))
    }
    
    private func drawPixelRect(context: GraphicsContext, x: CGFloat, y: CGFloat, width: Int, height: Int, pixelSize: CGFloat, color: Color) {
        for row in 0..<height {
            for col in 0..<width {
                drawPixel(
                    context: context,
                    x: x + CGFloat(col) * pixelSize,
                    y: y + CGFloat(row) * pixelSize,
                    pixelSize: pixelSize,
                    color: color
                )
            }
        }
    }
}

struct TypingArms: View {
    let frame: Int
    
    var body: some View {
        Canvas { context, size in
            let pixelSize: CGFloat = 3
            let centerX = size.width / 2
            let armY = size.height / 2 + 10
            
            let leftOffset = frame % 2 == 0 ? pixelSize : 0
            let rightOffset = frame % 2 == 1 ? pixelSize : 0
            
            // Left arm
            let leftArmRect = CGRect(
                x: centerX - pixelSize * 4,
                y: armY + leftOffset,
                width: pixelSize,
                height: pixelSize * 2
            )
            context.fill(Path(leftArmRect), with: .color(Color(red: 0.91, green: 0.76, blue: 0.65)))
            
            // Right arm
            let rightArmRect = CGRect(
                x: centerX + pixelSize * 3,
                y: armY + rightOffset,
                width: pixelSize,
                height: pixelSize * 2
            )
            context.fill(Path(rightArmRect), with: .color(Color(red: 0.91, green: 0.76, blue: 0.65)))
        }
    }
}

struct IdleArms: View {
    var body: some View {
        Canvas { context, size in
            let pixelSize: CGFloat = 3
            let centerX = size.width / 2
            let armY = size.height / 2 + 12
            
            // Left arm (resting)
            let leftArmRect = CGRect(
                x: centerX - pixelSize * 4,
                y: armY,
                width: pixelSize,
                height: pixelSize * 3
            )
            context.fill(Path(leftArmRect), with: .color(Color(red: 0.91, green: 0.76, blue: 0.65)))
            
            // Right arm (resting)
            let rightArmRect = CGRect(
                x: centerX + pixelSize * 3,
                y: armY,
                width: pixelSize,
                height: pixelSize * 3
            )
            context.fill(Path(rightArmRect), with: .color(Color(red: 0.91, green: 0.76, blue: 0.65)))
        }
    }
}

struct StatusBubble: View {
    let status: EmployeeStatus
    
    var body: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 16, height: 16)
            
            switch status {
            case .working:
                // Typing dots animation
                HStack(spacing: 1) {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(.gray)
                            .frame(width: 2, height: 2)
                    }
                }
            case .thinking:
                // Thinking bubble
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 8))
                    .foregroundStyle(.orange)
            case .idle:
                // Coffee cup or Zzz
                Text("☕")
                    .font(.system(size: 8))
            case .offline:
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.gray)
            case .error:
                Image(systemName: "exclamationmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.red)
            }
        }
    }
}

#Preview {
    HStack(spacing: 30) {
        VStack {
            PixelCharacter(
                appearance: CharacterAppearance(skinTone: 0, hairStyle: 0, hairColor: 0, shirtColor: 1, accessory: 0),
                status: .working,
                aiType: .claude
            )
            Text("Working")
        }
        
        VStack {
            PixelCharacter(
                appearance: CharacterAppearance(skinTone: 1, hairStyle: 1, hairColor: 3, shirtColor: 2, accessory: 1),
                status: .idle,
                aiType: .gpt
            )
            Text("Idle")
        }
        
        VStack {
            PixelCharacter(
                appearance: CharacterAppearance(skinTone: 2, hairStyle: 2, hairColor: 1, shirtColor: 4, accessory: 0),
                status: .offline,
                aiType: .gemini
            )
            Text("Offline")
        }
        
        VStack {
            PixelCharacter(
                appearance: CharacterAppearance.random(),
                status: .error,
                aiType: .local
            )
            Text("Error")
        }
    }
    .padding(40)
    .background(Color(NSColor.windowBackgroundColor))
}
