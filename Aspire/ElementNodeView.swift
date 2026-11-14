//
//  ElementNodeView.swift
//  Aspire
//
//  Created by forest on 2026/11/12.
//

import SwiftUI
import SwiftData


struct ElementNodeView: View {
    @Bindable var element: ElementItem
    let isSelected: Bool
    let onDoubleTap: () -> Void
    let onTap: () -> Void          // シングルタップ（選択）用
    
    // イニシャライザを明示的に定義して順序を保証する（または単純にプロパティの並びを直す）
    init(element: ElementItem, isSelected: Bool, onTap: @escaping () -> Void = {}, onDoubleTap: @escaping () -> Void = {}) {
        self.element = element
        self.isSelected = isSelected
        self.onTap = onTap
        self.onDoubleTap = onDoubleTap
    }
    
    // ★ 変更1: positionを直接書き換えず、一時的な移動量（offset）だけを持つ
    @State private var dragOffset: CGSize = .zero
    @State private var baseImpact: Int = 50
    
    @State private var dragStartPosition: CGPoint?
    // ダブルタップした瞬間に光らせるための状態
    @State private var isSelectedEffect = false
    
    // ピンチ操作用の一時変数
//    @State private var baseImpact: Int = 50
    
//    private var themeColor: Color {
//        element.isPleasure ? Color("Pleasuse Color") : Color("Unpleasant Color")
//    }
    
    // ★ typeに応じた背景色を返す計算プロパティ
    private var nodeBackgroundColor: Color {
        return element.isPleasure ? Color("Pleasuse Color") : Color("Unpleasant Color")
    }
    
    enum AnimationPhase: CaseIterable {
        case start, middle, end
        var angle: Angle {
            switch self {
            case .start: return .degrees(0)
            case .middle: return .degrees(180)
            case .end: return .degrees(360)
            }
        }
    }
    
    var body: some View {
        ZStack {
            
            // 1. 一番後ろに配置する「動くグラデーション円」
            if element.isDream {
                Circle()
                    .fill(
                        AngularGradient(colors: [.pink, .purple, .blue, .cyan, .pink], center: .center)
                    )
//                    .frame(width: 250, height: 250)
                    .blur(radius: 15)
                    .phaseAnimator(AnimationPhase.allCases) { content, phase in
                        content.rotationEffect(phase.angle)
                    } animation: { _ in
                            .easeInOut(duration: 4.0)
                    }
                    .opacity(0.3)
                    .clipShape(Circle()) // 全体をきれいな円の形に切り抜く（はみ出しが消える）
            }
         
            // 背景色
            Circle()
//                .fill(element.isDream ? Color("Element bgColor") : themeColor.opacity(0.12))
                .fill(nodeBackgroundColor.opacity(element.isCurrent ? 0.23 : 0.05))
                .shadow(color: .black.opacity(0.08), radius: 5, x: 0, y: 2)
            
                .overlay(
                    // ★ 選択時に薄い青色を被せる
                    Circle().fill(Color.blue.opacity(isSelected ? 0.25 : 0.0))
                )
                // 選択時は青い枠線もつけるとさらに分かりやすいです
                .overlay(
                    Circle().stroke(Color.blue, lineWidth: isSelected ? 3 : 0)
                )
                .overlay(
                    Group {
                        if element.isRational {
                            Image("node_texture") // モノクロテクスチャ
                                .resizable()
                                .renderingMode(.template)
                                .foregroundStyle(Color("Rational Color"))
                                .opacity(0.7)
                                .clipShape(Circle())
                        }
                    }
                )
                .shadow(color: .black.opacity(0.08), radius: 5, x: 0, y: 2)
            
            if element.isCurrent {
                
                Circle()
                    .strokeBorder(nodeBackgroundColor, lineWidth: element.isCurrent  ? 4 : 2)
          
                
//                Circle()
//                    .strokeBorder(
//                        themeColor,
//                        style: StrokeStyle(lineWidth: 2, dash: [15, 3]) // ← ここで点線を指定
//                    )
//                    .opacity(0.8)
//                    .padding(8)
                
                
                
                
            } else {
 
                
                Circle()
                    .strokeBorder(
                        nodeBackgroundColor,
                        style: StrokeStyle(lineWidth: 6, dash: [20, 5]) // ← ここで点線を指定
                    )
                
                
            }

            
            // isDreamがtrueの場合は2重の点線ライン
//            if element.isDream {
//                Circle()
//                    .strokeBorder(
//                        themeColor,
//                        style: StrokeStyle(lineWidth: 2, dash: [15, 3]) // ← ここで点線を指定
//                    )
//                    .opacity(0.8)
//                    .padding(8)
//            }
            
            // タイトル
            Text(element.title)
            // ★ 円の大きさに応じてフォントサイズを可変にする（最小12ptを確保）
                .font(.system(size: max(element.diameter * 0.15, 12), weight: .semibold))
                .foregroundStyle(nodeBackgroundColor)
                .multilineTextAlignment(.center)
                .lineLimit(nil) // 行数制限なし
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: element.diameter * 0.75) // ★ 円の丸みに沿って綺麗に折り返すための幅制限
                .padding(element.isDream ? 16 : 12)
            
//            Text(element.title)
//                .font(.system(size: 40, weight: .semibold))
//                .foregroundStyle(nodeBackgroundColor)
//                .multilineTextAlignment(.center)
//                .lineLimit(nil)
//                .fixedSize(horizontal: false, vertical: true)
//                .padding(element.isDream ? 16 : 12)
//            
//            
            
            
            // 【追加】円の上部に impact の値を表示
            Text("\(element.impact)")
                .font(.system(size: 11, weight: .thin, design: .rounded))
                .foregroundStyle(nodeBackgroundColor.opacity(1.0))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
//                .background(.ultraThinMaterial)
//                .clipShape(Capsule())
                .offset(y: -(element.diameter / 2) + 14) // 円の上端付近に配置
                .allowsHitTesting(false)
            
            
       
            // 【追加】ダブルタップされた時にラップする薄いブルーの演出用レイヤー
            Circle()
                .fill(Color.blue.opacity(isSelectedEffect ? 0.25 : 0.0))
                .scaleEffect(isSelectedEffect ? 1.05 : 0.95)
                .animation(.easeInOut(duration: 0.15), value: isSelectedEffect)
                .allowsHitTesting(false)
            
            // ==========================================
            // ★ 円の内部の下側に表示する円形サムネイル
            // ==========================================
            if let imageData = element.imageData,
               let uiImage = UIImage(data: imageData) {
                // 円のサイズに応じてサムネイルも少し可変にする（最小28px 〜 最大38px）
                let thumbSize: CGFloat = min(max(element.diameter * 0.3, 28), 100)
                
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: thumbSize, height: thumbSize)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .opacity(0.9)
//                    .clipShape(Circle())
//                    .overlay(
//                        Circle().stroke(nodeBackgroundColor, lineWidth: 2) // ノードと同色の枠線
//                    )
//                    .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                // 円の内部の下側に収まるようにオフセット計算
                    .offset(y: (element.diameter / 2) - (thumbSize / 2) - 20)
                    .allowsHitTesting(false)
            }
            
            
            
            // stopがtrueのとき、太めの点線2本が交差した「×」を表示
            if element.stop {
                ZStack {
                    // 1つ目の点線バー（右肩下がり：45度回転）
                    Path { path in
                        let w = element.diameter * 1.3
                        // 高さんの中央（y: 3）に水平線を引く
                        path.move(to: CGPoint(x: 0, y: 3))
                        path.addLine(to: CGPoint(x: w, y: 3))
                    }
                    .stroke(Color("Cross Color"), style: StrokeStyle(lineWidth: 8, lineCap: .square, dash: [22, 15]))
                    .frame(width: element.diameter * 1.3, height: 8) // ★ ここで領域と中心を固定
                    .rotationEffect(.degrees(45))
                    
                    // 2つ目の点線バー（右肩上がり：-45度回転）
                    Path { path in
                        let w = element.diameter * 1.3
                        path.move(to: CGPoint(x: 0, y: 3))
                        path.addLine(to: CGPoint(x: w, y: 3))
                    }
                    .stroke(Color("Cross Color"), style: StrokeStyle(lineWidth: 8, lineCap: .square, dash: [22, 15]))
                    .frame(width: element.diameter * 1.3, height: 8) // ★ ここで領域と中心を固定
                    .rotationEffect(.degrees(-45))
                }
                .allowsHitTesting(false)
            }
        }
        .frame(width: element.diameter, height: element.diameter)
        
        .position(element.position)
        
        // ★ 変更3: ドラッグ中はこの offset だけで見た目だけを高速移動させる
        .offset(dragOffset)
        .gesture(
            TapGesture(count: 2)
                .onEnded {
                    let generator = UIImpactFeedbackGenerator(style: .medium)
                    generator.impactOccurred()
                    onDoubleTap() // ダブルタップ：編集画面を開く
                }
                .exclusively(
                    before: TapGesture(count: 1)
                        .onEnded {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            onTap() // シングルタップ：選択状態にする
                        }
                )
        )
        
        
        // ダブルタップで詳細画面表示 ＋ 選択エフェクト
//        .onTapGesture(count: 2) {
//            // 選択エフェクトをパッと光らせてからアクションを実行
//            isSelectedEffect = true
//            let generator = UIImpactFeedbackGenerator(style: .medium)
//            generator.impactOccurred()
//            
//            // 少しだけエフェクトを見せてからモーダルを開く
//            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
//                isSelectedEffect = false
//                onDoubleTap()
//            }
//        }
        // ★ ピンチジェスチャーで impact（サイズ）を変更
//        .gesture(
//            MagnifyGesture()
//                .onChanged { value in
//                    if baseImpact == 0 { baseImpact = element.impact }
//                    let newImpact = Double(baseImpact) * value.magnification
//                    // 5〜200の範囲で、5刻みに丸める
//                    let clamped = min(max(Int(newImpact), 50), 500)
//                    element.impact = (clamped / 5) * 5
//                }
//                .onEnded { _ in
//                    baseImpact = 0
//                }
//        )
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

