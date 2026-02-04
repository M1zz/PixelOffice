import SwiftUI

/// 사원증 뷰 - 직원의 신분증 카드
struct EmployeeBadgeView: View {
    let name: String
    let employeeNumber: String
    let departmentType: DepartmentType
    let aiType: AIType
    let appearance: CharacterAppearance
    let hireDate: Date

    var body: some View {
        VStack(spacing: 0) {
            // 상단 헤더 (회사명)
            HStack {
                Image(systemName: "building.2.fill")
                    .font(.caption)
                Text("PIXELOFFICE")
                    .font(.caption.bold())
                    .tracking(2)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: [departmentType.color, departmentType.color.opacity(0.7)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )

            // 사진 영역 (픽셀 캐릭터)
            VStack(spacing: 8) {
                // 픽셀 캐릭터 (큰 사이즈)
                PixelCharacterLarge(appearance: appearance, aiType: aiType)
                    .frame(width: 80, height: 100)
                    .background(Color(white: 0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )

                // 이름
                Text(name)
                    .font(.title3.bold())
                    .foregroundColor(.primary)

                // 사원번호
                Text(employeeNumber)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(Color.white)

            // 하단 정보
            VStack(spacing: 6) {
                HStack {
                    Image(systemName: departmentType.icon)
                        .font(.caption)
                    Text(departmentType.rawValue)
                        .font(.caption)
                }
                .foregroundColor(.white.opacity(0.9))

                HStack {
                    Image(systemName: aiType.icon)
                        .font(.caption)
                    Text(aiType.rawValue)
                        .font(.caption)
                }
                .foregroundColor(.white.opacity(0.9))

                Text("입사: \(hireDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(departmentType.color.opacity(0.8))

            // 바코드 영역
            HStack(spacing: 1) {
                ForEach(0..<30, id: \.self) { i in
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: i % 3 == 0 ? 2 : 1, height: 20)
                }
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Color.white)
        }
        .frame(width: 180)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
    }
}

/// 큰 사이즈 픽셀 캐릭터 (사원증용)
struct PixelCharacterLarge: View {
    let appearance: CharacterAppearance
    let aiType: AIType

    var skinColors: [Color] {
        [
            Color(red: 1.0, green: 0.87, blue: 0.77),
            Color(red: 0.91, green: 0.76, blue: 0.65),
            Color(red: 0.76, green: 0.57, blue: 0.45),
            Color(red: 0.55, green: 0.38, blue: 0.28)
        ]
    }

    var hairColors: [Color] {
        [
            Color(red: 0.1, green: 0.1, blue: 0.1),
            Color(red: 0.4, green: 0.26, blue: 0.13),
            Color(red: 0.65, green: 0.5, blue: 0.35),
            Color(red: 0.85, green: 0.65, blue: 0.13),
            Color(red: 0.6, green: 0.2, blue: 0.2),
            Color(red: 0.5, green: 0.5, blue: 0.6)
        ]
    }

    var shirtColors: [Color] {
        [.white, .blue, .red, .green, .purple, .orange, .pink, Color(white: 0.3)]
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
            let pixelSize: CGFloat = 5
            let centerX = size.width / 2
            let startY: CGFloat = 10

            // Hair
            drawHair(context: context, centerX: centerX, startY: startY, pixelSize: pixelSize)

            // Head
            drawPixelRect(context: context, x: centerX - pixelSize * 2, y: startY + pixelSize * 2, width: 4, height: 4, pixelSize: pixelSize, color: skinColor)

            // Eyes
            drawPixel(context: context, x: centerX - pixelSize, y: startY + pixelSize * 3, pixelSize: pixelSize, color: .black)
            drawPixel(context: context, x: centerX + pixelSize, y: startY + pixelSize * 3, pixelSize: pixelSize, color: .black)

            // Mouth (smile)
            drawPixel(context: context, x: centerX, y: startY + pixelSize * 5, pixelSize: pixelSize * 0.5, color: Color(white: 0.3))

            // Glasses
            if appearance.accessory == 1 {
                drawGlasses(context: context, centerX: centerX, startY: startY, pixelSize: pixelSize)
            }

            // Body/Shirt
            drawPixelRect(context: context, x: centerX - pixelSize * 2.5, y: startY + pixelSize * 6, width: 5, height: 6, pixelSize: pixelSize, color: shirtColor)

            // AI badge
            drawPixel(context: context, x: centerX, y: startY + pixelSize * 7, pixelSize: pixelSize, color: aiType.color)
        }
    }

    private func drawHair(context: GraphicsContext, centerX: CGFloat, startY: CGFloat, pixelSize: CGFloat) {
        switch appearance.hairStyle {
        case 0:
            drawPixelRect(context: context, x: centerX - pixelSize * 2, y: startY, width: 4, height: 2, pixelSize: pixelSize, color: hairColor)
        case 1:
            drawPixelRect(context: context, x: centerX - pixelSize * 2.5, y: startY, width: 5, height: 2, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX - pixelSize * 2.5, y: startY + pixelSize * 2, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX + pixelSize * 2.5, y: startY + pixelSize * 2, pixelSize: pixelSize, color: hairColor)
        case 2:
            drawPixelRect(context: context, x: centerX - pixelSize * 2.5, y: startY, width: 5, height: 2, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX - pixelSize * 2.5, y: startY + pixelSize * 2, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX + pixelSize * 2.5, y: startY + pixelSize * 2, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX - pixelSize * 2.5, y: startY + pixelSize * 3, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX + pixelSize * 2.5, y: startY + pixelSize * 3, pixelSize: pixelSize, color: hairColor)
        case 3:
            drawPixelRect(context: context, x: centerX - pixelSize * 2, y: startY + pixelSize, width: 4, height: 1, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX - pixelSize, y: startY, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX + pixelSize, y: startY, pixelSize: pixelSize, color: hairColor)
        default:
            break
        }
    }

    private func drawGlasses(context: GraphicsContext, centerX: CGFloat, startY: CGFloat, pixelSize: CGFloat) {
        let glassColor = Color(white: 0.2)
        drawPixel(context: context, x: centerX - pixelSize * 2, y: startY + pixelSize * 3, pixelSize: pixelSize, color: glassColor)
        drawPixel(context: context, x: centerX - pixelSize * 2, y: startY + pixelSize * 4, pixelSize: pixelSize, color: glassColor)
        drawPixel(context: context, x: centerX + pixelSize * 2, y: startY + pixelSize * 3, pixelSize: pixelSize, color: glassColor)
        drawPixel(context: context, x: centerX + pixelSize * 2, y: startY + pixelSize * 4, pixelSize: pixelSize, color: glassColor)
        drawPixel(context: context, x: centerX, y: startY + pixelSize * 3, pixelSize: pixelSize, color: glassColor)
    }

    private func drawPixel(context: GraphicsContext, x: CGFloat, y: CGFloat, pixelSize: CGFloat, color: Color) {
        let rect = CGRect(x: x - pixelSize/2, y: y, width: pixelSize, height: pixelSize)
        context.fill(Path(rect), with: .color(color))
    }

    private func drawPixelRect(context: GraphicsContext, x: CGFloat, y: CGFloat, width: Int, height: Int, pixelSize: CGFloat, color: Color) {
        for row in 0..<height {
            for col in 0..<width {
                drawPixel(context: context, x: x + CGFloat(col) * pixelSize, y: y + CGFloat(row) * pixelSize, pixelSize: pixelSize, color: color)
            }
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        EmployeeBadgeView(
            name: "마이클",
            employeeNumber: "EMP-0001",
            departmentType: .planning,
            aiType: .claude,
            appearance: CharacterAppearance(skinTone: 1, hairStyle: 1, hairColor: 2, shirtColor: 1, accessory: 0),
            hireDate: Date()
        )

        EmployeeBadgeView(
            name: "제니",
            employeeNumber: "EMP-0042",
            departmentType: .design,
            aiType: .gpt,
            appearance: CharacterAppearance(skinTone: 0, hairStyle: 2, hairColor: 3, shirtColor: 5, accessory: 1),
            hireDate: Date().addingTimeInterval(-86400 * 30)
        )
    }
    .padding(40)
    .background(Color(white: 0.9))
}
