// Original technology-blue waveform icon. No third-party artwork or SF Symbols.
import AppKit
import ImageIO
import UniformTypeIdentifiers
let output = CommandLine.arguments[1]
let size = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
let colors = [CGColor(red: 0.025, green: 0.07, blue: 0.19, alpha: 1), CGColor(red: 0.04, green: 0.24, blue: 0.51, alpha: 1)] as CFArray
ctx.drawLinearGradient(CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1])!, start: CGPoint(x: 100, y: 1024), end: CGPoint(x: 900, y: 0), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
ctx.setStrokeColor(CGColor(red: 0.12, green: 0.72, blue: 1, alpha: 0.30)); ctx.setLineWidth(3)
ctx.strokeEllipse(in: CGRect(x: 155, y: 155, width: 714, height: 714))
ctx.setLineCap(.round);ctx.setLineWidth(48)
for (i, h) in [150.0, 310, 490, 350, 190].enumerated() {
 let x = 302.0 + Double(i) * 105
 ctx.setStrokeColor(CGColor(red: 0.30 + Double(i)*0.12, green: 0.80 + Double(i)*0.035, blue: 1, alpha: 1))
 ctx.move(to: CGPoint(x: x, y: 512-h/2)); ctx.addLine(to: CGPoint(x:x,y:512+h/2));ctx.strokePath()
}
let dest=CGImageDestinationCreateWithURL(URL(fileURLWithPath:output) as CFURL, UTType.png.identifier as CFString,1,nil)!
CGImageDestinationAddImage(dest,ctx.makeImage()!,nil)
precondition(CGImageDestinationFinalize(dest))
