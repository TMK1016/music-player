import Foundation

enum CropGeometry {
    static func sourceRect(width: Double, height: Double, side: Double, zoom: Double, offset: CGSize) -> CGRect {
        let scale = max(side / width, side / height) * min(3, max(1, zoom))
        let size = min(width, height, side / scale)
        let x = min(width - size, max(0, (width - size) / 2 - offset.width / scale))
        let y = min(height - size, max(0, (height - size) / 2 - offset.height / scale))
        return CGRect(x: x, y: y, width: size, height: size)
    }
}
