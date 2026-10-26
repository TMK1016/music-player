import SwiftUI
import UniformTypeIdentifiers

struct ModeSelectionStrip: View {
    @ObservedObject var model: PlayerModel
    var useSongPolicy = false
    var compact = false
    @ViewState private var focusedMode: String?
    @ViewState private var draggedMode: String?
    var body: some View {
        VStack(spacing: 2) {
            if !compact {
                HStack {
                    Text("模式選擇").font(.subheadline.weight(.semibold))
                    Spacer(minLength: 4)
                    newModeButton
                }.frame(height: 44)
            }
            HStack(spacing: 6) {
                ScrollViewReader { reader in
                    scrollingRow
                        .onChange(of: model.customPresets.count) { old, new in
                            if new > old, let id = model.customPresets.last?.id { reader.scrollTo(id, anchor: .trailing) }
                        }
                }
                if compact { newModeButton }
            }
        }
    }
    private var scrollingRow: some View { modeRow }
    private var modeRow: some View {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(model.modeOptions) { option in
                                Button {
                                    focusedMode = option.id
                                    select(option.id)
                                } label: {
                                    Text(option.name).font(.subheadline.weight(.medium)).lineLimit(1)
                                        .padding(.horizontal, 14).frame(minHeight: 44)
                                        .foregroundStyle(model.presetName == option.name ? OrcaTheme.cyan : OrcaTheme.text)
                                        .background(model.presetName == option.name ? OrcaTheme.blue.opacity(0.25) : OrcaTheme.background, in: RoundedRectangle(cornerRadius: 10))
                                }.buttonStyle(.plain).id(option.id)
                                    .onDrag { draggedMode = option.id; return NSItemProvider(object: option.id as NSString) }
                                    .onDrop(of: [.text], delegate: ModeReorderDrop(model: model, target: option.id, dragged: $draggedMode))
                                    .contextMenu { ModeActions(model: model, option: option) }
                                    .accessibilityHint("左右滑動瀏覽；長按可調整順序、命名或移除")
                                    .accessibilityAddTraits(model.presetName == option.name ? [.isSelected] : [])
                            }
                            if !model.hiddenPresets.isEmpty { Button("還原內建") { model.restoreBuiltinModes() }.frame(minHeight: 44) }
                        }.scrollTargetLayout()
                    }.scrollTargetBehavior(.viewAligned)
                        .scrollPosition(id: $focusedMode, anchor: .center)
                        .accessibilityLabel("音效模式，左右滑動選擇")
                        .onAppear { focusedMode = model.modeOptions.first(where: { $0.name == model.presetName })?.id }
    }
    private func select(_ id: String) {
        if useSongPolicy && model.useSongProfiles { model.bindSong(to: id) }
        else { model.applyPreset(id: id) }
    }
    private var newModeButton: some View {
        Button { model.editPreset() } label: {
            Label(model.hasManualEQChanges ? "新增模式" : "自訂", systemImage: "plus")
                .font(.caption.weight(.semibold)).frame(minWidth: 64, minHeight: 44)
        }.buttonStyle(.plain).foregroundStyle(OrcaTheme.cyan)
            .disabled(model.customPresets.count >= 20)
            .accessibilityLabel(model.customPresets.count >= 20 ? "自訂模式已達20組，長按舊模式可管理" : model.hasManualEQChanges ? "儲存新模式" : "新增自訂模式")
    }
}
struct ModeActions: View {
    @ObservedObject var model: PlayerModel
    let option: ModeOption
    var body: some View {
        Button("往前移") { model.moveMode(option.id, by: -1) }.disabled(model.modeOptions.first?.id == option.id)
        Button("往後移") { model.moveMode(option.id, by: 1) }.disabled(model.modeOptions.last?.id == option.id)
        if option.isCustom {
            Button("以目前調音覆蓋") { model.updatePreset(option.id) }
            Button("重新命名") { model.editPreset(option.id) }
        }
        Button(option.isCustom ? "刪除模式" : "移除模式", role: .destructive) { model.pendingDeleteID = option.id }
    }
}
struct PresetEditorPresentation: ViewModifier {
    @ObservedObject var model: PlayerModel
    func body(content: Content) -> some View {
        content
            .allowsHitTesting(!model.showPresetEditor)
            .accessibilityHidden(model.showPresetEditor)
            .overlay {
                if model.showPresetEditor {
                    ZStack {
                        Color.black.opacity(0.45).ignoresSafeArea()
                        PresetNameDialog(model: model).padding(20)
                    }.zIndex(100)
                }
            }
            .confirmationDialog("移除模式也會解除使用它的歌曲綁定。", isPresented: Binding(get: { model.pendingDeleteID != nil }, set: { if !$0 { model.pendingDeleteID = nil } }), titleVisibility: .visible) {
                Button("移除模式", role: .destructive) { if let id = model.pendingDeleteID { model.removeMode(id) }; model.pendingDeleteID = nil }
            }
    }
}
private struct PresetNameDialog: View {
    @ObservedObject var model: PlayerModel
    @FocusState private var focused: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(model.editingPresetID == nil ? "儲存新模式" : "重新命名").font(.headline)
            TextField("模式名稱（1～30字）", text: $model.presetInput)
                .textFieldStyle(.roundedBorder).focused($focused).accessibilityLabel("模式名稱")
                .onSubmit { model.savePresetName() }
            if let error = model.presetError { Text(error).font(.caption).foregroundStyle(.orange) }
            HStack {
                Button("取消") { model.showPresetEditor = false }.frame(minHeight: 44)
                Spacer()
                Button("儲存") { model.savePresetName() }.buttonStyle(.borderedProminent).frame(minHeight: 44)
            }
        }.padding(20).frame(maxWidth: 340)
            .background(OrcaTheme.panel, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(OrcaTheme.cyan.opacity(0.5)))
            .foregroundStyle(OrcaTheme.text).accessibilityAddTraits(.isModal)
            .onAppear { focused = true }
    }
}

private struct ModeReorderDrop: DropDelegate {
    let model: PlayerModel
    let target: String
    @Binding var dragged: String?
    func dropEntered(info: DropInfo) {
        guard let id = dragged, id != target else { return }
        let ids = model.modeOptions.map(\.id)
        guard let from = ids.firstIndex(of: id), let to = ids.firstIndex(of: target) else { return }
        model.moveMode(id, by: to - from)
    }
    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool { dragged = nil; return true }
}
