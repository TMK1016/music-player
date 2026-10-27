import SwiftUI
import ImageIO
import UniformTypeIdentifiers

/// The image is immutable; only ImageIO work on this actor constructs it.
struct ArtworkBitmap: @unchecked Sendable { let image: CGImage }
actor ArtworkPipeline {
    static let shared = ArtworkPipeline()
    private let cache = NSCache<NSData, BitmapBox>()
    init() { cache.totalCostLimit = 24 * 1024 * 1024; cache.countLimit = 12 }
    func decode(_ data: Data) throws -> ArtworkBitmap {
        if let cached = cache.object(forKey: data as NSData) { return cached.bitmap }
        guard data.count <= 20_000_000,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 1024,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) else { throw ArtworkError.invalid }
        let bitmap = ArtworkBitmap(image: image)
        cache.setObject(BitmapBox(bitmap), forKey: data as NSData, cost: image.bytesPerRow * image.height + data.count)
        return bitmap
    }
    func read(_ url: URL) throws -> Data {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 20_000_000 else { throw ArtworkError.invalid }
        return try Data(contentsOf: url)
    }
    func crop(_ bitmap: ArtworkBitmap, zoom: Double, offset: CGSize, side: Double) throws -> Data {
        let image = bitmap.image
        let rect = CropGeometry.sourceRect(width: Double(image.width), height: Double(image.height), side: side, zoom: zoom, offset: offset)
        guard let cropped = image.cropping(to: rect.integral) else { throw ArtworkError.invalid }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { throw ArtworkError.invalid }
        CGImageDestinationAddImage(destination, cropped, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ArtworkError.invalid }
        return output as Data
    }
}
private final class BitmapBox: NSObject {
    let bitmap: ArtworkBitmap
    init(_ bitmap: ArtworkBitmap) { self.bitmap = bitmap }
}
enum ArtworkError: LocalizedError {
    case invalid
    var errorDescription: String? { "圖片無法讀取，請使用20 MB以內的有效圖片。" }
}
struct DecodedArtwork: View {
    let data: Data?
    var symbol = "music.note"
    @ViewState private var bitmap: ArtworkBitmap?
    var body: some View {
        Group {
            if let bitmap { Image(decorative: bitmap.image, scale: 1).resizable().scaledToFill() }
            else { Image(systemName: symbol).resizable().scaledToFit().padding(12).foregroundStyle(OrcaTheme.cyan).background(OrcaTheme.panel) }
        }.task(id: data, priority: .utility) {
            bitmap = nil
            if let data {
                let decoded = try? await ArtworkPipeline.shared.decode(data)
                if !Task.isCancelled { bitmap = decoded }
            }
        }
    }
}
struct SongArtwork: View {
    @ObservedObject var model: PlayerModel
    let track: AudioTrack
    var compact = false
    var body: some View {
        GeometryReader { geometry in
            Group {
                if let data = model.coverData(track) { DecodedArtwork(data: data).frame(width: geometry.size.width, height: geometry.size.height).clipped() }
                else { AlbumArtwork(variant: track.artwork, compact: compact).equatable() }
            }
        }.aspectRatio(1, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: compact ? 9 : 18))
    }
}
struct ArtworkCropEditor: View {
    let bitmap: ArtworkBitmap
    var circular = false
    let onSave: (Data) -> Void
    @Environment(\.dismiss) private var dismiss
    @ViewState private var zoom = 1.0
    @ViewState private var offset = CGSize.zero
    @ViewState private var origin = CGSize.zero
    @ViewState private var cropSide = 300.0
    @ViewState private var saving = false
    @ViewState private var error: String?
    var body: some View {
        VStack(spacing: 18) {
            Text("裁剪照片").font(.headline)
            Text("拖曳照片，調整框內範圍").font(.caption).foregroundStyle(OrcaTheme.muted)
            GeometryReader { geometry in
                let side = min(geometry.size.width, geometry.size.height)
                let scale = max(side / CGFloat(bitmap.image.width), side / CGFloat(bitmap.image.height)) * zoom
                ZStack {
                    Image(decorative: bitmap.image, scale: 1).resizable()
                        .frame(width: CGFloat(bitmap.image.width) * scale, height: CGFloat(bitmap.image.height) * scale).offset(offset)
                    if circular { Circle().stroke(.white, lineWidth: 2).background(.black.opacity(0.12), in: Circle()).frame(width: side - 2, height: side - 2) }
                    else { Rectangle().stroke(.white, lineWidth: 2).frame(width: side - 2, height: side - 2) }
                    Path { path in
                        for i in 1...2 {
                            let p = side * CGFloat(i) / 3
                            path.move(to: CGPoint(x: p, y: 0)); path.addLine(to: CGPoint(x: p, y: side))
                            path.move(to: CGPoint(x: 0, y: p)); path.addLine(to: CGPoint(x: side, y: p))
                        }
                    }.stroke(.white.opacity(0.4), lineWidth: 0.5).frame(width: side, height: side)
                }.frame(width: side, height: side).clipped().contentShape(Rectangle())
                    .gesture(DragGesture().onChanged { value in
                        let x = max(0, (CGFloat(bitmap.image.width) * scale - side) / 2)
                        let y = max(0, (CGFloat(bitmap.image.height) * scale - side) / 2)
                        offset = CGSize(width: min(x, max(-x, origin.width + value.translation.width)), height: min(y, max(-y, origin.height + value.translation.height)))
                    }.onEnded { _ in origin = offset })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear { cropSide = side }.onChange(of: side) { _, value in cropSide = value; offset = .zero; origin = .zero }
            }.aspectRatio(1, contentMode: .fit).frame(maxWidth: 360)
            HStack { Image(systemName: "minus.magnifyingglass"); Slider(value: $zoom, in: 1...3).accessibilityLabel("照片縮放"); Image(systemName: "plus.magnifyingglass") }
                .onChange(of: zoom) { _, _ in offset = .zero; origin = .zero }
            if let error { Text(error).font(.caption).foregroundStyle(.orange) }
            HStack {
                Button("取消") { dismiss() }.frame(minHeight: 44)
                Spacer()
                Button("置中") { offset = .zero; origin = .zero; zoom = 1 }.frame(minHeight: 44)
                Spacer()
                Button(saving ? "處理中…" : "使用照片") {
                    saving = true
                    Task {
                        do { let data = try await ArtworkPipeline.shared.crop(bitmap, zoom: zoom, offset: offset, side: cropSide); onSave(data); dismiss() }
                        catch { self.error = error.localizedDescription; saving = false }
                    }
                }.disabled(saving).frame(minHeight: 44)
            }
        }.padding(20).frame(minWidth: 280, maxWidth: 500).themedSheet()
    }
}
