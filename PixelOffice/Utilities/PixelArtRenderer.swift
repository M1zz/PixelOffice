import SwiftUI
import AppKit

/// Utility class for rendering pixel art graphics
class PixelArtRenderer {
    
    // MARK: - Color Palettes
    
    static let skinTones: [NSColor] = [
        NSColor(red: 1.0, green: 0.87, blue: 0.77, alpha: 1.0),    // Light
        NSColor(red: 0.91, green: 0.76, blue: 0.65, alpha: 1.0),   // Medium light
        NSColor(red: 0.76, green: 0.57, blue: 0.45, alpha: 1.0),   // Medium
        NSColor(red: 0.55, green: 0.38, blue: 0.28, alpha: 1.0)    // Dark
    ]
    
    static let hairColors: [NSColor] = [
        NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0),      // 0: Black
        NSColor(red: 0.4, green: 0.26, blue: 0.13, alpha: 1.0),    // 1: Brown
        NSColor(red: 0.65, green: 0.5, blue: 0.35, alpha: 1.0),    // 2: Light brown
        NSColor(red: 0.85, green: 0.65, blue: 0.13, alpha: 1.0),   // 3: Blonde
        NSColor(red: 0.6, green: 0.2, blue: 0.2, alpha: 1.0),      // 4: Red
        NSColor(red: 0.5, green: 0.5, blue: 0.6, alpha: 1.0),      // 5: Gray
        NSColor(red: 0.8, green: 0.8, blue: 0.85, alpha: 1.0),     // 6: Silver
        NSColor(red: 0.2, green: 0.7, blue: 0.7, alpha: 1.0),      // 7: Cyan
        NSColor(red: 0.6, green: 0.3, blue: 0.7, alpha: 1.0)       // 8: Purple
    ]
    
    static let shirtColors: [NSColor] = [
        .white,                                                     // 0: White
        NSColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0),      // 1: Blue
        NSColor(red: 0.8, green: 0.2, blue: 0.2, alpha: 1.0),      // 2: Red
        NSColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0),      // 3: Green
        NSColor(red: 0.6, green: 0.3, blue: 0.7, alpha: 1.0),      // 4: Purple
        NSColor(red: 0.9, green: 0.5, blue: 0.1, alpha: 1.0),      // 5: Orange
        NSColor(red: 0.9, green: 0.5, blue: 0.6, alpha: 1.0),      // 6: Pink
        NSColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0),      // 7: Dark gray
        NSColor(red: 0.53, green: 0.81, blue: 0.92, alpha: 1.0),   // 8: Sky blue
        NSColor(red: 0.95, green: 0.90, blue: 0.25, alpha: 1.0),   // 9: Yellow
        NSColor(red: 0.0, green: 0.2, blue: 0.4, alpha: 1.0),      // 10: Navy
        NSColor(red: 0.6, green: 0.95, blue: 0.85, alpha: 1.0)     // 11: Mint
    ]
    
    // MARK: - Rendering Methods
    
    /// Renders a pixel art character to an NSImage
    static func renderCharacter(
        appearance: CharacterAppearance,
        status: EmployeeStatus,
        aiType: AIType,
        size: CGSize = CGSize(width: 32, height: 48),
        pixelSize: CGFloat = 2
    ) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        
        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }
        
        let centerX = size.width / 2
        let startY: CGFloat = 4
        
        // Get colors
        let skinColor = skinTones[min(appearance.skinTone, skinTones.count - 1)]
        let hairColor = hairColors[min(appearance.hairColor, hairColors.count - 1)]
        let shirtColor = shirtColors[min(appearance.shirtColor, shirtColors.count - 1)]
        
        // Draw hair
        drawHair(
            context: context,
            style: appearance.hairStyle,
            color: hairColor,
            centerX: centerX,
            startY: startY,
            pixelSize: pixelSize
        )
        
        // Draw head
        drawPixelRect(
            context: context,
            x: centerX - pixelSize * 2,
            y: startY + pixelSize * 2,
            width: 4,
            height: 4,
            pixelSize: pixelSize,
            color: skinColor
        )
        
        // Draw eyes
        drawPixel(context: context, x: centerX - pixelSize, y: startY + pixelSize * 3, pixelSize: pixelSize, color: .black)
        drawPixel(context: context, x: centerX + pixelSize, y: startY + pixelSize * 3, pixelSize: pixelSize, color: .black)
        
        // Draw body
        drawPixelRect(
            context: context,
            x: centerX - pixelSize * 2.5,
            y: startY + pixelSize * 6,
            width: 5,
            height: 5,
            pixelSize: pixelSize,
            color: shirtColor
        )
        
        // Draw AI badge
        let badgeColor = NSColor(aiType.color)
        drawPixel(context: context, x: centerX, y: startY + pixelSize * 7, pixelSize: pixelSize, color: badgeColor)
        
        // Draw arms based on status
        if status == .working {
            drawTypingArms(context: context, centerX: centerX, startY: startY, pixelSize: pixelSize, skinColor: skinColor)
        } else {
            drawIdleArms(context: context, centerX: centerX, startY: startY, pixelSize: pixelSize, skinColor: skinColor)
        }
        
        image.unlockFocus()
        return image
    }
    
    // MARK: - Drawing Helpers
    
    private static func drawPixel(
        context: CGContext,
        x: CGFloat,
        y: CGFloat,
        pixelSize: CGFloat,
        color: NSColor
    ) {
        context.setFillColor(color.cgColor)
        context.fill(CGRect(x: x - pixelSize/2, y: y, width: pixelSize, height: pixelSize))
    }
    
    private static func drawPixelRect(
        context: CGContext,
        x: CGFloat,
        y: CGFloat,
        width: Int,
        height: Int,
        pixelSize: CGFloat,
        color: NSColor
    ) {
        context.setFillColor(color.cgColor)
        for row in 0..<height {
            for col in 0..<width {
                context.fill(CGRect(
                    x: x + CGFloat(col) * pixelSize - pixelSize/2,
                    y: y + CGFloat(row) * pixelSize,
                    width: pixelSize,
                    height: pixelSize
                ))
            }
        }
    }
    
    private static func drawHair(
        context: CGContext,
        style: Int,
        color: NSColor,
        centerX: CGFloat,
        startY: CGFloat,
        pixelSize: CGFloat
    ) {
        switch style {
        case 0: // 숏컷 (볼륨 추가)
            drawPixelRect(context: context, x: centerX - pixelSize * 2.5, y: startY, width: 5, height: 2, pixelSize: pixelSize, color: color)
            drawPixel(context: context, x: centerX - pixelSize * 2, y: startY + pixelSize * 2, pixelSize: pixelSize, color: color)
            drawPixel(context: context, x: centerX + pixelSize * 2, y: startY + pixelSize * 2, pixelSize: pixelSize, color: color)
        case 1: // 미디엄
            drawPixelRect(context: context, x: centerX - pixelSize * 2.5, y: startY, width: 5, height: 2, pixelSize: pixelSize, color: color)
            drawPixel(context: context, x: centerX - pixelSize * 2.5, y: startY + pixelSize * 2, pixelSize: pixelSize, color: color)
            drawPixel(context: context, x: centerX + pixelSize * 2.5, y: startY + pixelSize * 2, pixelSize: pixelSize, color: color)
        case 2: // 롱헤어
            drawPixelRect(context: context, x: centerX - pixelSize * 2.5, y: startY, width: 5, height: 2, pixelSize: pixelSize, color: color)
            drawPixel(context: context, x: centerX - pixelSize * 2.5, y: startY + pixelSize * 2, pixelSize: pixelSize, color: color)
            drawPixel(context: context, x: centerX + pixelSize * 2.5, y: startY + pixelSize * 2, pixelSize: pixelSize, color: color)
            drawPixel(context: context, x: centerX - pixelSize * 2.5, y: startY + pixelSize * 3, pixelSize: pixelSize, color: color)
            drawPixel(context: context, x: centerX + pixelSize * 2.5, y: startY + pixelSize * 3, pixelSize: pixelSize, color: color)
        case 3: // 스파이키
            drawPixelRect(context: context, x: centerX - pixelSize * 2, y: startY + pixelSize, width: 4, height: 1, pixelSize: pixelSize, color: color)
            drawPixel(context: context, x: centerX - pixelSize, y: startY, pixelSize: pixelSize, color: color)
            drawPixel(context: context, x: centerX + pixelSize, y: startY, pixelSize: pixelSize, color: color)
            drawPixel(context: context, x: centerX, y: startY - pixelSize, pixelSize: pixelSize, color: color)
        case 4: // 민머리
            break
        case 5: // 포니테일
            drawPixelRect(context: context, x: centerX - pixelSize * 2.5, y: startY, width: 5, height: 2, pixelSize: pixelSize, color: color)
            drawPixel(context: context, x: centerX - pixelSize * 2, y: startY + pixelSize * 2, pixelSize: pixelSize, color: color)
            drawPixel(context: context, x: centerX + pixelSize * 3, y: startY + pixelSize * 2, pixelSize: pixelSize, color: color)
            drawPixel(context: context, x: centerX + pixelSize * 3.5, y: startY + pixelSize * 3, pixelSize: pixelSize, color: color)
            drawPixel(context: context, x: centerX + pixelSize * 4, y: startY + pixelSize * 4, pixelSize: pixelSize, color: color)
        case 6: // 보브컷
            drawPixelRect(context: context, x: centerX - pixelSize * 2.5, y: startY, width: 5, height: 3, pixelSize: pixelSize, color: color)
            drawPixel(context: context, x: centerX - pixelSize * 2, y: startY + pixelSize * 3, pixelSize: pixelSize, color: color)
            drawPixel(context: context, x: centerX + pixelSize * 2, y: startY + pixelSize * 3, pixelSize: pixelSize, color: color)
        case 7: // 모히칸
            drawPixel(context: context, x: centerX, y: startY - pixelSize * 2, pixelSize: pixelSize, color: color)
            drawPixel(context: context, x: centerX, y: startY - pixelSize, pixelSize: pixelSize, color: color)
            drawPixelRect(context: context, x: centerX - pixelSize, y: startY, width: 2, height: 2, pixelSize: pixelSize, color: color)
        case 8: // 곱슬
            drawPixelRect(context: context, x: centerX - pixelSize * 2.5, y: startY, width: 5, height: 2, pixelSize: pixelSize, color: color)
            drawPixel(context: context, x: centerX - pixelSize * 3, y: startY + pixelSize, pixelSize: pixelSize, color: color)
            drawPixel(context: context, x: centerX + pixelSize * 3, y: startY + pixelSize, pixelSize: pixelSize, color: color)
            drawPixel(context: context, x: centerX - pixelSize * 2.5, y: startY + pixelSize * 2, pixelSize: pixelSize, color: color)
            drawPixel(context: context, x: centerX + pixelSize * 2.5, y: startY + pixelSize * 2, pixelSize: pixelSize, color: color)
        case 9: // 투블럭
            drawPixelRect(context: context, x: centerX - pixelSize * 2, y: startY, width: 4, height: 2, pixelSize: pixelSize, color: color)
            drawPixel(context: context, x: centerX - pixelSize * 2, y: startY + pixelSize * 2, pixelSize: pixelSize, color: color.withAlphaComponent(0.5))
            drawPixel(context: context, x: centerX + pixelSize * 2, y: startY + pixelSize * 2, pixelSize: pixelSize, color: color.withAlphaComponent(0.5))
        case 10: // 울프컷
            drawPixelRect(context: context, x: centerX - pixelSize * 2.5, y: startY, width: 5, height: 2, pixelSize: pixelSize, color: color)
            drawPixel(context: context, x: centerX - pixelSize * 3, y: startY + pixelSize * 2, pixelSize: pixelSize, color: color)
            drawPixel(context: context, x: centerX + pixelSize * 3, y: startY + pixelSize * 2, pixelSize: pixelSize, color: color)
            drawPixel(context: context, x: centerX - pixelSize * 2.5, y: startY + pixelSize * 3, pixelSize: pixelSize, color: color)
            drawPixel(context: context, x: centerX + pixelSize * 2.5, y: startY + pixelSize * 3, pixelSize: pixelSize, color: color)
        case 11: // 언더컷
            drawPixelRect(context: context, x: centerX - pixelSize * 1.5, y: startY, width: 3, height: 2, pixelSize: pixelSize, color: color)
            drawPixel(context: context, x: centerX - pixelSize * 2, y: startY + pixelSize, pixelSize: pixelSize, color: color.withAlphaComponent(0.5))
            drawPixel(context: context, x: centerX + pixelSize * 2, y: startY + pixelSize, pixelSize: pixelSize, color: color.withAlphaComponent(0.5))
        default:
            // 알 수 없는 스타일은 숏컷으로 fallback
            drawPixelRect(context: context, x: centerX - pixelSize * 2.5, y: startY, width: 5, height: 2, pixelSize: pixelSize, color: color)
        }
    }
    
    private static func drawTypingArms(
        context: CGContext,
        centerX: CGFloat,
        startY: CGFloat,
        pixelSize: CGFloat,
        skinColor: NSColor
    ) {
        let armY = startY + pixelSize * 8
        
        // Left arm (extended for typing)
        drawPixelRect(context: context, x: centerX - pixelSize * 4, y: armY, width: 1, height: 2, pixelSize: pixelSize, color: skinColor)
        
        // Right arm (extended for typing)
        drawPixelRect(context: context, x: centerX + pixelSize * 3, y: armY, width: 1, height: 2, pixelSize: pixelSize, color: skinColor)
    }
    
    private static func drawIdleArms(
        context: CGContext,
        centerX: CGFloat,
        startY: CGFloat,
        pixelSize: CGFloat,
        skinColor: NSColor
    ) {
        let armY = startY + pixelSize * 8
        
        // Left arm (at rest)
        drawPixelRect(context: context, x: centerX - pixelSize * 4, y: armY + pixelSize, width: 1, height: 3, pixelSize: pixelSize, color: skinColor)
        
        // Right arm (at rest)
        drawPixelRect(context: context, x: centerX + pixelSize * 3, y: armY + pixelSize, width: 1, height: 3, pixelSize: pixelSize, color: skinColor)
    }
    
    // MARK: - Office Furniture
    
    /// Renders a desk
    static func renderDesk(size: CGSize = CGSize(width: 80, height: 40)) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        
        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }
        
        let deskColor = NSColor(red: 0.4, green: 0.25, blue: 0.15, alpha: 1.0)
        
        // Desk top
        context.setFillColor(deskColor.cgColor)
        context.fill(CGRect(x: 0, y: size.height * 0.7, width: size.width, height: size.height * 0.3))
        
        // Desk front panel
        context.setFillColor(deskColor.darker().cgColor)
        context.fill(CGRect(x: size.width * 0.1, y: 0, width: size.width * 0.8, height: size.height * 0.7))
        
        image.unlockFocus()
        return image
    }
    
    /// Renders a monitor
    static func renderMonitor(isOn: Bool = false, size: CGSize = CGSize(width: 32, height: 28)) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        
        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return image
        }
        
        let frameColor = NSColor(white: 0.15, alpha: 1.0)
        let screenColor = isOn ? NSColor(red: 0.2, green: 0.3, blue: 0.5, alpha: 1.0) : NSColor(white: 0.1, alpha: 1.0)
        
        // Screen frame
        context.setFillColor(frameColor.cgColor)
        context.fill(CGRect(x: 0, y: size.height * 0.2, width: size.width, height: size.height * 0.8))
        
        // Screen
        context.setFillColor(screenColor.cgColor)
        context.fill(CGRect(x: 2, y: size.height * 0.25, width: size.width - 4, height: size.height * 0.7))
        
        // Stand
        context.setFillColor(frameColor.cgColor)
        context.fill(CGRect(x: size.width * 0.4, y: size.height * 0.1, width: size.width * 0.2, height: size.height * 0.15))
        
        // Base
        context.fill(CGRect(x: size.width * 0.25, y: 0, width: size.width * 0.5, height: size.height * 0.1))
        
        image.unlockFocus()
        return image
    }
}

// MARK: - Color Extensions

extension NSColor {
    func darker(by percentage: CGFloat = 0.2) -> NSColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return NSColor(hue: h, saturation: s, brightness: max(b - percentage, 0), alpha: a)
    }
    
    func lighter(by percentage: CGFloat = 0.2) -> NSColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return NSColor(hue: h, saturation: s, brightness: min(b + percentage, 1), alpha: a)
    }
    
    convenience init(_ color: Color) {
        self.init(color)
    }
}

// MARK: - SwiftUI Image Extension

extension Image {
    init(nsImage: NSImage) {
        self.init(nsImage: nsImage)
    }
}
