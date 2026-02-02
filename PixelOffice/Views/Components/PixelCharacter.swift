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
            Color(red: 0.1, green: 0.1, blue: 0.1),    // Black
            Color(red: 0.4, green: 0.26, blue: 0.13),  // Brown
            Color(red: 0.65, green: 0.5, blue: 0.35),  // Light brown
            Color(red: 0.85, green: 0.65, blue: 0.13), // Blonde
            Color(red: 0.6, green: 0.2, blue: 0.2),    // Red
            Color(red: 0.5, green: 0.5, blue: 0.6)     // Gray
        ]
    }
    
    var shirtColors: [Color] {
        [
            .white,
            .blue,
            .red,
            .green,
            .purple,
            .orange,
            .pink,
            Color(white: 0.3)  // Dark gray
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
            
            // Eyes
            drawPixel(context: context, x: centerX - pixelSize, y: startY + pixelSize * 3, pixelSize: pixelSize, color: .black)
            drawPixel(context: context, x: centerX + pixelSize, y: startY + pixelSize * 3, pixelSize: pixelSize, color: .black)
            
            // Accessory (glasses)
            if appearance.accessory == 1 {
                drawGlasses(context: context, centerX: centerX, startY: startY, pixelSize: pixelSize)
            }
            
            // Body/Shirt
            drawPixelRect(context: context, x: centerX - pixelSize * 2.5, y: startY + pixelSize * 6, width: 5, height: 5, pixelSize: pixelSize, color: shirtColor)
            
            // AI Type badge on shirt
            let badgeColor = aiType.color
            drawPixel(context: context, x: centerX, y: startY + pixelSize * 7, pixelSize: pixelSize, color: badgeColor)
        }
    }
    
    private func drawHair(context: GraphicsContext, centerX: CGFloat, startY: CGFloat, pixelSize: CGFloat) {
        switch appearance.hairStyle {
        case 0: // Short
            drawPixelRect(context: context, x: centerX - pixelSize * 2, y: startY, width: 4, height: 2, pixelSize: pixelSize, color: hairColor)
        case 1: // Medium
            drawPixelRect(context: context, x: centerX - pixelSize * 2.5, y: startY, width: 5, height: 2, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX - pixelSize * 2.5, y: startY + pixelSize * 2, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX + pixelSize * 2.5, y: startY + pixelSize * 2, pixelSize: pixelSize, color: hairColor)
        case 2: // Long
            drawPixelRect(context: context, x: centerX - pixelSize * 2.5, y: startY, width: 5, height: 2, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX - pixelSize * 2.5, y: startY + pixelSize * 2, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX + pixelSize * 2.5, y: startY + pixelSize * 2, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX - pixelSize * 2.5, y: startY + pixelSize * 3, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX + pixelSize * 2.5, y: startY + pixelSize * 3, pixelSize: pixelSize, color: hairColor)
        case 3: // Spiky
            drawPixelRect(context: context, x: centerX - pixelSize * 2, y: startY + pixelSize, width: 4, height: 1, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX - pixelSize, y: startY, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX + pixelSize, y: startY, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX, y: startY - pixelSize, pixelSize: pixelSize, color: hairColor)
        case 4: // Bald
            break
        default:
            break
        }
    }
    
    private func drawGlasses(context: GraphicsContext, centerX: CGFloat, startY: CGFloat, pixelSize: CGFloat) {
        let glassColor = Color(white: 0.2)
        // Left lens frame
        drawPixel(context: context, x: centerX - pixelSize * 2, y: startY + pixelSize * 3, pixelSize: pixelSize, color: glassColor)
        drawPixel(context: context, x: centerX - pixelSize * 2, y: startY + pixelSize * 4, pixelSize: pixelSize, color: glassColor)
        // Right lens frame
        drawPixel(context: context, x: centerX + pixelSize * 2, y: startY + pixelSize * 3, pixelSize: pixelSize, color: glassColor)
        drawPixel(context: context, x: centerX + pixelSize * 2, y: startY + pixelSize * 4, pixelSize: pixelSize, color: glassColor)
        // Bridge
        drawPixel(context: context, x: centerX, y: startY + pixelSize * 3, pixelSize: pixelSize, color: glassColor)
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
