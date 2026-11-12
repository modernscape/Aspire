import SwiftUI

struct ArrowView: View {
    let from: CGPoint
    let fromRadius: CGFloat
    let to: CGPoint
    let toRadius: CGFloat
    
    var body: some View {
        Canvas { context, _ in
            let dx = to.x - from.x
            let dy = to.y - from.y
            let distance = hypot(dx, dy)
            
            // 2つの円が重なりすぎている場合は矢印を描画しない
            guard distance > (fromRadius + toRadius + 8) else { return }
            
            let angle = atan2(dy, dx)
            
            // 円のフチ（少し余白4ptを持たせる）の始点と終点
            let startPoint = CGPoint(
                x: from.x + cos(angle) * (fromRadius + 4),
                y: from.y + sin(angle) * (fromRadius + 4)
            )
            let endPoint = CGPoint(
                x: to.x - cos(angle) * (toRadius + 6),
                y: to.y - sin(angle) * (toRadius + 6)
            )
            
            // 線の描画
            var linePath = Path()
            linePath.move(to: startPoint)
            linePath.addLine(to: endPoint)
            context.stroke(
                linePath,
                with: .color(.secondary.opacity(0.75)),
                style: StrokeStyle(lineWidth: 2, lineCap: .round)
            )
            
            // 矢じり（三角形）の描画
            let arrowLength: CGFloat = 12
            let arrowAngle: CGFloat = .pi / 6 // 30度
            
            let arrowPoint1 = CGPoint(
                x: endPoint.x - arrowLength * cos(angle - arrowAngle),
                y: endPoint.y - arrowLength * sin(angle - arrowAngle)
            )
            let arrowPoint2 = CGPoint(
                x: endPoint.x - arrowLength * cos(angle + arrowAngle),
                y: endPoint.y - arrowLength * sin(angle + arrowAngle)
            )
            
            var headPath = Path()
            headPath.move(to: endPoint)
            headPath.addLine(to: arrowPoint1)
            headPath.addLine(to: arrowPoint2)
            headPath.closeSubpath()
            
            context.fill(headPath, with: .color(.secondary.opacity(0.9)))
        }
        // ★ここが重要：描画領域を画面全体に広げることで、どれだけ離れても矢印が切れません
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false) // 矢印がタップやドラッグを邪魔しないようにする
    }
}
