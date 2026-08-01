// Draws AppIcon master PNG (1024x1024), Big Sur style. Usage: swift gen-icon.swift out.png
import AppKit

let out = CommandLine.arguments[1]
let S: CGFloat = 1024
let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                    space: srgb, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

func rgba(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

// squircle plate: 824pt centered, Apple's ~22.37% corner radius, soft drop shadow
let plate = CGRect(x: 100, y: 100, width: 824, height: 824)
let squircle = CGPath(roundedRect: plate, cornerWidth: 184, cornerHeight: 184, transform: nil)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 40, color: rgba(0x000000, 0.35))
ctx.addPath(squircle)
ctx.setFillColor(rgba(0xF4434E))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(squircle)
ctx.clip()
let grad = CGGradient(colorsSpace: srgb, colors: [rgba(0xFF8A7A), rgba(0xF23B4B)] as CFArray,
                      locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
ctx.restoreGState()

// white note sheet
let sheet = CGRect(x: 512 - 220, y: 512 - 260, width: 440, height: 520)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 30, color: rgba(0x000000, 0.28))
ctx.addPath(CGPath(roundedRect: sheet, cornerWidth: 56, cornerHeight: 56, transform: nil))
ctx.setFillColor(rgba(0xFFFFFF))
ctx.fillPath()
ctx.restoreGState()

// sheet content; yTop measured from the top edge of the sheet
func bar(_ x: CGFloat, _ yTop: CGFloat, _ w: CGFloat, _ h: CGFloat, _ c: CGColor) {
    let r = CGRect(x: sheet.minX + x, y: sheet.maxY - yTop - h, width: w, height: h)
    ctx.addPath(CGPath(roundedRect: r, cornerWidth: h / 2, cornerHeight: h / 2, transform: nil))
    ctx.setFillColor(c)
    ctx.fillPath()
}
let pad: CGFloat = 64
let red = rgba(0xF4434E), gray = rgba(0xD7DBE0)
bar(pad, 72, 210, 44, red)        // heading
bar(pad, 176, 312, 26, gray)
bar(pad, 240, 258, 26, gray)

// checked task row: filled red box, white check
let box = CGRect(x: sheet.minX + pad, y: sheet.maxY - 332 - 52, width: 52, height: 52)
ctx.addPath(CGPath(roundedRect: box, cornerWidth: 14, cornerHeight: 14, transform: nil))
ctx.setFillColor(red)
ctx.fillPath()
ctx.setStrokeColor(rgba(0xFFFFFF))
ctx.setLineWidth(9)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
ctx.beginPath()
ctx.move(to: CGPoint(x: box.minX + 13, y: box.minY + 27))
ctx.addLine(to: CGPoint(x: box.minX + 22, y: box.minY + 16))
ctx.addLine(to: CGPoint(x: box.minX + 39, y: box.minY + 37))
ctx.strokePath()
bar(pad + 76, 345, 194, 26, gray)
bar(pad, 428, 160, 26, gray)

let img = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: img)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
