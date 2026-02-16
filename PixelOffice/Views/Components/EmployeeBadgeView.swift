import SwiftUI

/// 사원증 뷰 - 직원의 신분증 카드 (탭하면 앞/뒤 전환)
struct EmployeeBadgeView: View {
    let name: String
    let employeeNumber: String
    let departmentType: DepartmentType
    let aiType: AIType
    let appearance: CharacterAppearance
    let hireDate: Date
    let jobRoles: [JobRole]
    let personality: String
    let strengths: [String]
    let workStyle: String
    let statistics: EmployeeStatistics

    @State private var isFlipped = false

    var body: some View {
        ZStack {
            // 앞면 (기본 정보)
            EmployeeBadgeFrontView(
                name: name,
                employeeNumber: employeeNumber,
                departmentType: departmentType,
                aiType: aiType,
                appearance: appearance,
                hireDate: hireDate
            )
            .opacity(isFlipped ? 0 : 1)
            .rotation3DEffect(
                .degrees(isFlipped ? 180 : 0),
                axis: (x: 0, y: 1, z: 0)
            )

            // 뒷면 (상세 정보)
            EmployeeBadgeBackView(
                jobRoles: jobRoles,
                personality: personality,
                strengths: strengths,
                workStyle: workStyle,
                departmentColor: departmentType.color
            )
            .opacity(isFlipped ? 1 : 0)
            .rotation3DEffect(
                .degrees(isFlipped ? 0 : -180),
                axis: (x: 0, y: 1, z: 0)
            )
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isFlipped.toggle()
            }
        }
    }
}

/// 사원증 앞면 - 기존 정보
struct EmployeeBadgeFrontView: View {
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

/// 사원증 뒷면 - 직원 특성 및 상세 정보
struct EmployeeBadgeBackView: View {
    let jobRoles: [JobRole]
    let personality: String
    let strengths: [String]
    let workStyle: String
    let departmentColor: Color

    var body: some View {
        VStack(spacing: 0) {
            // 상단 헤더
            HStack {
                Image(systemName: "person.text.rectangle")
                    .font(.caption)
                Text("직원 정보")
                    .font(.caption.bold())
                    .tracking(1)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: [departmentColor, departmentColor.opacity(0.7)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )

            // 본문 영역
            VStack(alignment: .leading, spacing: 12) {
                // 직군
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "briefcase.fill")
                            .font(.caption2)
                            .foregroundColor(departmentColor)
                        Text("직군")
                            .font(.caption2.bold())
                            .foregroundColor(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(jobRoles, id: \.self) { role in
                            HStack(spacing: 4) {
                                Text("•")
                                    .font(.caption2)
                                    .foregroundColor(departmentColor)
                                Text(role.rawValue)
                                    .font(.caption.bold())
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }

                Divider()

                // 성격
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                            .foregroundColor(departmentColor)
                        Text("성격")
                            .font(.caption2.bold())
                            .foregroundColor(.secondary)
                    }
                    Text(personality)
                        .font(.callout)
                        .foregroundColor(.primary)
                }

                Divider()

                // 강점
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(departmentColor)
                        Text("강점")
                            .font(.caption2.bold())
                            .foregroundColor(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(strengths, id: \.self) { strength in
                            HStack(spacing: 4) {
                                Text("•")
                                    .font(.caption2)
                                    .foregroundColor(departmentColor)
                                Text(strength)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }

                Divider()

                // 업무 스타일
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape.fill")
                            .font(.caption2)
                            .foregroundColor(departmentColor)
                        Text("업무 스타일")
                            .font(.caption2.bold())
                            .foregroundColor(.secondary)
                    }
                    Text(workStyle)
                        .font(.caption)
                        .foregroundColor(.primary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)

            // 하단 안내
            HStack {
                Image(systemName: "hand.tap.fill")
                    .font(.caption2)
                Text("탭하여 앞면 보기")
                    .font(.caption2)
            }
            .foregroundColor(.white.opacity(0.8))
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(departmentColor.opacity(0.8))
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
        case 0: // 숏컷 (볼륨 추가)
            drawPixelRect(context: context, x: centerX - pixelSize * 2.5, y: startY, width: 5, height: 2, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX - pixelSize * 2, y: startY + pixelSize * 2, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX + pixelSize * 2, y: startY + pixelSize * 2, pixelSize: pixelSize, color: hairColor)
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
            drawPixelRect(context: context, x: centerX - pixelSize * 2.5, y: startY, width: 5, height: 2, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX - pixelSize * 2, y: startY + pixelSize * 2, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX + pixelSize * 3, y: startY + pixelSize * 2, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX + pixelSize * 3.5, y: startY + pixelSize * 3, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX + pixelSize * 4, y: startY + pixelSize * 4, pixelSize: pixelSize, color: hairColor)
        case 6: // 보브컷
            drawPixelRect(context: context, x: centerX - pixelSize * 2.5, y: startY, width: 5, height: 3, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX - pixelSize * 2, y: startY + pixelSize * 3, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX + pixelSize * 2, y: startY + pixelSize * 3, pixelSize: pixelSize, color: hairColor)
        case 7: // 모히칸
            drawPixel(context: context, x: centerX, y: startY - pixelSize * 2, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX, y: startY - pixelSize, pixelSize: pixelSize, color: hairColor)
            drawPixelRect(context: context, x: centerX - pixelSize, y: startY, width: 2, height: 2, pixelSize: pixelSize, color: hairColor)
        case 8: // 곱슬
            drawPixelRect(context: context, x: centerX - pixelSize * 2.5, y: startY, width: 5, height: 2, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX - pixelSize * 3, y: startY + pixelSize, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX + pixelSize * 3, y: startY + pixelSize, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX - pixelSize * 2.5, y: startY + pixelSize * 2, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX + pixelSize * 2.5, y: startY + pixelSize * 2, pixelSize: pixelSize, color: hairColor)
        case 9: // 투블럭
            drawPixelRect(context: context, x: centerX - pixelSize * 2, y: startY, width: 4, height: 2, pixelSize: pixelSize, color: hairColor)
            drawPixel(context: context, x: centerX - pixelSize * 2, y: startY + pixelSize * 2, pixelSize: pixelSize, color: hairColor.opacity(0.5))
            drawPixel(context: context, x: centerX + pixelSize * 2, y: startY + pixelSize * 2, pixelSize: pixelSize, color: hairColor.opacity(0.5))
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
            // 알 수 없는 스타일은 숏컷으로 fallback
            drawPixelRect(context: context, x: centerX - pixelSize * 2.5, y: startY, width: 5, height: 2, pixelSize: pixelSize, color: hairColor)
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

/// 사원증 통계 면 - 활동 통계
struct EmployeeBadgeStatisticsView: View {
    let statistics: EmployeeStatistics
    let departmentColor: Color
    let name: String

    var body: some View {
        VStack(spacing: 0) {
            // 상단 헤더
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.caption)
                Text("STATISTICS")
                    .font(.caption.bold())
                    .tracking(2)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: [departmentColor, departmentColor.opacity(0.7)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )

            // 통계 정보
            VStack(spacing: 12) {
                Text("\(name)의 활동 통계")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                    .padding(.top, 12)

                // 토큰 사용량
                StatRow(
                    icon: "cpu",
                    label: "총 토큰 사용",
                    value: formatNumber(statistics.totalTokensUsed),
                    color: .blue
                )

                StatRow(
                    icon: "arrow.down.circle",
                    label: "입력 토큰",
                    value: formatNumber(statistics.inputTokens),
                    color: .green
                )

                StatRow(
                    icon: "arrow.up.circle",
                    label: "출력 토큰",
                    value: formatNumber(statistics.outputTokens),
                    color: .orange
                )

                Divider()
                    .padding(.vertical, 4)

                // 토큰 소비 속도
                StatRow(
                    icon: "speedometer",
                    label: "소비 속도",
                    value: String(format: "%.0f 토큰/시간", statistics.tokensPerHour),
                    color: .purple
                )

                // 최근 24시간 사용량
                StatRow(
                    icon: "clock",
                    label: "최근 24시간",
                    value: formatNumber(statistics.tokensLast24Hours),
                    color: .red
                )

                Divider()
                    .padding(.vertical, 4)

                // 생산성
                StatRow(
                    icon: "doc.text",
                    label: "작성 문서",
                    value: "\(statistics.documentsCreated)개",
                    color: .indigo
                )

                StatRow(
                    icon: "checkmark.circle",
                    label: "완료 태스크",
                    value: "\(statistics.tasksCompleted)개",
                    color: .teal
                )

                StatRow(
                    icon: "bubble.left.and.bubble.right",
                    label: "대화 횟수",
                    value: "\(statistics.conversationCount)회",
                    color: .cyan
                )

                // 활동 시간
                if statistics.totalActiveTime > 0 {
                    StatRow(
                        icon: "timer",
                        label: "총 활동 시간",
                        value: formatDuration(statistics.totalActiveTime),
                        color: .pink
                    )
                }
            }
            .padding(12)
        }
        .frame(width: 300, height: 450)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(departmentColor.opacity(0.3), lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
    }

    private func formatNumber(_ number: Int) -> String {
        if number >= 1_000_000 {
            return String(format: "%.1fM", Double(number) / 1_000_000)
        } else if number >= 1_000 {
            return String(format: "%.1fK", Double(number) / 1_000)
        } else {
            return "\(number)"
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)시간 \(minutes)분"
        } else {
            return "\(minutes)분"
        }
    }
}

/// 통계 행 뷰
struct StatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 20)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.caption.bold())
                .foregroundColor(.primary)
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
            hireDate: Date(),
            jobRoles: [.productManager, .scrumMaster],
            personality: "체계적이고 계획적인",
            strengths: ["전략적 사고", "프로젝트 관리", "커뮤니케이션"],
            workStyle: "체계적으로 계획하고 단계별로 실행",
            statistics: EmployeeStatistics()
        )

        EmployeeBadgeView(
            name: "제니",
            employeeNumber: "EMP-0042",
            departmentType: .design,
            aiType: .gpt,
            appearance: CharacterAppearance(skinTone: 0, hairStyle: 2, hairColor: 3, shirtColor: 5, accessory: 1),
            hireDate: Date().addingTimeInterval(-86400 * 30),
            jobRoles: [.uiDesigner, .uxDesigner],
            personality: "창의적이고 혁신적인",
            strengths: ["디자인 시스템", "사용자 경험", "비주얼 감각"],
            workStyle: "빠르게 프로토타입을 만들고 개선",
            statistics: EmployeeStatistics(
                totalTokensUsed: 45_000,
                inputTokens: 20_000,
                outputTokens: 25_000,
                documentsCreated: 12,
                tasksCompleted: 8,
                conversationCount: 35,
                totalActiveTime: 3600 * 4.5
            )
        )
    }
    .padding(40)
    .background(Color(white: 0.9))
}
