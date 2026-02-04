import SwiftUI

// MARK: - Pixel Art Decorations

/// 픽셀 아트 컴퓨터 (책상 위)
struct PixelComputer: View {
    var body: some View {
        Canvas { context, size in
            let pixelSize: CGFloat = 3

            // Monitor screen (밝은 파란색 - 더 눈에 잘 띄게)
            context.fill(
                Path(CGRect(x: 3*pixelSize, y: pixelSize, width: 14*pixelSize, height: 12*pixelSize)),
                with: .color(.cyan.opacity(0.6))
            )

            // Monitor frame (어두운 회색)
            let frameColor = Color(white: 0.2)

            // 상단 프레임
            for x in 2...17 {
                drawPixel(context, x: x, y: 0, pixelSize: pixelSize, color: frameColor)
            }

            // 하단 프레임
            for x in 2...17 {
                drawPixel(context, x: x, y: 13, pixelSize: pixelSize, color: frameColor)
            }

            // 좌우 프레임
            for y in 0...13 {
                drawPixel(context, x: 2, y: y, pixelSize: pixelSize, color: frameColor)
                drawPixel(context, x: 17, y: y, pixelSize: pixelSize, color: frameColor)
            }

            // Stand (짙은 회색)
            for x in 8...11 {
                drawPixel(context, x: x, y: 14, pixelSize: pixelSize, color: Color(white: 0.3))
                drawPixel(context, x: x, y: 15, pixelSize: pixelSize, color: Color(white: 0.3))
            }

            // Base (더 넓은 받침대)
            for x in 5...14 {
                drawPixel(context, x: x, y: 16, pixelSize: pixelSize, color: Color(white: 0.25))
            }
        }
        .frame(width: 60, height: 51)
    }
}

/// 픽셀 아트 화분 (식물)
struct PixelPlant: View {
    var body: some View {
        Canvas { context, size in
            let pixelSize: CGFloat = 2

            // Leaves (초록색)
            let leafPositions = [
                (3, 0), (4, 0), (5, 0),
                (2, 1), (3, 1), (4, 1), (5, 1), (6, 1),
                (3, 2), (4, 2), (5, 2),
                (4, 3)
            ]
            for (x, y) in leafPositions {
                drawPixel(context, x: x, y: y, pixelSize: pixelSize, color: .green)
            }

            // Stem (갈색)
            drawPixel(context, x: 4, y: 4, pixelSize: pixelSize, color: .brown)
            drawPixel(context, x: 4, y: 5, pixelSize: pixelSize, color: .brown)

            // Pot (빨간색)
            let potPositions = [
                (3, 6), (4, 6), (5, 6),
                (2, 7), (3, 7), (4, 7), (5, 7), (6, 7),
                (2, 8), (3, 8), (4, 8), (5, 8), (6, 8)
            ]
            for (x, y) in potPositions {
                drawPixel(context, x: x, y: y, pixelSize: pixelSize, color: .red.opacity(0.7))
            }
        }
        .frame(width: 20, height: 20)
    }
}

/// 픽셀 아트 커피머신
struct PixelCoffeeMachine: View {
    var body: some View {
        Canvas { context, size in
            let pixelSize: CGFloat = 2

            // Machine body (회색)
            for y in 0...7 {
                for x in 0...5 {
                    drawPixel(context, x: x, y: y, pixelSize: pixelSize, color: Color(white: 0.7))
                }
            }

            // Display (파란색)
            drawPixel(context, x: 1, y: 1, pixelSize: pixelSize, color: .cyan)
            drawPixel(context, x: 2, y: 1, pixelSize: pixelSize, color: .cyan)

            // Buttons (빨간색, 초록색)
            drawPixel(context, x: 4, y: 1, pixelSize: pixelSize, color: .red)
            drawPixel(context, x: 4, y: 2, pixelSize: pixelSize, color: .green)

            // Coffee outlet (검정)
            drawPixel(context, x: 2, y: 5, pixelSize: pixelSize, color: .black)
            drawPixel(context, x: 3, y: 5, pixelSize: pixelSize, color: .black)

            // Cup (흰색)
            drawPixel(context, x: 2, y: 6, pixelSize: pixelSize, color: .white)
            drawPixel(context, x: 3, y: 6, pixelSize: pixelSize, color: .white)
            drawPixel(context, x: 2, y: 7, pixelSize: pixelSize, color: .brown.opacity(0.5))
            drawPixel(context, x: 3, y: 7, pixelSize: pixelSize, color: .brown.opacity(0.5))
        }
        .frame(width: 16, height: 20)
    }
}

/// 픽셀 아트 책장
struct PixelBookshelf: View {
    var body: some View {
        Canvas { context, size in
            let pixelSize: CGFloat = 2
            let shelfColor = Color(red: 0.4, green: 0.25, blue: 0.15)

            // Shelf frame (갈색)
            for y in 0...15 {
                drawPixel(context, x: 0, y: y, pixelSize: pixelSize, color: shelfColor)
                drawPixel(context, x: 9, y: y, pixelSize: pixelSize, color: shelfColor)
            }

            // Shelves
            for x in 0...9 {
                drawPixel(context, x: x, y: 5, pixelSize: pixelSize, color: shelfColor)
                drawPixel(context, x: x, y: 10, pixelSize: pixelSize, color: shelfColor)
                drawPixel(context, x: x, y: 15, pixelSize: pixelSize, color: shelfColor)
            }

            // Books (다양한 색상) - simplified to help compiler
            self.drawBooks(context: context, pixelSize: pixelSize)
        }
        .frame(width: 24, height: 36)
    }

    private func drawBooks(context: GraphicsContext, pixelSize: CGFloat) {
        let books: [(Int, Int, Int, Color)] = [
            (1, 1, 2, .red), (3, 2, 1, .blue), (4, 1, 2, .green),
            (6, 3, 1, .yellow), (7, 2, 2, .purple), (1, 7, 3, .orange),
            (4, 6, 2, .cyan), (6, 8, 2, .pink), (1, 11, 2, .mint),
            (3, 12, 3, .indigo), (6, 11, 2, .teal)
        ]

        for book in books {
            for y in book.1..<(book.1 + book.2) {
                drawPixel(context, x: book.0, y: y, pixelSize: pixelSize, color: book.3)
            }
        }
    }
}

/// 픽셀 아트 포스터
struct PixelPoster: View {
    var body: some View {
        Canvas { context, size in
            let pixelSize: CGFloat = 2

            // Frame (검정)
            for x in 0...9 {
                drawPixel(context, x: x, y: 0, pixelSize: pixelSize, color: .black)
                drawPixel(context, x: x, y: 11, pixelSize: pixelSize, color: .black)
            }
            for y in 0...11 {
                drawPixel(context, x: 0, y: y, pixelSize: pixelSize, color: .black)
                drawPixel(context, x: 9, y: y, pixelSize: pixelSize, color: .black)
            }

            // Inner content (그라데이션 효과)
            for y in 1...10 {
                for x in 1...8 {
                    let gradient = Double(y) / 10.0
                    drawPixel(context, x: x, y: y, pixelSize: pixelSize, color: Color(red: 0.3, green: 0.5 + gradient * 0.3, blue: 0.8))
                }
            }

            // Simple graphic (삼각형)
            drawPixel(context, x: 4, y: 3, pixelSize: pixelSize, color: .white)
            drawPixel(context, x: 3, y: 4, pixelSize: pixelSize, color: .white)
            drawPixel(context, x: 4, y: 4, pixelSize: pixelSize, color: .white)
            drawPixel(context, x: 5, y: 4, pixelSize: pixelSize, color: .white)
            drawPixel(context, x: 2, y: 5, pixelSize: pixelSize, color: .white)
            drawPixel(context, x: 3, y: 5, pixelSize: pixelSize, color: .white)
            drawPixel(context, x: 4, y: 5, pixelSize: pixelSize, color: .white)
            drawPixel(context, x: 5, y: 5, pixelSize: pixelSize, color: .white)
            drawPixel(context, x: 6, y: 5, pixelSize: pixelSize, color: .white)
        }
        .frame(width: 24, height: 28)
    }
}

/// 픽셀 아트 물병
struct PixelWaterBottle: View {
    var body: some View {
        Canvas { context, size in
            let pixelSize: CGFloat = 2

            // Cap (검정)
            drawPixel(context, x: 1, y: 0, pixelSize: pixelSize, color: .black)
            drawPixel(context, x: 2, y: 0, pixelSize: pixelSize, color: .black)

            // Bottle (파란색 투명)
            for y in 1...7 {
                drawPixel(context, x: 0, y: y, pixelSize: pixelSize, color: .cyan.opacity(0.3))
                drawPixel(context, x: 1, y: y, pixelSize: pixelSize, color: .cyan.opacity(0.5))
                drawPixel(context, x: 2, y: y, pixelSize: pixelSize, color: .cyan.opacity(0.5))
                drawPixel(context, x: 3, y: y, pixelSize: pixelSize, color: .cyan.opacity(0.3))
            }

            // Water inside
            for y in 3...7 {
                drawPixel(context, x: 1, y: y, pixelSize: pixelSize, color: .blue.opacity(0.7))
                drawPixel(context, x: 2, y: y, pixelSize: pixelSize, color: .blue.opacity(0.7))
            }
        }
        .frame(width: 10, height: 18)
    }
}

/// 픽셀 아트 노트북
struct PixelLaptop: View {
    var body: some View {
        Canvas { context, size in
            let pixelSize: CGFloat = 2

            // Screen (검정 프레임)
            for x in 0...9 {
                drawPixel(context, x: x, y: 0, pixelSize: pixelSize, color: .black)
            }
            for y in 1...5 {
                drawPixel(context, x: 0, y: y, pixelSize: pixelSize, color: .black)
                drawPixel(context, x: 9, y: y, pixelSize: pixelSize, color: .black)
            }

            // Screen content (파란색)
            for y in 1...5 {
                for x in 1...8 {
                    drawPixel(context, x: x, y: y, pixelSize: pixelSize, color: .blue.opacity(0.3))
                }
            }

            // Keyboard base (회색)
            for x in 0...9 {
                drawPixel(context, x: x, y: 6, pixelSize: pixelSize, color: Color(white: 0.7))
            }
        }
        .frame(width: 24, height: 16)
    }
}

/// 픽셀 아트 시계
struct PixelClock: View {
    var body: some View {
        Canvas { context, size in
            let pixelSize: CGFloat = 2

            // Clock circle (흰색)
            let circlePositions = [
                (2, 0), (3, 0), (4, 0), (5, 0),
                (1, 1), (6, 1),
                (0, 2), (7, 2),
                (0, 3), (7, 3),
                (0, 4), (7, 4),
                (0, 5), (7, 5),
                (1, 6), (6, 6),
                (2, 7), (3, 7), (4, 7), (5, 7)
            ]
            for (x, y) in circlePositions {
                drawPixel(context, x: x, y: y, pixelSize: pixelSize, color: .white)
            }

            // Fill inside
            for y in 2...5 {
                for x in 1...6 {
                    if !circlePositions.contains(where: { $0 == (x, y) }) {
                        drawPixel(context, x: x, y: y, pixelSize: pixelSize, color: .white)
                    }
                }
            }

            // Clock hands (검정)
            drawPixel(context, x: 3, y: 3, pixelSize: pixelSize, color: .black)
            drawPixel(context, x: 4, y: 3, pixelSize: pixelSize, color: .black)
            drawPixel(context, x: 4, y: 4, pixelSize: pixelSize, color: .black)
            drawPixel(context, x: 4, y: 2, pixelSize: pixelSize, color: .black)
        }
        .frame(width: 18, height: 18)
    }
}

// MARK: - Helper Function

private func drawPixel(_ context: GraphicsContext, x: Int, y: Int, pixelSize: CGFloat, color: Color) {
    let rect = CGRect(
        x: CGFloat(x) * pixelSize,
        y: CGFloat(y) * pixelSize,
        width: pixelSize,
        height: pixelSize
    )
    context.fill(Path(rect), with: .color(color))
}

// MARK: - Department-specific Decorations

/// 부서별 인테리어 컴포넌트
struct DepartmentDecoration: View {
    let departmentType: DepartmentType
    let index: Int // 같은 부서 내에서 다른 위치에 배치하기 위한 인덱스

    var body: some View {
        switch departmentType {
        case .planning:
            // 기획팀: 화이트보드, 포스터, 노트북
            if index == 0 {
                PixelPoster()
            } else if index == 1 {
                PixelLaptop()
            } else {
                PixelWaterBottle()
            }

        case .design:
            // 디자인팀: 색연필, 팔레트, 화분
            if index == 0 {
                PixelPlant()
            } else if index == 1 {
                PixelPoster()
            } else {
                PixelWaterBottle()
            }

        case .development:
            // 개발팀: 여러 모니터, 커피, 에너지드링크
            if index == 0 {
                PixelCoffeeMachine()
            } else if index == 1 {
                PixelComputer()
            } else {
                PixelWaterBottle()
            }

        case .qa:
            // QA팀: 체크리스트, 버그 노트, 시계
            if index == 0 {
                PixelClock()
            } else if index == 1 {
                PixelBookshelf()
            } else {
                PixelLaptop()
            }

        case .marketing:
            // 마케팅팀: 그래프, 광고 포스터, 노트
            if index == 0 {
                PixelPoster()
            } else if index == 1 {
                PixelBookshelf()
            } else {
                PixelPlant()
            }

        case .general:
            // 일반: 기본 화분
            PixelPlant()
        }
    }
}

// MARK: - Preview

#Preview("Decorations") {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            PixelComputer()
            PixelPlant()
            PixelCoffeeMachine()
            PixelBookshelf()
        }

        HStack(spacing: 20) {
            PixelPoster()
            PixelWaterBottle()
            PixelLaptop()
            PixelClock()
        }

        Text("Department Decorations")
            .font(.headline)
            .padding(.top)

        HStack(spacing: 20) {
            VStack {
                DepartmentDecoration(departmentType: .planning, index: 0)
                Text("기획")
            }
            VStack {
                DepartmentDecoration(departmentType: .design, index: 0)
                Text("디자인")
            }
            VStack {
                DepartmentDecoration(departmentType: .development, index: 0)
                Text("개발")
            }
            VStack {
                DepartmentDecoration(departmentType: .qa, index: 0)
                Text("QA")
            }
            VStack {
                DepartmentDecoration(departmentType: .marketing, index: 0)
                Text("마케팅")
            }
        }
    }
    .padding(40)
    .background(Color(NSColor.windowBackgroundColor))
}
