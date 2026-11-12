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
    
    // 指定した座標に新しい要素を作成してすぐ詳細を開く
    private func addNewElementAt(_ position: CGPoint) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        let newElement = ElementItem(
            title: "",
            impact: 60,
            isPleasure: true,
            isDream: false,
            stop: false,
            position: position
        )
        modelContext.insert(newElement)
        editingElement = newElement
    }
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Color(.systemGroupedBackground)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .gesture(canvasPanGesture)
                        .simultaneousGesture(
                            SpatialTapGesture(count: 2)
                                .onEnded { value in
                                    // 1. タップされた画面上の位置
                                    let screenLocation = value.location
                                    
                                    // 2. 現在のパン（オフセット）とズーム（スケール）を考慮して、キャンバス上のワールド座標に変換
                                    let worldX = (screenLocation.x - canvasOffset.width) / canvasScale
                                    let worldY = (screenLocation.y - canvasOffset.height) / canvasScale
                                    
                                    // 3. その位置に新規作成して編集画面を開く
                                    addNewElementAt(CGPoint(x: worldX, y: worldY))
                                }
                        )
                    
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
                            addNewElementAndEdit(in: geometry.size)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                    }
                }
                .sheet(item: $editingElement) { element in
                    ElementDetailView(element: element) {
                        // リスト下部の「＋新しい条件を作成して追加」が押された時の処理
                        let newFactor = ElementItem(
                            title: "",
                            impact: 50,
                            isPleasure: true,
                            isDream: false,
                            stop: false,
                            position: CGPoint(x: element.position.x + 60, y: element.position.y + 60)
                        )
                        modelContext.insert(newFactor)
                        element.factors.append(newFactor)
                    }
                }
            }
            .navigationTitle("あなたをつくる要素")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - 全体フィット計算ロジック
    private func fitToAllElements(in viewSize: CGSize) {
        guard !elements.isEmpty else {
            canvasScale = 1.0
            lastCanvasScale = 1.0
            canvasOffset = .zero
            lastCanvasOffset = .zero
            return
        }
        
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
        
        let padding: CGFloat = 80
        minX -= padding
        maxX += padding
        minY -= padding
        maxY += padding
        
        let contentWidth = max(maxX - minX, 100)
        let contentHeight = max(maxY - minY, 100)
        
        let scaleX = viewSize.width / contentWidth
        let scaleY = viewSize.height / contentHeight
        let targetScale = min(max(min(scaleX, scaleY), minScale), maxScale)
        
        let contentCenterX = (minX + maxX) / 2.0
        let contentCenterY = (minY + maxY) / 2.0
        
        let targetOffsetX = (viewSize.width / 2.0) - (contentCenterX * targetScale)
        let targetOffsetY = (viewSize.height / 2.0) - (contentCenterY * targetScale)
        
        canvasScale = targetScale
        lastCanvasScale = targetScale
        canvasOffset = CGSize(width: targetOffsetX, height: targetOffsetY)
        lastCanvasOffset = canvasOffset
    }
    
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
    
    // 新規作成してすぐ詳細を開く
    private func addNewElementAndEdit(in viewSize: CGSize) {
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
            title: "",
            impact: 60,
            isPleasure: true,
            isDream: false,
            stop: false,
            position: targetPos
        )
        modelContext.insert(newElement)
        editingElement = newElement
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
                .strokeBorder(themeColor, lineWidth: element.isDream  ? 4 : 2)
            
            // isDreamがtrueの場合は2重の点線ライン
            if element.isDream {
                Circle()
                    .strokeBorder(
                        themeColor,
                        style: StrokeStyle(lineWidth: 2, dash: [15, 3]) // ← ここで点線を指定
                    )
                    .opacity(0.8)
                    .padding(8)
            }
            
            // タイトル
            Text(element.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(themeColor)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(element.isDream ? 16 : 12)
            
            // stopがtrueのとき、細長い長方形が2つ交差した「×」を表示
            if element.stop {
                ZStack {
                    // 1つ目の長方形（右肩下がり）
                    Rectangle()
                        .frame(width: element.diameter * 1.23, height: 6) // 太さはここで調整
                        .rotationEffect(.degrees(45))
                        .foregroundStyle(Color("Cross Color"))
                    
                    // 2つ目の長方形（右肩上がり）
                    Rectangle()
                        .frame(width: element.diameter * 1.23, height: 6)
                        .rotationEffect(.degrees(-45))
                        .foregroundStyle(Color("Cross Color"))
                }
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
