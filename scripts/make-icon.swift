import AppKit
import CoreGraphics

// Logo 2a "Trail" — spec is authored on a 220pt tile; scale to 1024.
let size = 1024
let s = CGFloat(size)
let k = s / 220.0

func srgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: [r, g, b, a])!
}

let ink    = srgb(0x15/255, 0x15/255, 0x1A/255)
let paper  = (0xF4/255.0, 0xF2/255.0, 0xED/255.0)
let signal = (0.9366, 0.4012, 0.3791)

// x, yFromTop, colour, opacity
let squares: [(CGFloat, CGFloat, (Double, Double, Double), CGFloat)] = [
    (72,  72,  paper,  0.16),
    (38,  38,  paper,  1.00),
    (102, 102, signal, 0.30),
    (136, 136, signal, 1.00),
]
let side: CGFloat = 46
let radius: CGFloat = 9

// noneSkipLast => opaque, no alpha channel, exactly `size` pixels.
guard let ctx = CGContext(
    data: nil, width: size, height: size,
    bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else { exit(1) }

ctx.setFillColor(ink)
ctx.fill(CGRect(x: 0, y: 0, width: s, height: s))

for (x, yTop, c, alpha) in squares {
    let w = side * k
    let rect = CGRect(x: x * k, y: s - (yTop * k) - w, width: w, height: w)
    ctx.setFillColor(srgb(CGFloat(c.0), CGFloat(c.1), CGFloat(c.2), alpha))
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius * k, cornerHeight: radius * k, transform: nil))
    ctx.fillPath()
}

guard let cgImage = ctx.makeImage() else { exit(1) }
let url = URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL
guard let dest = CGImageDestinationCreateWithURL(url, "public.png" as CFString, 1, nil) else { exit(1) }
CGImageDestinationAddImage(dest, cgImage, nil)
CGImageDestinationFinalize(dest)
print("wrote \(CommandLine.arguments[1])")
