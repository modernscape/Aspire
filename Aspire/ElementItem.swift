import Foundation
import CoreGraphics
import SwiftData
import SwiftUI

@Model
final class ElementItem {
    var id: UUID
    var title: String
    var impact: Int
    var isPleasure: Bool // Posi Nega
    var isDream: Bool
    var isCurrent: Bool = true
    var isRational: Bool = false
    var stop: Bool // 追加：「この条件をやめる」フラグ
    
    // CGPointをSwiftDataで永続化するためのX, Y座標
    var positionX: Double
    var positionY: Double
    
    // 原因となる要素（子）の配列
    @Relationship(deleteRule: .nullify, inverse: \ElementItem.dependentElements)
    var factors: [ElementItem]
    
    // この要素をfactorとして参照している要素（親）の配列
    var dependentElements: [ElementItem]
    
//    var type: Int = 0        // 0: 夢, 1: 努力, 2: ストレス // positive rational negative
    
    var position: CGPoint {
        get { CGPoint(x: positionX, y: positionY) }
        set {
            positionX = newValue.x
            positionY = newValue.y
        }
    }
    
    /// impact (1〜200) から円の直径を算出
    var diameter: CGFloat {
        let clamped = CGFloat(min(max(impact, 1), 500))
        return 60.0 + (clamped - 1.0) * (160.0 / 199.0)
    }
    
    var radius: CGFloat {
        diameter / 2.0
    }
    
    init(
        title: String = "新しい条件",
        impact: Int = 50,
        isPleasure: Bool = true,
        isDream: Bool = false,
        stop: Bool = false,
        position: CGPoint = .zero,
        factors: [ElementItem] = [],
        isCurrent: Bool = true,
    ) {
        self.id = UUID()
        self.title = title
        self.impact = impact
        self.isPleasure = isPleasure
        self.isDream = isDream
        self.stop = stop
        self.positionX = position.x
        self.positionY = position.y
        self.factors = factors
        self.dependentElements = []
        self.isCurrent = isCurrent
    }
    
    /// 循環参照チェック
    func canAddAsFactor(_ candidate: ElementItem) -> Bool {
        if candidate.id == self.id { return false }
        return !hasAncestor(candidate, visited: [])
    }
    
    private func hasAncestor(_ target: ElementItem, visited: Set<UUID>) -> Bool {
        if visited.contains(self.id) { return false }
        var nextVisited = visited
        nextVisited.insert(self.id)
        
        for parent in dependentElements {
            if parent.id == target.id { return true }
            if parent.hasAncestor(target, visited: nextVisited) { return true }
        }
        return false
    }
    
    // ★ typeに応じた背景色を返す計算プロパティ
    var nodeBackgroundColor: Color {
        return isPleasure ? Color("Pleasuse Color") : Color("Unpleasant Color")
    }
    
  
}
