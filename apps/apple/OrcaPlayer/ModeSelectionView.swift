import SwiftUI

struct ModeSelectionStrip: View {
    @ObservedObject var model: PlayerModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("模式選擇").font(.system(size: 14, weight: .semibold))
                Spacer(minLength: 4)
                Button(model.modesExpanded ? "收合" : "全部") { withAnimation { model.modesExpanded.toggle() } }.font(.system(size: 12))
                Button { model.editPreset() } label: {
                    Label("自訂", systemImage: "plus.circle.fill").font(.system(size: 12, weight: .semibold))
                }.disabled(model.customPresets.count >= 20)
            }.buttonStyle(.plain).foregroundStyle(OrcaTheme.cyan)
            scrollingModes
            if model.modesExpanded {
                ExpandedModeGrid(model: model).transition(.opacity.combined(with: .move(edge: .top)))
            }
            Text("左右滑動可在下方展開全部模式；長按模式可管理。").font(.system(size: 10)).foregroundStyle(OrcaTheme.muted)
        }
    }
    @ViewBuilder private var scrollingModes: some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            modeRow.onScrollPhaseChange { _, phase in
                if phase == .interacting { withAnimation { model.modesExpanded = true } }
            }
        } else {
            modeRow.simultaneousGesture(DragGesture(minimumDistance: 20).onEnded { value in
                if abs(value.translation.width) > 24 && abs(value.translation.width) > abs(value.translation.height) * 1.3 { withAnimation { model.modesExpanded = true } }
            })
        }
    }
    private var modeRow: some View {
        ScrollViewReader { reader in
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.modeOptions) { option in
                    Button { model.applyPreset(id: option.id) } label: {
                        HStack(spacing: 5) {
                            if option.isCustom { Image(systemName: "person.crop.circle").font(.system(size: 10)) }
                            Text(option.name).lineLimit(1)
                        }.font(.system(size: 12, weight: .medium))
                            .padding(.horizontal, 15).frame(height: 42)
                            .foregroundStyle(model.presetName == option.name ? OrcaTheme.cyan : OrcaTheme.text)
                            .background(model.presetName == option.name ? OrcaTheme.blue.opacity(0.22) : OrcaTheme.background, in: RoundedRectangle(cornerRadius: 10))
                    }.buttonStyle(.plain).id(option.id)
                        .contextMenu { ModeActions(model: model, option: option) }
                        .accessibilityHint("長按可管理模式，也可按全部展開")
                }
                if model.modeOptions.isEmpty { Text("尚無模式，按自訂新增或在全部中還原內建模式。").font(.caption).foregroundStyle(OrcaTheme.muted) }
            }.padding(.vertical, 2)
        }.accessibilityLabel("模式選擇列")
            .onChange(of: model.customPresets.count) { old, new in
                if new > old, let last = model.customPresets.last {
                    withAnimation { reader.scrollTo(last.id, anchor: .trailing) }
                }
            }
        }
    }
}
struct ModeActions: View {
    @ObservedObject var model: PlayerModel
    let option: ModeOption
    var body: some View {
        if option.isCustom {
            Button("以目前調音覆蓋") { model.updatePreset(option.id) }
            Button("重新命名") { model.editPreset(option.id) }
        }
        Button(option.isCustom ? "刪除模式" : "移除模式", role: .destructive) { model.pendingDeleteID = option.id }
    }
}
struct ExpandedModeGrid: View {
    @ObservedObject var model: PlayerModel
    var body: some View {
                VStack(alignment: .leading, spacing: 20) {
                    Text("自訂模式 \(model.customPresets.count) / 20").font(.caption).foregroundStyle(OrcaTheme.muted)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 125), spacing: 10)], spacing: 10) {
                        ForEach(model.modeOptions) { option in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: option.isCustom ? "person.crop.circle" : "waveform").foregroundStyle(OrcaTheme.cyan)
                                    Spacer()
                                    Menu { ModeActions(model: model, option: option) } label: { Image(systemName: "ellipsis.circle") }
                                        .accessibilityLabel("管理 \(option.name)")
                                }
                                Button {
                                    model.applyPreset(id: option.id)
                                } label: {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(option.name).font(.system(size: 14, weight: .semibold)).lineLimit(2)
                                        Text(option.isCustom ? "自訂模式" : "內建模式").font(.system(size: 10)).foregroundStyle(OrcaTheme.muted)
                                    }.frame(maxWidth: .infinity, minHeight: 50, alignment: .leading).contentShape(Rectangle())
                                }.buttonStyle(.plain)
                            }.padding(14).background(model.presetName == option.name ? OrcaTheme.blue.opacity(0.2) : OrcaTheme.panel, in: RoundedRectangle(cornerRadius: 12))
                                .contextMenu { ModeActions(model: model, option: option) }
                        }
                    }
                    if !model.hiddenPresets.isEmpty {
                        Button("還原已移除的內建模式") { model.restoreBuiltinModes() }.font(.subheadline)
                    }
                    Text("移除模式會解除引用它的歌曲綁定。自訂模式刪除後無法從此列表還原；內建模式可用上方按鈕還原。").font(.caption).foregroundStyle(OrcaTheme.muted)
                }
    }
}
struct PresetEditorPresentation: ViewModifier {
    @ObservedObject var model: PlayerModel
    func body(content: Content) -> some View {
        content.sheet(isPresented: $model.showPresetEditor) {
            VStack(alignment: .leading, spacing: 20) {
                Text(model.editingPresetID == nil ? "儲存新模式" : "重新命名").font(.title2)
                TextField("模式名稱（1～30 字）", text: $model.presetInput).textFieldStyle(.roundedBorder)
                if let error = model.presetError { Text(error).font(.caption).foregroundStyle(.orange) }
                Text("保存 7 段 EQ、低音增強與空間風格。").font(.caption).foregroundStyle(OrcaTheme.muted)
                HStack { Button("取消") { model.showPresetEditor = false }; Spacer(); Button("儲存") { model.savePresetName() }.buttonStyle(.borderedProminent) }
            }.padding(24).frame(minWidth: 280, idealWidth: 380).preferredColorScheme(.dark)
        }
        .confirmationDialog("移除模式也會解除使用它的歌曲綁定。", isPresented: Binding(get: { model.pendingDeleteID != nil }, set: { value in if !value { model.pendingDeleteID = nil } }), titleVisibility: .visible) {
            Button("移除模式", role: .destructive) { if let id = model.pendingDeleteID { model.removeMode(id) }; model.pendingDeleteID = nil }
        }
    }
}
