import SwiftUI

extension View {
    func themedSheet() -> some View {
        self.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
            .presentationCornerRadius(30)
            .presentationBackground(.regularMaterial)
            .background(LinearGradient(colors: [OrcaTheme.blue.opacity(0.18), OrcaTheme.background], startPoint: .topLeading, endPoint: .bottomTrailing))
    }
}

/// Only these leaf views observe the 5 Hz clock; menus remain structurally stable.
struct PlaybackMiniProgress: View {
    let model: PlayerModel
    @ObservedObject var clock: PlaybackClock
    var body: some View {
        ProgressView(value: min(1, max(0, clock.time / max(1, model.track.duration)))).tint(OrcaTheme.cyan).accessibilityLabel("歌曲進度")
    }
}
struct PlaybackSeekBar: View {
    let model: PlayerModel
    @ObservedObject var clock: PlaybackClock
    @ViewState private var dragging = false
    @ViewState private var draft = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var progress: Double { dragging ? draft : min(1, max(0, clock.time / max(1, model.track.duration))) }
    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(OrcaTheme.line).frame(height: dragging ? 8 : 3)
                    Capsule().fill(OrcaTheme.cyan).frame(width: max(0, geometry.size.width * progress), height: dragging ? 8 : 3)
                    RoundedRectangle(cornerRadius: dragging ? 5 : 2).fill(OrcaTheme.text)
                        .frame(width: dragging ? 24 : 8, height: dragging ? 24 : 8)
                        .offset(x: max(0, min(geometry.size.width - (dragging ? 24 : 8), geometry.size.width * progress - (dragging ? 12 : 4))))
                }.frame(height: 44).contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                        dragging = true; draft = min(1, max(0, value.location.x / max(1, geometry.size.width)))
                    }.onEnded { value in
                        let fraction = min(1, max(0, value.location.x / max(1, geometry.size.width)))
                        model.seek(to: fraction * model.track.duration); dragging = false
                    })
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: dragging)
            }.frame(height: 44)
            HStack { Text(PlayerModel.time(progress * model.track.duration)); Spacer(); Text("−" + PlayerModel.time((1 - progress) * model.track.duration)) }
                .font(.caption2.monospacedDigit()).foregroundStyle(OrcaTheme.muted)
        }.accessibilityElement(children: .ignore).accessibilityLabel("播放進度")
            .accessibilityValue("\(PlayerModel.time(clock.time))，共\(PlayerModel.time(model.track.duration))")
            .accessibilityAdjustableAction { direction in
                model.seek(to: min(model.track.duration, max(0, clock.time + (direction == .increment ? 5 : -5))))
            }
            .onChange(of: model.selectedID) { _, _ in dragging = false }
    }
}
