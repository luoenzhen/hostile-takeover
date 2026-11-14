import AppKit
let url = URL(fileURLWithPath: CommandLine.arguments[1])
guard let image = NSImage(contentsOf: url), let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { exit(1) }
let n = 128
var pixels = [UInt8](repeating: 0, count: n*n*4)
let lit = pixels.withUnsafeMutableBytes { bytes -> Int in
    let context = CGContext(data: bytes.baseAddress, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n*4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.draw(cg, in: CGRect(x: 0, y: 0, width: n, height: n))
    let p = bytes.bindMemory(to: UInt8.self)
    return stride(from: 0, to: n*n*4, by: 4).filter { p[$0] > 20 || p[$0+1] > 20 || p[$0+2] > 20 }.count
}
print("Visible pixels: \(lit)/\(n*n)")
exit(lit > 500 ? 0 : 1)
