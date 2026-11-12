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
    
    @State private var dragStartPosition: CGPoint?
    // ダブルタップした瞬間に光らせるための状態
    @State private var isSelectedEffect = false
    
    // ピンチ操作用の一時変数
    @State private var baseImpact: Int = 60
    
    private var themeColor: Color {
        element.isPleasure ? Color("Pleasuse Color") : Color("Unpleasant Color")
    }
    
    var body: some View {
        ZStack {
            // 背景色
            Circle()
                .fill(element.isDream ? Color("Element bgColor") : themeColor.opacity(0.12))
                .shadow(color: .black.opacity(0.08), radius: 5, x: 0, y: 2)
                .overlay(
                    // ★ 選択時に薄い青色を被せる
                    Circle().fill(Color.blue.opacity(isSelected ? 0.25 : 0.0))
                )
                // 選択時は青い枠線もつけるとさらに分かりやすいです
                .overlay(
                    Circle().stroke(Color.blue, lineWidth: isSelected ? 3 : 0)
                )
                .shadow(color: .black.opacity(0.08), radius: 5, x: 0, y: 2)
            
            if element.isDream {
                // 外枠（1重目）
                Circle()
                    .strokeBorder(
                        themeColor,
                        style: StrokeStyle(lineWidth: 4, dash: [20, 5]) // ← ここで点線を指定
                    )
            
                
//                Circle()
//                    .strokeBorder(
//                        themeColor,
//                        style: StrokeStyle(lineWidth: 2, dash: [15, 3]) // ← ここで点線を指定
//                    )
//                    .opacity(0.8)
//                    .padding(8)
                
                
                
                
            } else {
                // 外枠（1重目）
                Circle()
                    .strokeBorder(themeColor, lineWidth: element.isDream  ? 4 : 2)
                
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
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(themeColor)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(element.isDream ? 16 : 12)
            
            // 【追加】円の上部に impact の値を表示
            Text("\(element.impact)")
                .font(.system(size: 11, weight: .thin, design: .rounded))
                .foregroundStyle(themeColor.opacity(0.8))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .offset(y: -(element.diameter / 2) + 14) // 円の上端付近に配置
                .allowsHitTesting(false)
            
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
        // ★ シングルタップとダブルタップを競合させずに両立させるジェスチャー
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
        .gesture(
            MagnifyGesture()
                .onChanged { value in
                    if baseImpact == 0 { baseImpact = element.impact }
                    let newImpact = Double(baseImpact) * value.magnification
                    // 5〜200の範囲で、5刻みに丸める
                    let clamped = min(max(Int(newImpact), 5), 500)
                    element.impact = (clamped / 5) * 5
                }
                .onEnded { _ in
                    baseImpact = 0
                }
        )
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

