import SwiftUI

struct ArrowView: View {
    let from: CGPoint
    let fromRadius: CGFloat
    let to: CGPoint
    let toRadius: CGFloat
    
    var body: some View {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let distance = hypot(dx, dy)
        
        // 2つの円が重なりすぎている場合は描画しない
        let minDistance = fromRadius + toRadius + 8
        if distance > minDistance {
            let angle = atan2(dy, dx)
            
            // 円のフチの始点と終点
            let startPoint = CGPoint(
                x: from.x + cos(angle) * (fromRadius + 4),
                y: from.y + sin(angle) * (fromRadius + 4)
            )
            let endPoint = CGPoint(
                x: to.x - cos(angle) * (toRadius + 6),
                y: to.y - sin(angle) * (toRadius + 6)
            )
            
            ZStack {
                // 1. 直線の描画
                Path { path in
                    path.move(to: startPoint)
                    path.addLine(to: endPoint)
                }
                .stroke(
                    Color.secondary.opacity(0.75),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                
                // 2. 矢じり（三角形）の描画
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
                
                Path { path in
                    path.move(to: endPoint)
                    path.addLine(to: arrowPoint1)
                    path.addLine(to: arrowPoint2)
                    path.closeSubpath()
                }
                .fill(Color.secondary.opacity(0.9))
            }
        }
    }
}
