import SwiftUI
import SwiftData
import UIKit
import PhotosUI

struct ElementDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var element: ElementItem
    @Query(sort: \ElementItem.title) private var allElements: [ElementItem]
    
    @State private var selectedItem: PhotosPickerItem?
    
    // リスト下部から新しい条件を作って追加するためのコールバック
    var onCreateAndLinkNew: (() -> Void)? = nil
    
    @State private var showDeleteAlert = false
    
    private var selectableFactors: [ElementItem] {
        allElements.filter { candidate in
            candidate.id != element.id && (
                element.factors.contains(where: { $0.id == candidate.id }) ||
                element.canAddAsFactor(candidate)
            )
        }
        // impactの大きい順（降順）にソート
        .sorted { $0.impact > $1.impact }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // 基本情報
                Section() {
                    TextField("タイトル", text: $element.title, axis: .vertical)
                        .lineLimit(1...4)
                        .clearButton(text: $element.title)
                    
                    //
                    Toggle("これこそが夢", isOn: $element.isDream)
                        .tint(Color("Dream Color"))
                    
                    
                    
                    // 快楽／不快 (Segmented Control)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Positive／Negative")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        UIKitSegmentedControl(
                            items: ["Positive", "Negative"],
                            selection: Binding(
                                get: { element.isPleasure ? 0 : 1 }, // Boolをインデックス(0 or 1)に変換
                                set: { element.isPleasure = ($0 == 0) } // インデックスをBoolに変換
                            ),
                            selectedColor: {
                                // isPleasure に応じた UIColor を返す
                                let colorName = element.isPleasure ? "Pleasuse Color" : "Unpleasant Color"
                                return UIColor(named: colorName) ?? .systemBlue
                            }()
                        )
                        .frame(height: 36)
                        
                        // 左右それぞれの説明テキスト
                        HStack(alignment: .top, spacing: 12) {
                            // 左側（プラス）の説明
                            VStack(alignment: .leading, spacing: 2) {
                                Text("快楽・夢・楽しみ・持ってるもの・能力・欲しいもの・目標")
                                Text("幸せなこと・好きなこと")
                            }
                            .foregroundColor(Color("Pleasuse Color" ))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // 右側（マイナス）の説明
                            VStack(alignment: .leading, spacing: 2) {
                                Text("労力・コスト・ストレス・不快なこと・持ってないもの・悩み・いらないもの・嫌いなもの")
//                                Text("持ってないもの・悩み・いらないもの")
                            }
                            .foregroundColor(Color("Unpleasant Color" ))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 4)
                        .padding(.top, 2)
                    }
                    .padding(.vertical, 4)
                    
                    // 度合い（スライダー5刻み ＆ 数値直接入力 ＆ 比例反映）
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("度合い・大きさ")
                            Spacer()
                            // 数値を直接入力できるフィールド
                            TextField("値", value: $element.impact, formatter: NumberFormatter())
                                .keyboardType(.numberPad)
                                .monospacedDigit()
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                                .padding(4)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        
                        Slider(
                            value: Binding(
                                get: { Double(element.impact) },
                                set: { newValue in
                                    // 5刻みに丸める（範囲は5〜200）
                                    let rounded = Int(round(newValue / 5.0) * 5.0)
                                    element.impact = max(100, min(500, rounded))
                                }
                            ),
                            in: 100...500, // 50からスタート
                            step: 5
                        )
                    }
                    .padding(.vertical, 4)
                    
                    
                    
                    //
                    Toggle("理性的", isOn: $element.isRational)
                        .tint(Color("Rational Color"))
                    
                    
            
                    
                    
                    // 状態（現状 / 未来）の切り替え
                    VStack(alignment: .leading, spacing: 6) {
                        Text("状態")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        UIKitSegmentedControl(
                            items: ["現状", "未来（まだその状態にない）"],
                            selection: Binding(
                                get: { element.isCurrent ? 0 : 1 },
                                set: { element.isCurrent = ($0 == 0) }
                            ),
                            selectedColor: element.isCurrent
                            ? .systemGray : (UIColor(named: "Active Color") ?? .systemBlue)
                            
                        )
                        .frame(height: 32)
                    }
                    .padding(.vertical, 4)
                    
                    // 「この条件をやめる」トグル
                    Toggle("やめる・やめたい・やらない", isOn: $element.stop)
                        .tint(.red)
                    
    
                }
                

                PhotosPicker(selection: $selectedItem, matching: .images) {
                    if let imageData = element.imageData, let uiImage = UIImage(data: imageData) {
                        // 行の中央に配置するためのHStackとSpacer
                        HStack {
                            Spacer()
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit() // 元画像のアスペクト比を維持して全体を表示
                                .frame(maxHeight: 220) // 大きめの表示サイズ（必要に応じて調整してください）
                                .cornerRadius(10) // 四角形（少し角丸にすると綺麗です。直角が良い場合は削除してください）
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            Spacer()
                        }
                        .padding(.vertical, 6)
                    } else {
                        Label("画像を追加", systemImage: "photo.badge.plus")
                    }
                }
                .onChange(of: selectedItem) { _, newItem in
                    guard let newItem else { return }
                    Task {
                        if let data = try? await newItem.loadTransferable(type: Data.self) {
                            await MainActor.run {
                                element.imageData = data
                            }
                        }
                    }
                }
                
                if element.imageData != nil {
                    Button("画像を削除", role: .destructive) {
                        element.imageData = nil
                        selectedItem = nil // 選択状態もリセット
                    }
                }
                
                
                // Factors（原因となる条件の複数選択 ＋ 最後に＋ボタン）
                Section {
                    if selectableFactors.isEmpty {
                        Text("選択できる他の条件がありません")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(selectableFactors) { candidate in
                            let isSelected = element.factors.contains(where: { $0.id == candidate.id })
                            
                            Button {
                                toggleFactor(candidate)
                            } label: {
                                HStack(spacing: 12) {
                                    // 左端の色丸 ＋ 小さな×
                                    ZStack {
                                        Circle()
                                            .fill(candidate.isPleasure ? Color("Pleasuse Color") : Color("Unpleasant Color"))
                                            .frame(width: 12, height: 12)
                                            .padding(4)
                                        
                                        if candidate.isRational {
                                            Circle()
                                                .strokeBorder(Color("Rational Color"), lineWidth: 3)
//                                                .fill(Color("Rational Color"))
                                                .frame(width: 20, height: 20)
          
                                            
                                        }
                                        
//                                        if candidate.stop {
//                                            Image(systemName: "xmark")
//                                                .font(.system(size: 17))
//                                                .foregroundStyle(.white).opacity(0.7)
//                                        }
                                    }
                                    
                                    // タイトル（stopがtrueのときに取り消し線を引く）
                                    Text(candidate.title)
                                        .strikethrough(candidate.stop)
                                    
                                    Spacer()
                                    
                                    // ★ 2. 選択されている場合のみ右側にチェックマークを表示
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.accentColor) // または .blue など
                                    }
                                }
                            }
                        }
                    }
                    
                    // リストの最後に新規作成「＋」ボタンを配置
                    if let onCreateAndLinkNew {
                        Button {
                            onCreateAndLinkNew()
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                                Text("新しい条件")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                } header: {
                    Text("実現のために必要なのは？")
                } footer: {
                    Text("選択した条件から、この条件に向かって矢印が引かれます。")
                }
                
                // 削除セクション
                Section {
                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("この条件を削除")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("条件の詳細")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 左上にキャンセルボタンを配置
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        // 画面を閉じる処理（例: dismiss()）
//                        dismiss() // 環境変数 @Environment(\.dismiss) var dismiss が必要です
                        
                        // タイトルが空、または新規作成時のものなど、必要に応じて削除
                        let trimmedTitle = element.title.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmedTitle.isEmpty {
                            modelContext.delete(element)
                        }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        dismiss()
                    }
                }
            }
            .alert("条件を削除しますか？", isPresented: $showDeleteAlert) {
                Button("削除", role: .destructive) {
                    deleteElement()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("この操作は取り消せません。つながっている矢印も削除されます。")
            }
        }
    }
    
    private func toggleFactor(_ candidate: ElementItem) {
        if let index = element.factors.firstIndex(where: { $0.id == candidate.id }) {
            element.factors.remove(at: index)
        } else {
            element.factors.append(candidate)
        }
    }
    
    private func deleteElement() {
        element.factors.removeAll()
        element.dependentElements.removeAll()
        modelContext.delete(element)
        dismiss()
    }
}



// 便利なTextField用クリアボタン拡張
extension View {
    func clearButton(text: Binding<String>) -> some View {
        HStack(alignment: .top, spacing: 6) {
            self
            if !text.wrappedValue.isEmpty {
                Button {
                    text.wrappedValue = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain) // ★ これにより、タップ領域がアイコンだけに限定されます
            }
        }
    }
}


struct UIKitSegmentedControl: UIViewRepresentable {
    var items: [String]
    @Binding var selection: Int
    var selectedColor: UIColor
    
    func makeUIView(context: Context) -> UISegmentedControl {
        let segmentedControl = UISegmentedControl(items: items)
        segmentedControl.selectedSegmentIndex = selection
        segmentedControl.addTarget(context.coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
        
        segmentedControl.selectedSegmentTintColor = selectedColor
        
        let normalAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 14, weight: .medium)
        ]
        let selectedAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 14, weight: .bold)
        ]
        
        segmentedControl.setTitleTextAttributes(normalAttributes, for: .normal)
        segmentedControl.setTitleTextAttributes(selectedAttributes, for: .selected)
        
        return segmentedControl
    }
    
    func updateUIView(_ uiView: UISegmentedControl, context: Context) {
        if uiView.selectedSegmentIndex != selection {
            uiView.selectedSegmentIndex = selection
        }
        uiView.selectedSegmentTintColor = selectedColor
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: UIKitSegmentedControl
        
        init(_ parent: UIKitSegmentedControl) {
            self.parent = parent
        }
        
        @objc func valueChanged(_ sender: UISegmentedControl) {
            parent.selection = sender.selectedSegmentIndex
        }
    }
}
