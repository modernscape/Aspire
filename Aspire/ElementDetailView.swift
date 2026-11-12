import SwiftUI
import SwiftData
import UIKit

struct ElementDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var element: ElementItem
    @Query(sort: \ElementItem.title) private var allElements: [ElementItem]
    
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
                    
                    // 快楽／不快 (Segmented Control)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Positive／Negative")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        UIKitSegmentedControl(
                            items: ["Positive", "Negative"],
                            selection: Binding(
                                get: { element.isPleasure ? 0 : 1 },
                                set: { element.isPleasure = ($0 == 0) }
                            ),
                            selectedColor: UIColor(named: element.isPleasure ? "Pleasuse Color" : "Unpleasant Color") ?? .systemBlue
                        )
                        .frame(height: 36) // 文字が2行になる場合を考慮して少し高さを調整してもOKです
                        
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
                                    element.impact = max(5, min(500, rounded))
                                }
                            ),
                            in: 5...500, // 5からスタート
                            step: 5
                        )
                    }
                    .padding(.vertical, 4)
                    
                    // 状態（現状 / 未来）の切り替え
                    VStack(alignment: .leading, spacing: 6) {
                        Text("状態")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        UIKitSegmentedControl(
                            items: ["現状", "未来（それを選択する）"],
                            selection: Binding(
                                get: { element.isDream ? 1 : 0 },
                                set: { element.isDream = ($0 == 1) }
                            ),
                            selectedColor: element.isDream
                            ? (UIColor(named: "Active Color") ?? .systemBlue)
                            : .systemGray
                        )
                        .frame(height: 32)
                    }
                    .padding(.vertical, 4)
                    
                    // 「この条件をやめる」トグル
                    Toggle("やめる・やめたい・やらない", isOn: $element.stop)
                        .tint(.red)
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
                                HStack {
                                    Circle()
                                        .fill(candidate.isPleasure ? Color("Pleasuse Color") : Color("Unpleasant Color"))
                                        .frame(width: 14, height: 14)
                                    
                                    Text(candidate.title.isEmpty ? "(無題の条件)" : candidate.title)
                                        .foregroundStyle(.primary)
                                    
                                    Spacer()
                                    
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.tint)
                                            .fontWeight(.semibold)
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
        HStack {
            self
            if !text.wrappedValue.isEmpty {
                Button {
                    text.wrappedValue = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
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
