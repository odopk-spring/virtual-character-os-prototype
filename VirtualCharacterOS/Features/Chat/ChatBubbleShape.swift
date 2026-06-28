import SwiftUI

/// 聊天气泡 shape，支持左侧/右侧小尖角 tail。
struct ChatBubbleShape: Shape {
    let side: BubbleSide
    let cornerRadius: CGFloat
    let tailWidth: CGFloat
    let tailHeight: CGFloat
    let tailOffset: CGFloat

    enum BubbleSide {
        case left, right
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = cornerRadius
        let tw = tailWidth
        let th = tailHeight
        let to = tailOffset

        if side == .left {
            // 尖角在左侧边缘
            let tailTip = CGPoint(x: rect.minX, y: to + th / 2)
            let tailTop = CGPoint(x: rect.minX + tw, y: to)
            let tailBottom = CGPoint(x: rect.minX + tw, y: to + th)

            path.move(to: tailTip)
            path.addLine(to: tailTop)
            path.addLine(to: CGPoint(x: rect.minX + tw, y: rect.minY + r))
            path.addArc(center: CGPoint(x: rect.minX + tw + r, y: rect.minY + r),
                        radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
            path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
            path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.minY + r),
                        radius: r, startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
            path.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r),
                        radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            path.addLine(to: CGPoint(x: rect.minX + tw + r, y: rect.maxY))
            path.addArc(center: CGPoint(x: rect.minX + tw + r, y: rect.maxY - r),
                        radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            path.addLine(to: tailBottom)
        } else {
            // 尖角在右侧边缘
            let tailTip = CGPoint(x: rect.maxX, y: to + th / 2)
            let tailTop = CGPoint(x: rect.maxX - tw, y: to)
            let tailBottom = CGPoint(x: rect.maxX - tw, y: to + th)

            path.move(to: tailTip)
            path.addLine(to: tailTop)
            path.addLine(to: CGPoint(x: rect.maxX - tw, y: rect.minY + r))
            path.addArc(center: CGPoint(x: rect.maxX - tw - r, y: rect.minY + r),
                        radius: r, startAngle: .degrees(0), endAngle: .degrees(270), clockwise: true)
            path.addLine(to: CGPoint(x: rect.minX + r, y: rect.minY))
            path.addArc(center: CGPoint(x: rect.minX + r, y: rect.minY + r),
                        radius: r, startAngle: .degrees(270), endAngle: .degrees(180), clockwise: true)
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - r))
            path.addArc(center: CGPoint(x: rect.minX + r, y: rect.maxY - r),
                        radius: r, startAngle: .degrees(180), endAngle: .degrees(90), clockwise: true)
            path.addLine(to: CGPoint(x: rect.maxX - tw - r, y: rect.maxY))
            path.addArc(center: CGPoint(x: rect.maxX - tw - r, y: rect.maxY - r),
                        radius: r, startAngle: .degrees(90), endAngle: .degrees(0), clockwise: true)
            path.addLine(to: tailBottom)
        }

        path.closeSubpath()
        return path
    }
}
