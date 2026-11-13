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
    
    @State private var selectedElement: ElementItem? = nil
    @State private var pinchStartImpact: Int = 60 // ピンチ操作用の一時保存
        
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
            position: position,
            isCurrent: true,
        )
        modelContext.insert(newElement)
        editingElement = newElement
    }
    
    private func duplicateElement(_ item: ElementItem) {
        let duplicated = ElementItem(
            title: item.title + " (コピー)",
            impact: item.impact,
            isPleasure: item.isPleasure,
            isDream: item.isDream,
            stop: item.stop,
            position: CGPoint(x: item.position.x + 30, y: item.position.y + 30) // 少しずらして配置
        )
        modelContext.insert(duplicated)
        selectedElement = duplicated
    }
    

    
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                
                // ▼ ここにそのまま記述します
//                let doubleTap = SpatialTapGesture(count: 2)
//                    .onEnded { value in
//                        let screenLocation = value.location
//                        let worldX = (screenLocation.x - canvasOffset.width) / canvasScale
//                        let worldY = (screenLocation.y - canvasOffset.height) / canvasScale
//                        
//                        addNewElementAt(CGPoint(x: worldX, y: worldY))
//                    }
//                
//                let singleTap = SpatialTapGesture(count: 1)
//                    .onEnded { value in
//                        selectedElement = nil
//                    }
//                
//                let tapGesture = doubleTap.exclusively(before: singleTap)
                // ▲ ここまで
                
                ZStack {
                    Color(.systemGroupedBackground)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .gesture(canvasPanGesture)
//                        .simultaneousGesture(tapGesture) // 先ほど定義したダブル/シングルの複合タップ
                        .simultaneousGesture(
                            SpatialTapGesture(count: 1) // シングルタップで選択解除
                                .onEnded { value in
                                    // ノード以外の空白をタップした時だけ選択解除したい場合など
                                    selectedElement = nil
                                }
                        )
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
                            ElementNodeView(
                                element: element,
                                isSelected: (element == selectedElement),
                                onTap: {
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                    // 1回タップ：選択状態にする（下端メニューが出る）
                                    selectedElement = element
                                },
                                onDoubleTap: {
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                    // ダブルタップ：直接編集画面を開く
                                    editingElement = element
                                }
                            )
                        }
                    }
                    .scaleEffect(canvasScale)
                    .offset(canvasOffset)
                }
                .overlay(alignment: .bottom) {
                    // 3. 選択時のみ画面下端に現れるメニューバー
                    if let selected = selectedElement {
                        HStack(spacing: 20) {
                            // ① ポジ・ネガ トグル
                            Button {
                                selected.isPleasure.toggle()
                            } label: {
                                Circle()
                                    .fill(selected.isPleasure ? Color("Pleasuse Color") : Color("Unpleasant Color"))
                                    .frame(width: 32, height: 32)
                                    .overlay(Image(systemName: selected.isPleasure ? "heart.fill" : "cloud.rain.fill").font(.system(size: 12)).foregroundStyle(.white))
                            }
                            
                            // ② 子条件を選択 (モーダルやピッカーを開くなど)
                            Button {
                                // TODO: 子条件選択画面のシートを開く処理など
                            } label: {
                                Image(systemName: "arrow.triangle.branch")
                            }
                            
                            // ③ stop トグル
                            Button {
                                selected.stop.toggle()
                            } label: {
                                Image(systemName: selected.stop ? "xmark.circle.fill" : "circle")
                            }
                            
                            // ④ 編集画面へ
                            Button {
                                editingElement = selected
                            } label: {
                                Image(systemName: "pencil")
                            }
                            
                            // ⑤ 複製
                            Button {
                                duplicateElement(selected)
                            } label: {
                                Image(systemName: "plus.square.on.square")
                            }
                            
                            // ⑥ 削除
                            Button(role: .destructive) {
                                modelContext.delete(selected)
                                selectedElement = nil
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                        .font(.system(size: 20))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                        .padding(.bottom, 30)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedElement)
                    }
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

