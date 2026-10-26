import SwiftUI

enum OrcaTheme {
    static let background = Color(hex: 0x080F1B)
    static let sidebar = Color(hex: 0x0B1422)
    static let panel = Color(hex: 0x101D2E)
    static let elevated = Color(hex: 0x15263B)
    static let line = Color(hex: 0x23354D)
    static let blue = Color(hex: 0x398CFF)
    static let cyan = Color(hex: 0x6BD8FF)
    static let text = Color(hex: 0xF1F6FF)
    static let muted = Color(hex: 0x99AEC8)
    static let gradient = LinearGradient(colors: [cyan, blue], startPoint: .topLeading, endPoint: .bottomTrailing)
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
}

struct Panel<Content: View>: View {
    var padding: CGFloat = 24
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(padding).frame(maxWidth: .infinity, alignment: .leading)
            .background(OrcaTheme.panel, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(OrcaTheme.line.opacity(0.7), lineWidth: 1))
    }
}

struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 10, weight: .semibold, design: .monospaced)).tracking(2.5).foregroundStyle(OrcaTheme.muted)
    }
}

struct IconButton: View {
    let symbol: String
    let label: String
    var active = false
    var size: CGFloat = 42
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 17, weight: .medium))
                .foregroundStyle(active ? OrcaTheme.cyan : OrcaTheme.muted)
                .frame(width: size, height: size).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(label)
    }
}

struct Tag: View {
    let text: String
    var symbol: String? = nil
    var body: some View {
        HStack(spacing: 5) {
            if let symbol { Image(systemName: symbol) }
            Text(text)
        }.font(.system(size: 11, weight: .medium)).foregroundStyle(OrcaTheme.cyan)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(OrcaTheme.blue.opacity(0.12), in: Capsule())
    }
}

/// Procedural cover art; no remote images, third-party music, or licensed artwork.
struct AlbumArtwork: View {
    var variant = 0
    var compact = false
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                LinearGradient(colors: [Color(hex: 0x102E55), Color(hex: 0x071326), Color(hex: 0x14395C)], startPoint: .topLeading, endPoint: .bottomTrailing)
                Canvas { context, s in
                    let center = CGPoint(x: s.width * 0.51, y: s.height * 0.46)
                    let radius = s.width * 0.29
                    for ring in 0..<7 {
                        let r = radius + CGFloat(ring) * s.width * 0.022
                        let ellipse = CGRect(x: center.x - r, y: center.y - r * 0.56, width: r * 2, height: r * 1.12)
                        context.stroke(Path(ellipseIn: ellipse), with: .color(OrcaTheme.cyan.opacity(0.5 - Double(ring) * 0.055)), lineWidth: ring == 0 ? 1.8 : 0.6)
                    }
                    for line in 0..<24 {
                        var path = Path()
                        for step in 0...90 {
                            let x = CGFloat(step) / 90 * s.width
                            let phase = Double(step) * 0.065 + Double(variant) * 0.8
                            let envelope = sin(Double(step) / 90 * .pi)
                            let y = s.height * 0.64 + CGFloat(line) * s.height * 0.017 - CGFloat(sin(phase + Double(line) * 0.13) * envelope) * s.height * 0.14
                            if step == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                        context.stroke(path, with: .color(OrcaTheme.cyan.opacity(0.18 + Double(line) * 0.012)), lineWidth: 0.7)
                    }
                    let sun = CGRect(x: center.x - s.width * 0.065, y: center.y - s.width * 0.065, width: s.width * 0.13, height: s.width * 0.13)
                    context.fill(Path(ellipseIn: sun), with: .linearGradient(Gradient(colors: [OrcaTheme.cyan, OrcaTheme.blue]), startPoint: sun.origin, endPoint: CGPoint(x: sun.maxX, y: sun.maxY)))
                }
                if !compact {
                    VStack(alignment: .leading) {
                        HStack { Text("MUSIC").tracking(4); Spacer(); Text("VOL. 01").tracking(1) }
                            .font(.system(size: max(8, size.width * 0.031), weight: .medium, design: .monospaced))
                        Spacer()
                        Text(variant % 2 == 0 ? "AFTER\nHOURS" : "BLUE\nHOUR")
                            .font(.system(size: max(20, size.width * 0.15), weight: .light, design: .rounded)).tracking(4).lineSpacing(-4)
                        Text("S O U N D   I N   M O T I O N").font(.system(size: max(6, size.width * 0.022), weight: .medium, design: .monospaced)).padding(.top, 6)
                    }.foregroundStyle(Color.white.opacity(0.9)).padding(size.width * 0.085)
                }
            }
        }.aspectRatio(1, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: compact ? 9 : 18))
            .accessibilityLabel("Music Player 原創藍色波紋示範封面")
    }
}
