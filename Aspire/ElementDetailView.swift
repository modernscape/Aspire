import SwiftUI
import SwiftData
import UIKit


struct ElementDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var element: ElementItem
    @Query(sort: \ElementItem.title) private var allElements: [ElementItem]
    
    @State private var showDeleteAlert = false
    
    private var selectableFactors: [ElementItem] {
        allElements.filter { candidate in
            element.factors.contains(where: { $0.id == candidate.id }) ||
            element.canAddAsFactor(candidate)
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // 基本情報
                Section() {
                    TextField("タイトル", text: $element.title, axis: .vertical)
                        .lineLimit(1...4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("度合い（インパクト）")
                            Spacer()
                            Text("\(element.impact)")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(element.impact) },
                                set: { element.impact = Int($0.rounded()) }
                            ),
                            in: 1...200,
                            step: 1
                        )
                    }
                    .padding(.vertical, 4)
                    
                    // 快楽／不快 (Segmented Control)
                    // 例：快楽・不快の切り替え
                    VStack(alignment: .leading, spacing: 6) {
                        Text("快楽・不快")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        UIKitSegmentedControl(
                            items: ["＋（快楽・希求）", "ー （コスト・労力・不快）"],
                            selection: Binding(
                                get: { element.isPleasure ? 0 : 1 },
                                set: { element.isPleasure = ($0 == 0) }
                            ),
                            selectedColor: UIColor(named: element.isPleasure ? "Pleasuse Color" : "Unpleasant Color") ?? .systemBlue
                        )
                        .frame(height: 32)
                    }
                    .padding(.vertical, 4)
//                    VStack(alignment: .leading, spacing: 6) {
//                        Text("快楽・不快")
//                            .font(.caption)
//                            .foregroundStyle(.secondary)
//                        
//                        HStack(spacing: 0) {
//                            // 「快」ボタン
//                            Button {
//                                withAnimation(.snappy(duration: 0.2)) {
//                                    element.isPleasure = true
//                                }
//                            } label: {
//                                Text("快楽")
//                                    .font(.subheadline.bold())
//                                    .frame(maxWidth: .infinity)
//                                    .padding(.vertical, 8)
//                                    .background(element.isPleasure ? Color("Pleasuse Color") : Color.clear)
//                                    .foregroundStyle(element.isPleasure ? .white : .primary)
//                            }
//                            
//                            Divider().frame(height: 20)
//                            
//                            // 「不快」ボタン
//                            Button {
//                                withAnimation(.snappy(duration: 0.2)) {
//                                    element.isPleasure = false
//                                }
//                            } label: {
//                                Text("不快")
//                                    .font(.subheadline.bold())
//                                    .frame(maxWidth: .infinity)
//                                    .padding(.vertical, 8)
//                                    .background(!element.isPleasure ? Color("Unpleasant Color") : Color.clear)
//                                    .foregroundStyle(!element.isPleasure ? .white : .primary)
//                            }
//                        }
//                        .background(Color(.systemGray6))
//                        .clipShape(RoundedRectangle(cornerRadius: 8))
//                        .overlay(
//                            RoundedRectangle(cornerRadius: 8)
//                                .stroke(Color(.systemGray4), lineWidth: 0.5)
//                        )
//                    }
//                    Picker("快楽・不快", selection: $element.isPleasure) {
//                        Text("快楽").tag(true)
//                        Text("不快").tag(false)
//                    }
//                    .pickerStyle(.segmented)
//                    .padding(.vertical, 4)
//                    
                    // 希求する（夢） / 今はその状態でない (Segmented Control)
//                    Picker("状態", selection: $element.isDream) {
//                        Text("今はその状態でない").tag(false)
//                        Text("それを選択する").tag(true)
//                    }
//                    .pickerStyle(.segmented)
//                    .padding(.vertical, 4)
                    
         
                    // 状態（今はその状態でない / それを選択する）の切り替え
                    VStack(alignment: .leading, spacing: 6) {
                        Text("状態")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        UIKitSegmentedControl(
                            items: ["今はその状態でない", "それを選択する"],
                            selection: Binding(
                                get: { element.isDream ? 1 : 0 },
                                set: { element.isDream = ($0 == 1) }
                            ),
                            // isDreamがfalse（左）なら systemGray、true（右）なら "Active Color" を使用
                            selectedColor: element.isDream
                            ? (UIColor(named: "Active Color") ?? .systemBlue)
                            : .systemGray
                        )
                        .frame(height: 32)
                    }
                    .padding(.vertical, 4)
                    
                    // 「この条件をやめる」トグル
                    Toggle("これをやめる・破棄", isOn: $element.stop)
                        .tint(.red)
                }
                
                // Factors（原因となる条件の複数選択）
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
                                    
                                    Text(candidate.title)
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
            .navigationTitle("条件の編集")
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



struct UIKitSegmentedControl: UIViewRepresentable {
    var items: [String]
    @Binding var selection: Int
    var selectedColor: UIColor // 選択時の背景色（アセットの色などを指定可能）
    
    func makeUIView(context: Context) -> UISegmentedControl {
        let segmentedControl = UISegmentedControl(items: items)
        segmentedControl.selectedSegmentIndex = selection
        segmentedControl.addTarget(context.coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
        
        // 選択時の背景色を設定
        segmentedControl.selectedSegmentTintColor = selectedColor
        
        // 選択時・非選択時の文字色を設定
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
