import SwiftUI
import SwiftData
import AppTrackingTransparency
import GoogleMobileAds

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var elements: [ElementItem]
    
    @State private var canvasOffset: CGSize = .zero
    @State private var lastCanvasOffset: CGSize = .zero
//    @State private var canvasScale: CGFloat = 1.0
    @State private var lastCanvasScale: CGFloat = 1.0
    
    @State private var editingElement: ElementItem?
    
    private let minScale: CGFloat = 0.1
    private let maxScale: CGFloat = 3.0
    
    @State private var selectedElement: ElementItem? = nil
    @State private var pinchStartImpact: Int = 100 // ピンチ操作用の一時保存

//     --- 1. AppStorageで永続化（アプリを落としても値が残ります） ---
    @AppStorage("savedCanvasScale") private var canvasScale: Double = 1.0
    @AppStorage("savedCanvasOffsetX") private var canvasOffsetX: Double = 0.0
    @AppStorage("savedCanvasOffsetY") private var canvasOffsetY: Double = 0.0
    
    // ★ 追加：現在キャンバスを操作中（ピンチ・パン中）かどうかのフラグ
    @State private var isCanvasInteracting: Bool = false
    
    // 初回起動が終わったかどうかを永続化（falseなら初回）
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome: Bool = false
    
    // ようこそ画面を表示しているかどうかのフラグ
    @State private var isShowingWelcome: Bool = false
    
//    private var canvasOffset: Binding<CGPoint> {
//        Binding(
//            get: { CGPoint(x: canvasOffsetX, y: canvasOffsetY) },
//            set: { newValue in
//                canvasOffsetX = newValue.width
//                canvasOffsetY = newValue.height
//            }
//        )
//    }
    
    // 1. ドラッグ開始時の基準位置を保持するStateを追加
    @State private var baseScale: Double? = nil
    @State private var baseOffset: CGSize? = nil
    @State private var zoomStartLocation: CGPoint = .zero // ★ 追加：ピンチ開始時の中心位置
    
    // 指定した座標に新しい要素を作成してすぐ詳細を開く
    private func addNewElementAt(_ position: CGPoint) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        let newElement = ElementItem(
            title: "",
            impact: 100,
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
    

    // 長押し判定用のタスクを保持するState
    @State private var longPressTask: Task<Void, Never>? = nil
    // ★ 修正：画面座標ではなく、キャンバス上のワールド座標を保持する
    @State private var longPressWorldLocation: CGPoint? = nil
    // ★ 追加：インジケーターのアニメーション用スケール
    @State private var isPressing: Bool = false
    
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                
           
                
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
                            // ★ ここでキャンバス操作中はノードのインタラクションを一時無効化する
                            .disabled(isCanvasInteracting)
                        }
                    }
                    .scaleEffect(CGFloat(canvasScale), anchor: .topLeading)
                    .offset(canvasOffset)
                    
                    
                    
                }//
                .withAdMobBanner()
                // --- 3. 再起動時の復元 ＆ 変更時の自動保存 ---
                .onAppear {
                    // 1. レイアウト確定後にウェルカム画面とキャンバス初期位置を設定
                    DispatchQueue.main.async {
                        if !hasSeenWelcome {
                            isShowingWelcome = true
                        }
                        canvasOffset = CGSize(width: canvasOffsetX, height: canvasOffsetY)
                    }
                }
                .onAppear {
                    requestTrackingAndInitializeAds()
                }
                .onChange(of: canvasOffset) { _, newValue in
                    // 動かすたびに自動でAppStorageに保存
                    canvasOffsetX = newValue.width
                    canvasOffsetY = newValue.height
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
                        HStack(spacing: 12) {
                            Button {
                                withAnimation(.spring(duration: 0.4)) {
                                    fitToAllElements(in: geometry.size)
                                }
                            } label: {
                                Image(systemName: "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left")
                            }
                            .disabled(elements.isEmpty)
                            
                            // 2. 新規追加：いつでもチュートリアルを開ける「？」ボタン
                            Button {
                                isShowingWelcome = true
                            } label: {
                                Image(systemName: "document.circle.fill")
                            }
                        }
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
                
                // --- ★ 追加：画面左上のヘルパー（チュートリアル）ボタン ---
//                VStack {
//                    HStack {
//                        Button(action: {
//                            isShowingWelcome = true
//                        }) {
//                            Image(systemName: "questionmark.circle.fill")
//                                .font(.system(size: 26))
//                                .foregroundStyle(.primary)
//                                .background(.ultraThinMaterial, in: Circle())
//                                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
//                        }
//                        .buttonStyle(.plain)
//                        .padding(.leading, 16)
//                        .padding(.top, 12)
//                        
//                        Spacer()
//                    }
//                    Spacer()
//                }
                
                // --- ★ 追加：ようこそ（チュートリアル）画面のオーバーレイ ---
                if isShowingWelcome {
                    ZStack {

                        // または、すりガラスにしたい場合はこちら：
                        Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
                        
//                        Color.black.opacity(0.4) // 0.3 〜 0.5 でお好みの暗さに調整
//                            .ignoresSafeArea()
                    
                        
                        // 背景のチュートリアル画像
                        // ※ Assets に登録した画像名（例: "TutorialBackground"）に書き換えてください
                        Image("Tutorial Image")
                            .resizable()
                            .scaledToFit() // 画面に綺麗に収まるように変更すると見やすくなります
//                            .padding(40) // 画面端に少し余裕を持たせる
//                            .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
                        
                        VStack(spacing: 20) {
                            Text("「希求」アプリへようこそ！")
                                .font(.title2)
                                .bold()
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                            
                            Text("画面をタップして閉じる")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.9))
                                .shadow(radius: 2)
                        }
                        
                        // お好みで「タップして閉じる」などの案内テキストを添える場合
//                        VStack {
//                            Spacer()
//                            Text("ようこそ 希求 アプリへ")
//                            
//                            Text("画面をタップしてはじめる")
//                                .font(.subheadline)
//                                .fontWeight(.medium)
//                                .foregroundStyle(.white)
//                                .padding(.horizontal, 20)
//                                .padding(.vertical, 10)
//                                .background(.black.opacity(0.6), in: Capsule())
//                                .padding(.bottom, 60)
//                            Spacer()
//                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
//                    .background(Color(.systemBackground)) // 画像読み込み前の仮背景
                    .ignoresSafeArea()
                    .contentShape(Rectangle()) // 画面全体をタップ可能にする
                    .onTapGesture {
                        // タップされたら非表示にし、初回フラグを true にする
                        withAnimation(.easeInOut(duration: 0.25)) {
                            hasSeenWelcome = true
                            isShowingWelcome = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(999) // 常に一番手前に表示
                }
                
                
                
            } //

            .navigationTitle("あなたをつくる要素")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
//    private func requestTrackingAndInitializeAds() {
//        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//            ATTrackingManager.requestTrackingAuthorization { status in
//                
//                // ★ ここに「あなたの実機のテストデバイスID」を登録する
//                // シミュレータの場合は自動でテスト広告になるため追加不要です
//                MobileAds.shared.requestConfiguration.testDeviceIdentifiers = [
//                    "322dcfafac9fe6cac54edd0096dad3eb" // ここにXcodeのコンソールに出る英数字のIDを入れる
//                ]
//                
//                MobileAds.shared.start(completionHandler: nil)
//            }
//        }
//    }
    
    private func requestTrackingAndInitializeAds() {
        MobileAds.shared.requestConfiguration.testDeviceIdentifiers = [
            "322dcfafac9fe6cac54edd0096dad3eb"
        ]
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            ATTrackingManager.requestTrackingAuthorization { _ in
                DispatchQueue.main.async {
                    MobileAds.shared.start(completionHandler: nil)
                }
            }
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
                // ★ 操作中フラグを立てる（指が動いている間）
                isCanvasInteracting = true
                // 2. ドラッグが始まった瞬間の（現在の）canvasOffsetを基準として保持する
                if baseOffset == nil {
                    baseOffset = canvasOffset
                }
                
                // 3. 保持した基準位置に、今回のドラッグ移動量を足し合わせる
                let currentBase = baseOffset ?? canvasOffset
                let newWidth = currentBase.width + value.translation.width
                let newHeight = currentBase.height + value.translation.height
                
                canvasOffset = CGSize(width: newWidth, height: newHeight)
            }
            .onEnded { _ in
                // 4. 指を離したら基準をリセット
                baseOffset = nil
                // ★ 指を離したらフラグを下ろす
                isCanvasInteracting = false
            }
    }
    
    private var canvasZoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                // ★ 操作中フラグを立てる
                isCanvasInteracting = true
                
                // 1. ピンチが始まった瞬間の状態を初回の1回だけキャプチャする
                if baseScale == nil {
                    baseScale = canvasScale
                    baseOffset = canvasOffset
                    zoomStartLocation = value.startLocation // ピンチし始めたときの中心点
                }
                
                let startScale = baseScale ?? canvasScale
                let startOffset = baseOffset ?? canvasOffset
                
                // 2. 新しいスケールを計算（範囲制限）
                let newScale = min(max(startScale * value.magnification, minScale), maxScale)
                
                // 3. 【重要】ピンチ開始位置（zoomStartLocation）を基点として、
                //    拡大・縮小してもその場所がズレないように新しいオフセットを逆算する
                let s = zoomStartLocation
                let scaleRatio = newScale / startScale
                
                let newWidth = s.x - (s.x - startOffset.width) * scaleRatio
                let newHeight = s.y - (s.y - startOffset.height) * scaleRatio
                
                // 4. スケールとオフセットを同時に更新
                canvasScale = newScale
                canvasOffset = CGSize(width: newWidth, height: newHeight)
            }
            .onEnded { _ in
                // 5. 指を離したらリセット
                baseScale = nil
                baseOffset = nil
                // ★ 指を離したらフラグを下ろす
                isCanvasInteracting = false
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
            impact: 100,
            isPleasure: true,
            isDream: false,
            stop: false,
            position: targetPos
        )
        modelContext.insert(newElement)
        editingElement = newElement
    }
}

