import SwiftUI

/// 걸어다니는 직원을 표시하는 뷰
struct WalkingCharacter: View {
    let appearance: CharacterAppearance
    let aiType: AIType
    let direction: WalkingDirection
    let isWalking: Bool  // 걷고 있는지 여부

    @State private var walkFrame = 0

    let timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Character body (mirrored based on direction)
            WalkingPixelBody(appearance: appearance, aiType: aiType, direction: direction)

            // Walking legs (멈췄을 때는 프레임 1로 고정 - 서있는 자세)
            WalkingLegs(frame: isWalking ? walkFrame : 1, skinTone: appearance.skinTone, direction: direction)
        }
        .frame(width: 40, height: 55)
        .scaleEffect(x: direction == .left ? -1 : 1, y: 1)
        .onReceive(timer) { _ in
            if isWalking {
                withAnimation(.easeInOut(duration: 0.1)) {
                    walkFrame = (walkFrame + 1) % 4
                }
            }
        }
    }
}

/// 걷는 방향
enum WalkingDirection {
    case left
    case right
    case up
    case down

    var isHorizontal: Bool {
        self == .left || self == .right
    }
}

/// 걷는 캐릭터의 몸체
struct WalkingPixelBody: View {
    let appearance: CharacterAppearance
    let aiType: AIType
    let direction: WalkingDirection

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
            let pixelSize: CGFloat = 3
            let centerX = size.width / 2
            let startY: CGFloat = 5

            // Hair
            drawHair(context: context, centerX: centerX, startY: startY, pixelSize: pixelSize)

            // Head
            drawPixelRect(context: context, x: centerX - pixelSize * 2, y: startY + pixelSize * 2, width: 4, height: 4, pixelSize: pixelSize, color: skinColor)

            // Eyes
            drawPixel(context: context, x: centerX - pixelSize, y: startY + pixelSize * 3, pixelSize: pixelSize, color: .black)
            drawPixel(context: context, x: centerX + pixelSize, y: startY + pixelSize * 3, pixelSize: pixelSize, color: .black)

            // Glasses
            if appearance.accessory == 1 {
                drawGlasses(context: context, centerX: centerX, startY: startY, pixelSize: pixelSize)
            }

            // Body/Shirt
            drawPixelRect(context: context, x: centerX - pixelSize * 2.5, y: startY + pixelSize * 6, width: 5, height: 5, pixelSize: pixelSize, color: shirtColor)

            // AI badge
            drawPixel(context: context, x: centerX, y: startY + pixelSize * 7, pixelSize: pixelSize, color: aiType.color)

            // Arms (swinging while walking)
            drawPixelRect(context: context, x: centerX - pixelSize * 4, y: startY + pixelSize * 7, width: 1, height: 3, pixelSize: pixelSize, color: skinColor)
            drawPixelRect(context: context, x: centerX + pixelSize * 3, y: startY + pixelSize * 7, width: 1, height: 3, pixelSize: pixelSize, color: skinColor)
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
            drawPixel(context: context, x: centerX, y: startY - pixelSize, pixelSize: pixelSize, color: hairColor)
        case 4:
            break
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

/// 걷는 다리 애니메이션
struct WalkingLegs: View {
    let frame: Int
    let skinTone: Int
    let direction: WalkingDirection

    var skinColors: [Color] {
        [
            Color(red: 1.0, green: 0.87, blue: 0.77),
            Color(red: 0.91, green: 0.76, blue: 0.65),
            Color(red: 0.76, green: 0.57, blue: 0.45),
            Color(red: 0.55, green: 0.38, blue: 0.28)
        ]
    }

    var pantsColor: Color { Color(red: 0.2, green: 0.2, blue: 0.3) }

    var skinColor: Color {
        skinColors[min(skinTone, skinColors.count - 1)]
    }

    var body: some View {
        Canvas { context, size in
            let pixelSize: CGFloat = 3
            let centerX = size.width / 2
            let legY = size.height / 2 + 12

            // Walking animation frames
            let leftOffset: CGFloat
            let rightOffset: CGFloat

            switch frame {
            case 0:
                leftOffset = -pixelSize
                rightOffset = pixelSize
            case 1:
                leftOffset = 0
                rightOffset = 0
            case 2:
                leftOffset = pixelSize
                rightOffset = -pixelSize
            case 3:
                leftOffset = 0
                rightOffset = 0
            default:
                leftOffset = 0
                rightOffset = 0
            }

            // Left leg (pants + foot)
            let leftLegRect = CGRect(
                x: centerX - pixelSize * 2 + leftOffset,
                y: legY,
                width: pixelSize,
                height: pixelSize * 3
            )
            context.fill(Path(leftLegRect), with: .color(pantsColor))

            let leftFootRect = CGRect(
                x: centerX - pixelSize * 2 + leftOffset,
                y: legY + pixelSize * 3,
                width: pixelSize,
                height: pixelSize
            )
            context.fill(Path(leftFootRect), with: .color(skinColor))

            // Right leg (pants + foot)
            let rightLegRect = CGRect(
                x: centerX + pixelSize + rightOffset,
                y: legY,
                width: pixelSize,
                height: pixelSize * 3
            )
            context.fill(Path(rightLegRect), with: .color(pantsColor))

            let rightFootRect = CGRect(
                x: centerX + pixelSize + rightOffset,
                y: legY + pixelSize * 3,
                width: pixelSize,
                height: pixelSize
            )
            context.fill(Path(rightFootRect), with: .color(skinColor))
        }
    }
}

/// 걸어다니는 직원의 위치와 상태
class WalkingEmployeeState: ObservableObject, Identifiable {
    let id: UUID
    let employeeId: UUID
    let appearance: CharacterAppearance
    let aiType: AIType
    let name: String
    let departmentType: DepartmentType

    /// 자리(책상) 위치 - 이 주변을 걸어다님
    let deskPosition: CGPoint

    /// 걸어다니는 반경
    let walkRadius: CGFloat = 120

    @Published var position: CGPoint
    @Published var direction: WalkingDirection = .right
    @Published var targetPosition: CGPoint
    @Published var isWalking: Bool = false  // 현재 걷고 있는지

    // 생각 말풍선 관련
    @Published var currentThought: String = ""
    @Published var showThought: Bool = false
    private var nextThoughtTime: Date
    private var thoughtEndTime: Date

    /// X축 또는 Y축 중 하나로만 이동
    private var movingAxis: MovingAxis = .horizontal

    /// 다음에 걷기 시작할 시간
    private var nextWalkTime: Date
    /// 다음에 멈출 시간
    private var nextStopTime: Date

    enum MovingAxis {
        case horizontal  // X축
        case vertical    // Y축
    }

    /// 부서별 생각 목록
    private var departmentThoughts: [String] {
        switch departmentType {
        case .planning:
            return [
                "🤔 사용자 니즈가...",
                "📊 시장 분석 중...",
                "💡 새로운 아이디어!",
                "📝 PRD 작성해야지",
                "🎯 KPI 정리 중...",
                "👥 타겟 유저는...",
                "📅 로드맵 검토 중"
            ]
        case .design:
            return [
                "🎨 색상 조합이...",
                "✏️ UI 스케치 중...",
                "📐 레이아웃 고민",
                "🖼️ 아이콘 디자인...",
                "💫 애니메이션은...",
                "📱 반응형 설계...",
                "🎭 UX 개선 중..."
            ]
        case .development:
            return [
                "💻 코드 리팩토링...",
                "🐛 버그 원인이...",
                "⚡ 성능 최적화...",
                "🔧 API 설계 중...",
                "📦 아키텍처 고민",
                "🧪 테스트 케이스...",
                "🔀 Git 머지 중..."
            ]
        case .qa:
            return [
                "🔍 버그 탐색 중...",
                "✅ 테스트 케이스...",
                "📋 QA 리포트 작성",
                "🎯 엣지 케이스...",
                "⚠️ 이슈 발견!",
                "📊 커버리지 확인",
                "🔄 회귀 테스트..."
            ]
        case .marketing:
            return [
                "📣 캠페인 기획 중",
                "📈 지표 분석 중...",
                "✍️ 카피라이팅...",
                "🎪 이벤트 준비 중",
                "📱 SNS 콘텐츠...",
                "🎯 타겟팅 전략...",
                "💰 예산 계획 중..."
            ]
        case .general:
            return [
                "☕ 커피 마시고 싶다",
                "📧 메일 확인해야지",
                "🍽️ 점심 뭐 먹지?",
                "📅 미팅 준비 중...",
                "💭 오늘 할 일은..."
            ]
        }
    }

    init(employeeId: UUID, appearance: CharacterAppearance, aiType: AIType, name: String, deskPosition: CGPoint, departmentType: DepartmentType = .general) {
        self.id = UUID()
        self.employeeId = employeeId
        self.appearance = appearance
        self.aiType = aiType
        self.name = name
        self.deskPosition = deskPosition
        self.departmentType = departmentType

        // 책상 근처에서 시작
        let offsetX = CGFloat.random(in: -walkRadius...walkRadius)
        let offsetY = CGFloat.random(in: -walkRadius...walkRadius)
        let startPosition = CGPoint(
            x: deskPosition.x + offsetX,
            y: deskPosition.y + offsetY
        )
        self.position = startPosition
        self.targetPosition = startPosition

        // 각 직원마다 랜덤한 초기 대기 시간 (0~5초)
        let initialDelay = Double.random(in: 0...5)
        self.nextWalkTime = Date().addingTimeInterval(initialDelay)
        self.nextStopTime = Date.distantFuture

        // 생각 말풍선 타이밍 (3~10초 후에 첫 생각)
        self.nextThoughtTime = Date().addingTimeInterval(Double.random(in: 3...10))
        self.thoughtEndTime = Date.distantFuture
    }

    /// 생각 말풍선 업데이트
    func updateThought() {
        let now = Date()

        // 생각을 보여줄 시간이 되면
        if !showThought && now >= nextThoughtTime {
            currentThought = departmentThoughts.randomElement() ?? "💭"
            showThought = true
            // 3~6초 동안 표시
            thoughtEndTime = now.addingTimeInterval(Double.random(in: 3...6))
        }

        // 생각을 숨길 시간이 되면
        if showThought && now >= thoughtEndTime {
            showThought = false
            // 5~15초 후에 다음 생각
            nextThoughtTime = now.addingTimeInterval(Double.random(in: 5...15))
        }
    }

    /// 새 목표 지점 선택 (X축 또는 Y축 중 하나로만)
    func pickNewTarget() {
        // 랜덤으로 X축 또는 Y축 선택
        movingAxis = Bool.random() ? .horizontal : .vertical

        if movingAxis == .horizontal {
            // X축으로만 이동
            let targetX = deskPosition.x + CGFloat.random(in: -walkRadius...walkRadius)
            targetPosition = CGPoint(x: targetX, y: position.y)
            direction = targetX > position.x ? .right : .left
        } else {
            // Y축으로만 이동
            let targetY = deskPosition.y + CGFloat.random(in: -walkRadius...walkRadius)
            targetPosition = CGPoint(x: position.x, y: targetY)
            direction = targetY > position.y ? .down : .up
        }

        // 걷기 시작
        isWalking = true
        // 1~4초 후에 멈춤
        nextStopTime = Date().addingTimeInterval(Double.random(in: 1...4))
    }

    /// 위치 업데이트 (매 프레임 호출)
    func updatePosition() {
        let now = Date()

        // 생각 말풍선 업데이트
        updateThought()

        // 멈춰있다가 걸을 시간이 되면
        if !isWalking && now >= nextWalkTime {
            pickNewTarget()
            return
        }

        // 걷다가 멈출 시간이 되면
        if isWalking && now >= nextStopTime {
            isWalking = false
            // 1~5초 후에 다시 걷기 시작
            nextWalkTime = now.addingTimeInterval(Double.random(in: 1...5))
            return
        }

        // 걷고 있을 때만 이동
        guard isWalking else { return }

        let speed: CGFloat = 0.8

        if movingAxis == .horizontal {
            let dx = targetPosition.x - position.x
            if abs(dx) < 3 {
                // 목표 도달
                isWalking = false
                nextWalkTime = Date().addingTimeInterval(Double.random(in: 1...5))
                return
            }
            position.x += (dx > 0 ? 1 : -1) * speed
            direction = dx > 0 ? .right : .left
        } else {
            let dy = targetPosition.y - position.y
            if abs(dy) < 3 {
                // 목표 도달
                isWalking = false
                nextWalkTime = Date().addingTimeInterval(Double.random(in: 1...5))
                return
            }
            position.y += (dy > 0 ? 1 : -1) * speed
            // 위아래로 움직일 때도 좌우 방향 유지 (캐릭터가 옆을 보도록)
        }
    }

    var hasReachedTarget: Bool {
        let dx = targetPosition.x - position.x
        let dy = targetPosition.y - position.y
        return sqrt(dx * dx + dy * dy) < 5
    }
}

/// 픽셀아트 스타일 생각 말풍선
struct PixelThoughtBubble: View {
    let text: String

    var body: some View {
        ZStack {
            // 말풍선 배경 (픽셀 스타일)
            Canvas { context, size in
                let pixelSize: CGFloat = 2
                let bubbleColor = Color.white
                let outlineColor = Color(white: 0.3)

                // 말풍선 본체 (둥근 사각형 형태를 픽셀로)
                let bodyWidth = Int(size.width / pixelSize) - 2
                let bodyHeight = Int(size.height / pixelSize) - 6

                // 외곽선 (상단)
                for x in 2..<(bodyWidth - 2) {
                    drawPixel(context: context, x: CGFloat(x) * pixelSize, y: 0, size: pixelSize, color: outlineColor)
                }

                // 외곽선 (좌우 상단 모서리)
                drawPixel(context: context, x: pixelSize, y: pixelSize, size: pixelSize, color: outlineColor)
                drawPixel(context: context, x: CGFloat(bodyWidth - 2) * pixelSize, y: pixelSize, size: pixelSize, color: outlineColor)

                // 본체 채우기
                for y in 1..<bodyHeight {
                    let startX = y == 1 ? 2 : 1
                    let endX = y == 1 ? bodyWidth - 2 : bodyWidth - 1

                    // 외곽선 (좌)
                    drawPixel(context: context, x: CGFloat(startX - 1) * pixelSize, y: CGFloat(y) * pixelSize, size: pixelSize, color: outlineColor)
                    // 외곽선 (우)
                    drawPixel(context: context, x: CGFloat(endX) * pixelSize, y: CGFloat(y) * pixelSize, size: pixelSize, color: outlineColor)

                    // 내부 채우기
                    for x in startX..<endX {
                        drawPixel(context: context, x: CGFloat(x) * pixelSize, y: CGFloat(y) * pixelSize, size: pixelSize, color: bubbleColor)
                    }
                }

                // 외곽선 (좌우 하단 모서리)
                drawPixel(context: context, x: pixelSize, y: CGFloat(bodyHeight - 1) * pixelSize, size: pixelSize, color: outlineColor)
                drawPixel(context: context, x: CGFloat(bodyWidth - 2) * pixelSize, y: CGFloat(bodyHeight - 1) * pixelSize, size: pixelSize, color: outlineColor)

                // 외곽선 (하단)
                for x in 2..<(bodyWidth - 2) {
                    drawPixel(context: context, x: CGFloat(x) * pixelSize, y: CGFloat(bodyHeight) * pixelSize, size: pixelSize, color: outlineColor)
                }

                // 구름 꼬리 (작은 원들)
                let tailY = CGFloat(bodyHeight + 1) * pixelSize
                drawPixel(context: context, x: CGFloat(bodyWidth / 2) * pixelSize, y: tailY, size: pixelSize, color: outlineColor)
                drawPixel(context: context, x: CGFloat(bodyWidth / 2 + 1) * pixelSize, y: tailY, size: pixelSize, color: bubbleColor)
                drawPixel(context: context, x: CGFloat(bodyWidth / 2 - 1) * pixelSize, y: tailY + pixelSize, size: pixelSize, color: outlineColor)
                drawPixel(context: context, x: CGFloat(bodyWidth / 2) * pixelSize, y: tailY + pixelSize, size: pixelSize, color: bubbleColor)
                drawPixel(context: context, x: CGFloat(bodyWidth / 2 + 1) * pixelSize, y: tailY + pixelSize, size: pixelSize, color: outlineColor)

                // 더 작은 원
                drawPixel(context: context, x: CGFloat(bodyWidth / 2 - 2) * pixelSize, y: tailY + pixelSize * 2.5, size: pixelSize * 0.8, color: outlineColor)
                drawPixel(context: context, x: CGFloat(bodyWidth / 2 - 3) * pixelSize, y: tailY + pixelSize * 3.5, size: pixelSize * 0.6, color: outlineColor)
            }

            // 텍스트
            Text(text)
                .font(.system(size: 10))
                .foregroundColor(.black)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .offset(y: -4)
        }
        .frame(width: max(CGFloat(text.count) * 8 + 16, 60), height: 32)
    }

    private func drawPixel(context: GraphicsContext, x: CGFloat, y: CGFloat, size: CGFloat, color: Color) {
        let rect = CGRect(x: x, y: y, width: size, height: size)
        context.fill(Path(rect), with: .color(color))
    }
}

#Preview {
    VStack(spacing: 30) {
        HStack(spacing: 40) {
            VStack {
                WalkingCharacter(
                    appearance: CharacterAppearance(skinTone: 0, hairStyle: 1, hairColor: 0, shirtColor: 1, accessory: 0),
                    aiType: .claude,
                    direction: .right,
                    isWalking: true
                )
                Text("걷는 중")
            }

            VStack {
                WalkingCharacter(
                    appearance: CharacterAppearance(skinTone: 1, hairStyle: 2, hairColor: 3, shirtColor: 2, accessory: 1),
                    aiType: .gpt,
                    direction: .left,
                    isWalking: false
                )
                Text("멈춤")
            }
        }
    }
    .padding(40)
    .background(Color(white: 0.9))
}
