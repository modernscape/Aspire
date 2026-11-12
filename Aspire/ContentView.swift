import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var elements: [ElementItem]
    
    @State private var canvasOffset: CGSize = .zero
    @State private var lastCanvasOffset: CGSize = .zero
    @State private var canvasScale: CGFloat = 1.0
    @State private var lastCanvasScale: CGFloat = 1.0
    
    @State private var editingElement: ElementItem?
    
    private let minScale: CGFloat = 0.3
    private let maxScale: CGFloat = 2.5
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Color(.systemGroupedBackground)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .gesture(canvasPanGesture)
                    
                    ZStack {
                        // 矢印レイヤー
                        ForEach(elements) { element in
                            ForEach(element.factors) { factor in
                                ArrowView(
                                    from: factor.position,
                                    fromRadius: factor.radius,
                                    to: element.position,
                                    toRadius: element.radius
                                )
                            }
                        }
                        
                        // 条件ノードレイヤー
                        ForEach(elements) { element in
                            ElementNodeView(element: element) {
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                                editingElement = element
                            }
                        }
                    }
                    .scaleEffect(canvasScale)
                    .offset(canvasOffset)
                }
                .simultaneousGesture(canvasZoomGesture)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        // 【変更】押すとすべての要素が画面に収まるように自動フィットするボタン
                        Button {
                            withAnimation(.spring(duration: 0.4)) {
                                fitToAllElements(in: geometry.size)
                            }
                        } label: {
                            Image(systemName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
                        }
                        .disabled(elements.isEmpty)
                    }
                    
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            addNewElement(in: geometry.size)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                    }
                }
                .sheet(item: $editingElement) { element in
                    ElementDetailView(element: element)
                }
            }
            .navigationTitle("現状と夢の条件を整理する")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - 全体フィット計算ロジック（修正版）
    private func fitToAllElements(in viewSize: CGSize) {
        guard !elements.isEmpty else {
            canvasScale = 1.0
            lastCanvasScale = 1.0
            canvasOffset = .zero
            lastCanvasOffset = .zero
            return
        }
        
        // 1. すべての要素を包み込むバウンディングボックスを算出
        var minX = CGFloat.infinity
        var maxX = -CGFloat.infinity
        var minY = CGFloat.infinity
        var maxY = -CGFloat.infinity
        
        for element in elements {
            let r = element.radius
            let left = element.position.x - r
            let right = element.position.x + r
            let top = element.position.y - r
            let bottom = element.position.y + r
            
            minX = min(minX, left)
            maxX = max(maxX, right)
            minY = min(minY, top)
            maxY = max(maxY, bottom)
        }
        
        // 周囲の余白を少し広めに確保 (80pt)
        let padding: CGFloat = 80
        minX -= padding
        maxX += padding
        minY -= padding
        maxY += padding
        
        let contentWidth = max(maxX - minX, 100)
        let contentHeight = max(maxY - minY, 100)
        
        // 2. 画面サイズ（余白考慮）に収まるようなスケールを計算
        let scaleX = viewSize.width / contentWidth
        let scaleY = viewSize.height / contentHeight
        let targetScale = min(max(min(scaleX, scaleY), minScale), maxScale)
        
        // 3. コンテンツの本当の中心座標
        let contentCenterX = (minX + maxX) / 2.0
        let contentCenterY = (minY + maxY) / 2.0
        
        // 4. 画面の中心に対してオフセットを計算
        // ※ GeometryReaderの中での中央を基準にするため、位置のずれを補正
        let targetOffsetX = (viewSize.width / 2.0) - (contentCenterX * targetScale)
        let targetOffsetY = (viewSize.height / 2.0) - (contentCenterY * targetScale)
        
        // 5. 反映
        canvasScale = targetScale
        lastCanvasScale = targetScale
        canvasOffset = CGSize(width: targetOffsetX, height: targetOffsetY)
        lastCanvasOffset = canvasOffset
    }
    
    // MARK: - ジェスチャー定義
    private var canvasPanGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                canvasOffset = CGSize(
                    width: lastCanvasOffset.width + value.translation.width,
                    height: lastCanvasOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastCanvasOffset = canvasOffset
            }
    }
    
    private var canvasZoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let newScale = lastCanvasScale * value.magnification
                canvasScale = min(max(newScale, minScale), maxScale)
            }
            .onEnded { _ in
                lastCanvasScale = canvasScale
            }
    }
    
    private func addNewElement(in viewSize: CGSize) {
        let centerX = (viewSize.width / 2.0 - canvasOffset.width) / canvasScale
        let centerY = (viewSize.height / 2.0 - canvasOffset.height) / canvasScale
        var targetPos = CGPoint(x: centerX, y: centerY)
        
        var attempts = 0
        while elements.contains(where: { hypot($0.position.x - targetPos.x, $0.position.y - targetPos.y) < 35 }) && attempts < 20 {
            targetPos.x += 24
            targetPos.y += 24
            attempts += 1
        }
        
        let newElement = ElementItem(
            title: "条件",
            impact: 60,
            isPleasure: true,
            isDream: false,
            stop: false,
            position: targetPos
        )
        modelContext.insert(newElement)
    }
}

struct ElementNodeView: View {
    @Bindable var element: ElementItem
    var onDoubleTap: () -> Void
    
    @State private var dragStartPosition: CGPoint?
    // ダブルタップした瞬間に光らせるための状態
    @State private var isSelectedEffect = false
    
    private var themeColor: Color {
        element.isPleasure ? Color("Pleasuse Color") : Color("Unpleasant Color")
    }
    
    var body: some View {
        ZStack {
            // 背景色
            Circle()
                .fill(Color("Element bgColor"))
                .shadow(color: .black.opacity(0.08), radius: 5, x: 0, y: 2)
            
            // 外枠（1重目）
            Circle()
                .strokeBorder(themeColor, lineWidth: 2.5)
            
            // isDreamがtrueの場合は2重ライン
            if element.isDream {
                Circle()
                    .strokeBorder(themeColor, lineWidth: 2)
                    .padding(6)
            }
            
            // タイトル
            Text(element.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(themeColor)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(element.isDream ? 16 : 12)
            
            // stopがtrueのとき、円形全体を覆う大きな「×」を表示
            if element.stop {
                Image(systemName: "xmark")
                    .font(.system(size: element.diameter * 1.65))
                    .foregroundStyle(Color.red.opacity(0.5))
                    .allowsHitTesting(false)
            }
            
            // 【追加】ダブルタップされた時にラップする薄いブルーの演出用レイヤー
            Circle()
                .fill(Color.blue.opacity(isSelectedEffect ? 0.25 : 0.0))
                .scaleEffect(isSelectedEffect ? 1.05 : 0.95)
                .animation(.easeInOut(duration: 0.15), value: isSelectedEffect)
                .allowsHitTesting(false)
        }
        .frame(width: element.diameter, height: element.diameter)
        .position(element.position)
        // ダブルタップで詳細画面表示 ＋ 選択エフェクト
        .onTapGesture(count: 2) {
            // 選択エフェクトをパッと光らせてからアクションを実行
            isSelectedEffect = true
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            // 少しだけエフェクトを見せてからモーダルを開く
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isSelectedEffect = false
                onDoubleTap()
            }
        }
        // ドラッグで移動
        .gesture(
            DragGesture()
                .onChanged { value in
                    if dragStartPosition == nil {
                        dragStartPosition = element.position
                    }
                    if let start = dragStartPosition {
                        element.position = CGPoint(
                            x: start.x + value.translation.width,
                            y: start.y + value.translation.height
                        )
                    }
                }
                .onEnded { _ in
                    dragStartPosition = nil
                }
        )
    }
}
