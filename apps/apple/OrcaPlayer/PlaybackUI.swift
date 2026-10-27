import SwiftUI

extension View {
    func themedSheet() -> some View {
        self.presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
            .presentationCornerRadius(30)
            .presentationBackground(OrcaTheme.sheet)
            .background(OrcaTheme.sheet.ignoresSafeArea())
    }
}

/// Only these leaf views observe the 5 Hz clock; menus remain structurally stable.
struct PlaybackMiniProgress: View {
    let model: PlayerModel
    @ObservedObject var clock: PlaybackClock
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Color.white.opacity(0.12)
                Rectangle().fill(OrcaTheme.cyan).frame(width: geometry.size.width * min(1, max(0, clock.time / max(1, model.track.duration))))
            }
        }.frame(height: 2).accessibilityLabel("歌曲進度").accessibilityValue("\(Int(min(100, max(0, clock.time / max(1, model.track.duration) * 100))))百分比")
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

struct PlaybackModeButton: View {
    @ObservedObject var model: PlayerModel
    private var title: String { model.repeatOne ? "單曲循環" : model.shuffle ? "隨機播放" : "歌單循環" }
    var body: some View {
        Button { model.cyclePlaybackMode() } label: {
            Image(systemName: model.repeatOne ? "repeat.1" : model.shuffle ? "shuffle" : "repeat").frame(width: 44, height: 44)
        }.buttonStyle(.plain).accessibilityLabel("切換播放模式").accessibilityValue(title)
    }
}
struct SleepCountdownStatus: View {
    @ObservedObject var model: PlayerModel
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: 6) {
                if let deadline = model.sleepDeadline {
                    Text("倒數 \(PlayerModel.time(max(0, deadline.timeIntervalSince(context.date))))").monospacedDigit()
                    Text("預計結束 \(deadline.formatted(date: .omitted, time: .shortened))")
                } else if let songs = model.sleepSongsRemaining {
                    Text("剩餘 \(songs) 首")
                    if let date = model.estimatedSleepEnd {
                        Text("\(model.isPlaying ? "預計" : "恢復播放後約於") \(date.formatted(date: .omitted, time: .shortened)) 結束").font(.caption)
                    }
                }
            }.font(.subheadline).foregroundStyle(OrcaTheme.text)
        }
    }
}

extension View {
    func songEditorField() -> some View {
        self.textFieldStyle(.plain).padding(.horizontal, 12).frame(minHeight: 44)
            .foregroundStyle(OrcaTheme.ink).background(Color.white, in: RoundedRectangle(cornerRadius: 10)).tint(OrcaTheme.blue)
            .environment(\.colorScheme, .light)
    }
}
