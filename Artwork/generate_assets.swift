// Sky Stack art generator.
// Paints every bitmap the app uses (backgrounds, blocks, characters, items, tutorial
// illustrations, HUD parts) with CoreGraphics and writes them as image sets into an
// asset catalog folder. Deterministic: the same run always produces the same art.
//
// Usage: swift generate_assets.swift "<path>/Assets.xcassets/Generated" [preview-dir]

import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let outputRoot = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "./Generated")
let previewRoot: URL? = CommandLine.arguments.count > 2 ? URL(fileURLWithPath: CommandLine.arguments[2]) : nil
let fm = FileManager.default
try? fm.createDirectory(at: outputRoot, withIntermediateDirectories: true)
if let previewRoot { try? fm.createDirectory(at: previewRoot, withIntermediateDirectories: true) }
try! #"{"info":{"author":"xcode","version":1}}"#.write(to: outputRoot.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)

// MARK: - Colour helpers

struct Col {
    var r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat = 1
    init(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) { self.r = r; self.g = g; self.b = b; self.a = a }
    init(hex: UInt32, _ a: CGFloat = 1) {
        r = CGFloat((hex >> 16) & 0xFF) / 255; g = CGFloat((hex >> 8) & 0xFF) / 255; b = CGFloat(hex & 0xFF) / 255; self.a = a
    }
    var cg: CGColor { CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: [r, g, b, a])! }
    func mix(_ o: Col, _ t: CGFloat) -> Col { Col(r + (o.r - r) * t, g + (o.g - g) * t, b + (o.b - b) * t, a + (o.a - a) * t) }
    func alpha(_ v: CGFloat) -> Col { Col(r, g, b, v) }
    func lighter(_ t: CGFloat) -> Col { mix(.white, t) }
    func darker(_ t: CGFloat) -> Col { mix(Col(0.05, 0.06, 0.12), t) }
    static let white = Col(1, 1, 1)
    static let ink = Col(hex: 0x1B2340)
}

struct Rng {
    var s: UInt64
    mutating func next() -> CGFloat {
        s ^= s >> 12; s ^= s << 25; s ^= s >> 27
        return CGFloat(Double((s &* 2685821657736338717) >> 11) / Double(1 << 53))
    }
    mutating func r(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * next() }
}

// MARK: - Canvas (top-left origin)

var ctx: CGContext!
var canvasW: CGFloat = 0, canvasH: CGFloat = 0

func begin(_ w: Int, _ h: Int) {
    canvasW = CGFloat(w); canvasH = CGFloat(h)
    ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.translateBy(x: 0, y: CGFloat(h)); ctx.scaleBy(x: 1, y: -1)
    ctx.setLineCap(.round); ctx.setLineJoin(.round)
    ctx.interpolationQuality = .high
}

/// Writes the current canvas as `<name>.imageset` marked @3x so 3 px = 1 pt.
func finish(_ name: String) {
    let image = ctx.makeImage()!
    let dir = outputRoot.appendingPathComponent("\(name).imageset")
    try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
    let file = dir.appendingPathComponent("\(name).png")
    let dest = CGImageDestinationCreateWithURL(file as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil); CGImageDestinationFinalize(dest)
    let json = #"{"images":[{"idiom":"universal","scale":"1x"},{"idiom":"universal","scale":"2x"},{"filename":"\#(name).png","idiom":"universal","scale":"3x"}],"info":{"author":"xcode","version":1}}"#
    try! json.write(to: dir.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
    if let previewRoot { try? fm.removeItem(at: previewRoot.appendingPathComponent("\(name).png")); try? fm.copyItem(at: file, to: previewRoot.appendingPathComponent("\(name).png")) }
}

func gradient(_ cols: [Col], _ locs: [CGFloat]? = nil) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: cols.map(\.cg) as CFArray, locations: locs)!
}

func rr(_ r: CGRect, _ radius: CGFloat) -> CGPath { CGPath(roundedRect: r, cornerWidth: min(radius, r.width / 2), cornerHeight: min(radius, r.height / 2), transform: nil) }
func ellipse(_ r: CGRect) -> CGPath { CGPath(ellipseIn: r, transform: nil) }
func circle(_ c: CGPoint, _ rad: CGFloat) -> CGPath { ellipse(CGRect(x: c.x - rad, y: c.y - rad, width: rad * 2, height: rad * 2)) }
func poly(_ pts: [CGPoint]) -> CGPath { let p = CGMutablePath(); p.addLines(between: pts); p.closeSubpath(); return p }

func fill(_ path: CGPath, _ c: Col) { ctx.addPath(path); ctx.setFillColor(c.cg); ctx.fillPath() }
func stroke(_ path: CGPath, _ c: Col, _ w: CGFloat) { ctx.addPath(path); ctx.setStrokeColor(c.cg); ctx.setLineWidth(w); ctx.strokePath() }
func linearFill(_ path: CGPath, _ cols: [Col], _ from: CGPoint, _ to: CGPoint, _ locs: [CGFloat]? = nil) {
    ctx.saveGState(); ctx.addPath(path); ctx.clip()
    ctx.drawLinearGradient(gradient(cols, locs), start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()
}
func radialFill(_ path: CGPath, _ cols: [Col], _ c: CGPoint, _ radius: CGFloat, _ locs: [CGFloat]? = nil) {
    ctx.saveGState(); ctx.addPath(path); ctx.clip()
    ctx.drawRadialGradient(gradient(cols, locs), startCenter: c, startRadius: 0, endCenter: c, endRadius: radius, options: [.drawsAfterEndLocation])
    ctx.restoreGState()
}
func glow(_ c: CGPoint, _ radius: CGFloat, _ col: Col) {
    ctx.saveGState(); ctx.setBlendMode(.screen)
    ctx.drawRadialGradient(gradient([col, col.alpha(0)]), startCenter: c, startRadius: 0, endCenter: c, endRadius: radius, options: [])
    ctx.restoreGState()
}
func shadowed(_ offsetY: CGFloat, _ blur: CGFloat, _ col: Col = Col(0.05, 0.08, 0.2, 0.35), _ body: () -> Void) {
    ctx.saveGState(); ctx.setShadow(offset: CGSize(width: 0, height: -offsetY), blur: blur, color: col.cg); ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    body()
    ctx.endTransparencyLayer(); ctx.restoreGState()
}
func text(_ s: String, _ p: CGPoint, size: CGFloat, weight: NSFont.Weight = .black, color: Col, center: Bool = true) {
    var font = NSFont.systemFont(ofSize: size, weight: weight)
    if let d = font.fontDescriptor.withDesign(.rounded), let f = NSFont(descriptor: d, size: size) { font = f }
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor(cgColor: color.cg)!]
    let str = NSAttributedString(string: s, attributes: attrs)
    let sz = str.size()
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
    str.draw(at: CGPoint(x: center ? p.x - sz.width / 2 : p.x, y: p.y - sz.height / 2))
    NSGraphicsContext.restoreGraphicsState()
}

// MARK: - Shared motifs

/// A puffy cloud: union of circles, white top fading to a cool shadowed underside.
func cloudShape(_ rect: CGRect, seed: UInt64, puffs: Int = 6) -> CGPath {
    var g = Rng(s: seed)
    let p = CGMutablePath()
    let base = rect.maxY - rect.height * 0.28
    p.addPath(rr(CGRect(x: rect.minX + rect.width * 0.08, y: base - rect.height * 0.22, width: rect.width * 0.84, height: rect.height * 0.5), rect.height * 0.25))
    for i in 0..<puffs {
        let t = (CGFloat(i) + 0.5) / CGFloat(puffs)
        let rad = rect.height * g.r(0.24, 0.42) * (1 - abs(t - 0.5) * 0.8)
        let cx = rect.minX + rect.width * (0.12 + 0.76 * t)
        let cy = base - rad * g.r(0.4, 0.9)
        p.addPath(circle(CGPoint(x: cx, y: cy), rad))
    }
    return p
}

func drawCloud(_ rect: CGRect, seed: UInt64, top: Col = .white, bottom: Col = Col(hex: 0xC9D7EE), alpha: CGFloat = 1, shadow: Bool = true) {
    let shape = cloudShape(rect, seed: seed)
    let body = { fill(shape, bottom.alpha(alpha)) }
    if shadow { shadowed(rect.height * 0.06, rect.height * 0.12, Col(0.15, 0.25, 0.5, 0.25 * alpha), body) } else { body() }
    // Lit upper part: the same silhouette nudged up, clipped to the cloud, leaves a shaded underside that follows every puff.
    ctx.saveGState(); ctx.addPath(shape); ctx.clip()
    ctx.translateBy(x: -rect.width * 0.015, y: -rect.height * 0.13)
    linearFill(shape, [top.alpha(alpha), top.mix(bottom, 0.25).alpha(alpha)], CGPoint(x: 0, y: rect.minY), CGPoint(x: 0, y: rect.maxY))
    ctx.restoreGState()
}

/// One tower floor module: roof trim, glass band, floor slab, bevelled edges.
func drawBlockFace(_ rect: CGRect, _ base: Col, radius: CGFloat? = nil, windows: Bool = false, seed: UInt64 = 1) {
    let r = radius ?? rect.height * 0.24
    let path = rr(rect, r)
    linearFill(path, [base.lighter(0.25), base, base.darker(0.28)], CGPoint(x: 0, y: rect.minY), CGPoint(x: 0, y: rect.maxY), [0, 0.45, 1])
    ctx.saveGState(); ctx.addPath(path); ctx.clip()
    // Roof trim and cornice.
    fill(CGPath(rect: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height * 0.16), transform: nil), base.lighter(0.45))
    fill(CGPath(rect: CGRect(x: rect.minX, y: rect.minY + rect.height * 0.16, width: rect.width, height: rect.height * 0.04), transform: nil), base.darker(0.15).alpha(0.6))
    // Floor slab.
    fill(CGPath(rect: CGRect(x: rect.minX, y: rect.maxY - rect.height * 0.2, width: rect.width, height: rect.height * 0.2), transform: nil), base.darker(0.38))
    fill(CGPath(rect: CGRect(x: rect.minX, y: rect.maxY - rect.height * 0.2, width: rect.width, height: rect.height * 0.035), transform: nil), Col.white.alpha(0.18))
    // Side bevels.
    ctx.drawLinearGradient(gradient([Col.white.alpha(0.22), Col.white.alpha(0), Col(0, 0, 0, 0), Col(0, 0, 0, 0.18)], [0, 0.08, 0.9, 1]),
                           start: CGPoint(x: rect.minX, y: 0), end: CGPoint(x: rect.maxX, y: 0), options: [])
    if windows {
        var g = Rng(s: seed)
        let count = max(2, Int(rect.width / (rect.height * 0.9)))
        for i in 0..<count {
            let wW = rect.height * 0.34, wH = rect.height * 0.4
            let cx = rect.minX + rect.width * (CGFloat(i) + 0.5) / CGFloat(count)
            drawWindow(CGRect(x: cx - wW / 2, y: rect.minY + rect.height * 0.27, width: wW, height: wH), lit: g.next() > 0.45)
        }
    }
    ctx.restoreGState()
    stroke(rr(rect.insetBy(dx: rect.height * 0.03, dy: rect.height * 0.03), r), base.darker(0.55).alpha(0.85), rect.height * 0.055)
}

func drawWindow(_ r: CGRect, lit: Bool) {
    let frame = rr(r, r.width * 0.18)
    fill(frame, Col.ink.alpha(0.75))
    let glass = r.insetBy(dx: r.width * 0.14, dy: r.width * 0.14)
    if lit {
        linearFill(rr(glass, r.width * 0.1), [Col(hex: 0xFFF1B8), Col(hex: 0xFFC65C), Col(hex: 0xF29A3C)], CGPoint(x: 0, y: glass.minY), CGPoint(x: 0, y: glass.maxY))
        fill(CGPath(rect: CGRect(x: glass.midX - glass.width * 0.06, y: glass.minY, width: glass.width * 0.12, height: glass.height), transform: nil), Col(hex: 0xB86A2A, 0.45))
    } else {
        linearFill(rr(glass, r.width * 0.1), [Col(hex: 0x9FD4FF), Col(hex: 0x4F86D8), Col(hex: 0x2A4C99)], CGPoint(x: glass.minX, y: glass.minY), CGPoint(x: glass.maxX, y: glass.maxY))
        ctx.saveGState(); ctx.addPath(rr(glass, r.width * 0.1)); ctx.clip()
        fill(poly([CGPoint(x: glass.minX, y: glass.maxY * 0.98), CGPoint(x: glass.minX + glass.width * 0.45, y: glass.minY), CGPoint(x: glass.minX + glass.width * 0.75, y: glass.minY), CGPoint(x: glass.minX + glass.width * 0.2, y: glass.maxY)]), Col.white.alpha(0.35))
        ctx.restoreGState()
    }
}

func star(_ c: CGPoint, _ outer: CGFloat, _ inner: CGFloat, points: Int = 5, rotation: CGFloat = -.pi / 2) -> CGPath {
    var pts: [CGPoint] = []
    for i in 0..<(points * 2) {
        let a = rotation + CGFloat(i) * .pi / CGFloat(points)
        let rad = i % 2 == 0 ? outer : inner
        pts.append(CGPoint(x: c.x + cos(a) * rad, y: c.y + sin(a) * rad))
    }
    return poly(pts)
}

func drawCoin(_ c: CGPoint, _ rad: CGFloat) {
    shadowed(rad * 0.08, rad * 0.18) {
        linearFill(circle(c, rad), [Col(hex: 0xFFE68A), Col(hex: 0xF5B532), Col(hex: 0xC97A12)], CGPoint(x: c.x, y: c.y - rad), CGPoint(x: c.x, y: c.y + rad))
    }
    linearFill(circle(c, rad * 0.8), [Col(hex: 0xF7B934), Col(hex: 0xFFD866)], CGPoint(x: c.x, y: c.y - rad), CGPoint(x: c.x, y: c.y + rad))
    let s = star(c, rad * 0.56, rad * 0.25)
    shadowed(-rad * 0.03, rad * 0.04, Col(1, 1, 1, 0.6)) { fill(s, Col(hex: 0xFFF4C2)) }
    stroke(s, Col(hex: 0xC27A16, 0.7), rad * 0.04)
    stroke(circle(c, rad * 0.97), Col(hex: 0xA8620E, 0.8), rad * 0.05)
    ctx.saveGState(); ctx.addPath(circle(c, rad * 0.95)); ctx.clip()
    fill(ellipse(CGRect(x: c.x - rad * 0.9, y: c.y - rad * 1.2, width: rad * 1.3, height: rad * 0.9)), Col.white.alpha(0.22))
    ctx.restoreGState()
}

// MARK: - Palettes (mirrors BuilderSkin.blockPalette)

let palettes: [String: [UInt32]] = [
    "sparrow": [0xFA6B66, 0xFFB84D, 0x73D173, 0x59A6FA, 0xB880F2, 0xFA8CBF],
    "kite": [0xFF7359, 0xFF9E4D, 0xFFCC59, 0xF2668C, 0xD959B3, 0xFF8C73],
    "heron": [0x66CCD9, 0x4DA6CC, 0x8CE6BF, 0x4080B3, 0xB3EBF2, 0x59B8AD],
    "aurora": [0x66E6A6, 0x8C80F2, 0x4DCCD9, 0xBF73F2, 0x73F2CC, 0x5999F2],
    "comet": [0xFF8C33, 0xF24D40, 0xFFC74D, 0xCC4066, 0xFF7366, 0x993373],
    "zenith": [0xFFD966, 0xF2F2FA, 0x4D59A6, 0xFFBF4D, 0xCCD1F2, 0x7380D9]
]
let skins = ["sparrow", "kite", "heron", "aurora", "comet", "zenith"]

// MARK: - Backgrounds

func skyline(_ baseY: CGFloat, _ col: Col, _ lit: Col?, seed: UInt64, maxH: CGFloat) {
    var g = Rng(s: seed)
    var x: CGFloat = -20
    while x < canvasW + 20 {
        let w = g.r(50, 120), h = g.r(maxH * 0.3, maxH)
        let r = CGRect(x: x, y: baseY - h, width: w, height: h + 400)
        fill(CGPath(rect: r, transform: nil), col)
        if g.next() > 0.6 { fill(CGPath(rect: CGRect(x: x + w * 0.45, y: baseY - h - g.r(20, 60), width: 4, height: 60), transform: nil), col) }
        if let lit {
            var yy = baseY - h + 16
            while yy < baseY {
                var xx = x + 10
                while xx < x + w - 14 { if g.next() > 0.62 { fill(CGPath(rect: CGRect(x: xx, y: yy, width: 8, height: 10), transform: nil), lit) }; xx += 18 }
                yy += 22
            }
        }
        x += w + g.r(4, 18)
    }
}

func drawSky(_ name: String, _ stops: [Col], _ locs: [CGFloat], body: () -> Void) {
    begin(780, 1690)
    linearFill(CGPath(rect: CGRect(x: 0, y: 0, width: canvasW, height: canvasH), transform: nil), stops, .zero, CGPoint(x: 0, y: canvasH), locs)
    body()
    finish(name)
}

drawSky("sky-day", [Col(hex: 0x2E7BEA), Col(hex: 0x6FB6FF), Col(hex: 0xBFE3FF), Col(hex: 0xFFE3C4)], [0, 0.45, 0.78, 1]) {
    glow(CGPoint(x: 600, y: 360), 320, Col(hex: 0xFFF6D8, 0.9))
    fill(circle(CGPoint(x: 600, y: 360), 70), Col(hex: 0xFFF8E4))
    for (i, y) in [240.0, 520, 820, 1080].enumerated() {
        drawCloud(CGRect(x: CGFloat(i % 2 == 0 ? -60 : 380), y: y, width: 460, height: 170), seed: UInt64(10 + i), alpha: 0.75 - CGFloat(i) * 0.08, shadow: false)
    }
    skyline(1500, Col(hex: 0x9CC4EC), nil, seed: 3, maxH: 300)
    skyline(1580, Col(hex: 0x86B1E0), Col(hex: 0xEAF4FF, 0.5), seed: 4, maxH: 220)
    for i in 0..<5 { drawCloud(CGRect(x: CGFloat(i) * 180 - 90, y: 1500, width: 330, height: 200), seed: UInt64(40 + i), alpha: 0.95) }
}

drawSky("sky-dusk", [Col(hex: 0x262B6E), Col(hex: 0x6B3F8C), Col(hex: 0xD9667A), Col(hex: 0xFFB065)], [0, 0.4, 0.75, 1]) {
    var g = Rng(s: 8)
    for _ in 0..<40 { fill(circle(CGPoint(x: g.r(0, canvasW), y: g.r(0, 500)), g.r(1.5, 3)), Col.white.alpha(g.r(0.3, 0.8))) }
    glow(CGPoint(x: 240, y: 1380), 420, Col(hex: 0xFFC76B, 0.9))
    fill(circle(CGPoint(x: 240, y: 1380), 90), Col(hex: 0xFFE2A8))
    for (i, y) in [420.0, 760, 1050].enumerated() {
        drawCloud(CGRect(x: CGFloat(i % 2 == 0 ? 320 : -80), y: y, width: 480, height: 160), seed: UInt64(20 + i), top: Col(hex: 0xFFC3B0), bottom: Col(hex: 0x8A4F86), alpha: 0.7, shadow: false)
    }
    skyline(1540, Col(hex: 0x4A2E63), Col(hex: 0xFFD27A, 0.85), seed: 5, maxH: 320)
    skyline(1620, Col(hex: 0x33204A), Col(hex: 0xFFC560, 0.9), seed: 6, maxH: 220)
}

drawSky("sky-night", [Col(hex: 0x03061A), Col(hex: 0x0B1440), Col(hex: 0x1C2E73), Col(hex: 0x2F4A9A)], [0, 0.4, 0.8, 1]) {
    var g = Rng(s: 9)
    for _ in 0..<220 {
        let p = CGPoint(x: g.r(0, canvasW), y: g.r(0, canvasH * 0.9)), rad = g.r(1, 3.4)
        if rad > 2.8 { glow(p, rad * 5, Col.white.alpha(0.5)) }
        fill(circle(p, rad), Col.white.alpha(g.r(0.35, 1)))
    }
    // Aurora ribbon.
    ctx.saveGState(); ctx.setBlendMode(.screen)
    for k in 0..<3 {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: -40, y: 520 + CGFloat(k) * 40))
        p.addCurve(to: CGPoint(x: 820, y: 360 + CGFloat(k) * 50), control1: CGPoint(x: 240, y: 260), control2: CGPoint(x: 520, y: 640))
        ctx.addPath(p); ctx.setStrokeColor((k == 1 ? Col(hex: 0x8C6BFA, 0.12) : Col(hex: 0x5CF2B0, 0.1)).cg); ctx.setLineWidth(70 - CGFloat(k) * 18); ctx.strokePath()
    }
    ctx.restoreGState()
    // Crescent moon.
    glow(CGPoint(x: 590, y: 280), 200, Col(hex: 0xDDE6FF, 0.5))
    ctx.saveGState(); ctx.addPath(circle(CGPoint(x: 590, y: 280), 62)); ctx.clip()
    fill(circle(CGPoint(x: 590, y: 280), 62), Col(hex: 0xF4F1E2)); ctx.setBlendMode(.clear); fill(circle(CGPoint(x: 620, y: 262), 56), .white)
    ctx.restoreGState()
    for i in 0..<5 { drawCloud(CGRect(x: CGFloat(i) * 180 - 90, y: 1520, width: 330, height: 190), seed: UInt64(60 + i), top: Col(hex: 0x6E86C9), bottom: Col(hex: 0x2B3C7A), alpha: 0.9, shadow: false) }
}

drawSky("sky-storm", [Col(hex: 0x141A2E), Col(hex: 0x262E4A), Col(hex: 0x3A4466), Col(hex: 0x56607F)], [0, 0.35, 0.7, 1]) {
    for (i, y) in [60.0, 300, 600, 900, 1250].enumerated() {
        drawCloud(CGRect(x: CGFloat(i % 2 == 0 ? -120 : 260), y: y, width: 680, height: 260), seed: UInt64(80 + i), top: Col(hex: 0x6B7594), bottom: Col(hex: 0x1C2238), alpha: 0.85, shadow: false)
    }
    let bolt = poly([CGPoint(x: 520, y: 330), CGPoint(x: 470, y: 520), CGPoint(x: 520, y: 520), CGPoint(x: 450, y: 760), CGPoint(x: 580, y: 480), CGPoint(x: 530, y: 480), CGPoint(x: 580, y: 330)])
    glow(CGPoint(x: 515, y: 540), 260, Col(hex: 0xC9D8FF, 0.35))
    fill(bolt, Col(hex: 0xF2F6FF, 0.85))
    ctx.saveGState(); ctx.setStrokeColor(Col(hex: 0xBFD0FF, 0.25).cg); ctx.setLineWidth(3)
    var g = Rng(s: 12)
    for _ in 0..<140 { let x = g.r(0, canvasW), y = g.r(0, canvasH); ctx.move(to: CGPoint(x: x, y: y)); ctx.addLine(to: CGPoint(x: x - 16, y: y + 70)); }
    ctx.strokePath(); ctx.restoreGState()
}

// MARK: - Clouds

for (i, size) in [(0, (420, 200)), (1, (360, 180)), (2, (480, 210))] {
    begin(size.0, size.1)
    drawCloud(CGRect(x: 14, y: 14, width: canvasW - 28, height: canvasH - 30), seed: UInt64(100 + i))
    finish("cloud-\(["a", "b", "c"][i])")
}

begin(660, 260)
drawCloud(CGRect(x: 16, y: 40, width: 628, height: 200), seed: 140)
finish("podium-cloud")

// MARK: - Blocks and windows

for skin in skins {
    for (i, hex) in palettes[skin]!.enumerated() {
        begin(360, 102)
        drawBlockFace(CGRect(x: 2, y: 2, width: 356, height: 98), Col(hex: hex), radius: 22)
        finish("block-\(skin)-\(i)")
    }
}
begin(360, 102)
drawBlockFace(CGRect(x: 2, y: 2, width: 356, height: 98), Col(hex: 0x3A4A7A), radius: 22)
finish("block-base")

begin(36, 45); drawWindow(CGRect(x: 1, y: 1, width: 34, height: 43), lit: true); finish("window-lit")
begin(36, 45); drawWindow(CGRect(x: 1, y: 1, width: 34, height: 43), lit: false); finish("window-glass")

// Tall building the tower stands on.
begin(600, 1800)
do {
    let body = CGRect(x: 30, y: 30, width: 540, height: 1800)
    linearFill(CGPath(rect: body, transform: nil), [Col(hex: 0x3B4C85), Col(hex: 0x2A386A), Col(hex: 0x1C2650)], CGPoint(x: body.minX, y: 0), CGPoint(x: body.maxX, y: 0), [0, 0.5, 1])
    fill(CGPath(rect: CGRect(x: 0, y: 10, width: 600, height: 36), transform: nil), Col(hex: 0x52649E))
    fill(CGPath(rect: CGRect(x: 0, y: 46, width: 600, height: 8), transform: nil), Col(hex: 0x1A2348))
    var g = Rng(s: 21)
    for row in 0..<28 {
        for col in 0..<6 {
            let r = CGRect(x: 70 + CGFloat(col) * 82, y: 90 + CGFloat(row) * 62, width: 46, height: 40)
            drawWindow(r, lit: g.next() > 0.55)
        }
        fill(CGPath(rect: CGRect(x: 30, y: 140 + CGFloat(row) * 62, width: 540, height: 4), transform: nil), Col(hex: 0x16204A, 0.6))
    }
    for x in [30.0, 288, 556] { fill(CGPath(rect: CGRect(x: x, y: 54, width: 14, height: 1800), transform: nil), Col(hex: 0x4A5C96, 0.8)) }
}
finish("tower-building")

// MARK: - Builders

func drawBuilder(_ skin: String, primary: Col, secondary: Col, glowCol: Col) {
    let s: CGFloat = canvasW / 360
    func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
    func R(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect { CGRect(x: x * s, y: y * s, width: w * s, height: h * s) }
    let skinTone = Col(hex: 0xF6D2B0), outline = secondary.darker(0.55)

    fill(ellipse(R(80, 392, 200, 26)), Col(0.05, 0.1, 0.25, 0.22))

    // Behind-the-body accessories.
    switch skin {
    case "kite":
        let k = poly([P(300, 30), P(352, 92), P(300, 160), P(250, 92)])
        shadowed(4, 8) { linearFill(k, [Col(hex: 0xFFD25C), Col(hex: 0xFF7A59)], P(250, 30), P(352, 160)) }
        stroke(k, outline, 4 * s); stroke(poly([P(300, 30), P(300, 160)]), outline.alpha(0.6), 3 * s); stroke(poly([P(250, 92), P(352, 92)]), outline.alpha(0.6), 3 * s)
        let string = CGMutablePath(); string.move(to: P(300, 160)); string.addCurve(to: P(250, 270), control1: P(330, 210), control2: P(240, 220))
        stroke(string, outline.alpha(0.7), 3 * s)
        for (i, y) in [180.0, 205, 228].enumerated() { fill(poly([P(296 + CGFloat(i) * 6, y), P(316 + CGFloat(i) * 6, y - 8), P(316 + CGFloat(i) * 6, y + 8)]), Col(hex: i % 2 == 0 ? 0xFF5C7A : 0x5CB8FF)) }
    case "aurora":
        let cape = CGMutablePath(); cape.move(to: P(120, 210)); cape.addCurve(to: P(70, 380), control1: P(80, 260), control2: P(40, 330)); cape.addLine(to: P(290, 380)); cape.addCurve(to: P(240, 210), control1: P(320, 330), control2: P(280, 260)); cape.closeSubpath()
        linearFill(cape, [Col(hex: 0x5CF2B0), Col(hex: 0x59A6FA), Col(hex: 0x9B6BFA)], P(60, 220), P(300, 380))
        stroke(cape, outline.alpha(0.7), 4 * s)
    case "comet":
        let tail = CGMutablePath(); tail.move(to: P(130, 80)); tail.addCurve(to: P(10, 40), control1: P(80, 40), control2: P(40, 20)); tail.addCurve(to: P(120, 170), control1: P(40, 110), control2: P(80, 160)); tail.closeSubpath()
        linearFill(tail, [Col(hex: 0xFFE07A, 0.95), Col(hex: 0xFF7A33, 0.85), Col(hex: 0xF2404D, 0)], P(130, 100), P(10, 40))
    default: break
    }

    // Legs and boots.
    for x in [130.0, 196] {
        linearFill(rr(R(x, 320, 36, 50), 12 * s), [secondary.lighter(0.1), secondary.darker(0.2)], P(0, 320), P(0, 370))
        shadowed(3, 6) { fill(rr(R(x - 6, 356, 48, 30), 14 * s), Col(hex: 0x3A2A26)) }
        fill(rr(R(x - 2, 358, 30, 8), 4 * s), Col.white.alpha(0.2))
    }
    // Body.
    let body = rr(R(100, 196, 160, 150), 62 * s)
    shadowed(5, 10) { linearFill(body, [primary.lighter(0.3), primary, primary.darker(0.25)], P(100, 196), P(260, 346)) }
    stroke(body, outline, 5 * s)
    // Overall bib and straps.
    fill(rr(R(138, 236, 84, 76), 18 * s), primary.lighter(0.15).alpha(0.9))
    stroke(rr(R(138, 236, 84, 76), 18 * s), outline.alpha(0.5), 3 * s)
    fill(rr(R(162, 256, 36, 26), 6 * s), primary.darker(0.2))
    // Belt with star buckle.
    fill(CGPath(rect: R(102, 300, 156, 16), transform: nil), secondary.darker(0.1))
    fill(star(P(180, 308), 13 * s, 6 * s), glowCol.lighter(0.3)); stroke(star(P(180, 308), 13 * s, 6 * s), outline.alpha(0.6), 2 * s)
    // Arms: left hanging, right raised with a hammer.
    let leftArm = rr(R(78, 220, 34, 92), 17 * s)
    linearFill(leftArm, [primary.lighter(0.2), primary.darker(0.2)], P(78, 0), P(112, 0)); stroke(leftArm, outline, 4 * s)
    fill(circle(P(95, 316), 16 * s), skinTone); stroke(circle(P(95, 316), 16 * s), outline.alpha(0.6), 3 * s)
    ctx.saveGState(); ctx.translateBy(x: 262 * s, y: 236 * s); ctx.rotate(by: 0.55)
    let rightArm = rr(CGRect(x: -17 * s, y: -80 * s, width: 34 * s, height: 88 * s), 17 * s)
    linearFill(rightArm, [primary.lighter(0.2), primary.darker(0.2)], CGPoint(x: -17 * s, y: 0), CGPoint(x: 17 * s, y: 0)); stroke(rightArm, outline, 4 * s)
    fill(rr(CGRect(x: -6 * s, y: -150 * s, width: 12 * s, height: 78 * s), 5 * s), Col(hex: 0xA0663A))
    linearFill(rr(CGRect(x: -26 * s, y: -168 * s, width: 52 * s, height: 26 * s), 7 * s), [Col(hex: 0xD8DFEA), Col(hex: 0x8792A8)], CGPoint(x: 0, y: -168 * s), CGPoint(x: 0, y: -142 * s))
    stroke(rr(CGRect(x: -26 * s, y: -168 * s, width: 52 * s, height: 26 * s), 7 * s), Col.ink.alpha(0.6), 3 * s)
    fill(circle(CGPoint(x: 0, y: -80 * s), 16 * s), skinTone); stroke(circle(CGPoint(x: 0, y: -80 * s), 16 * s), outline.alpha(0.6), 3 * s)
    ctx.restoreGState()

    // Scarf for the heron.
    if skin == "heron" {
        let scarf = CGMutablePath(); scarf.move(to: P(120, 196)); scarf.addLine(to: P(240, 196)); scarf.addLine(to: P(236, 222)); scarf.addLine(to: P(124, 222)); scarf.closeSubpath()
        fill(scarf, glowCol.darker(0.15)); stroke(scarf, outline.alpha(0.6), 3 * s)
        let tail = poly([P(220, 214), P(320, 250), P(312, 268), P(214, 234)]); fill(tail, glowCol.darker(0.25)); stroke(tail, outline.alpha(0.6), 3 * s)
    }

    // Head.
    let head = circle(P(180, 150), 70 * s)
    shadowed(4, 8) { radialFill(head, [skinTone.lighter(0.25), skinTone, skinTone.darker(0.12)], P(160, 130), 90 * s) }
    stroke(head, outline.alpha(0.7), 4 * s)
    fill(ellipse(R(122, 160, 30, 18)), Col(hex: 0xFF8C8C, 0.45)); fill(ellipse(R(208, 160, 30, 18)), Col(hex: 0xFF8C8C, 0.45))
    for x in [155.0, 205] {
        fill(ellipse(R(x - 9, 136, 18, 24)), Col(hex: 0x2A2235)); fill(circle(P(x - 3, 142), 4 * s), .white)
    }
    let smile = CGMutablePath(); smile.move(to: P(164, 176)); smile.addQuadCurve(to: P(196, 176), control: P(180, 192))
    stroke(smile, Col(hex: 0x6B3A3A), 5 * s)

    // Hat.
    let dome = CGMutablePath(); dome.move(to: P(104, 116)); dome.addCurve(to: P(256, 116), control1: P(104, 30), control2: P(256, 30)); dome.closeSubpath()
    switch skin {
    case "heron":
        // Aviator cap with ear flaps.
        let cap = CGMutablePath(); cap.move(to: P(108, 130)); cap.addCurve(to: P(252, 130), control1: P(100, 40), control2: P(260, 40)); cap.addLine(to: P(248, 176)); cap.addLine(to: P(226, 176)); cap.addLine(to: P(226, 124)); cap.addLine(to: P(134, 124)); cap.addLine(to: P(134, 176)); cap.addLine(to: P(112, 176)); cap.closeSubpath()
        shadowed(3, 6) { linearFill(cap, [secondary.lighter(0.3), secondary, secondary.darker(0.2)], P(0, 50), P(0, 176)) }
        stroke(cap, outline, 4 * s)
    default:
        shadowed(3, 6) { linearFill(dome, [secondary.lighter(0.35), secondary, secondary.darker(0.15)], P(0, 50), P(0, 116)) }
        stroke(dome, outline, 4 * s)
        fill(rr(R(172, 48, 16, 66), 6 * s), secondary.lighter(0.4).alpha(0.7))
        let brim = ellipse(R(88, 106, 184, 26))
        linearFill(brim, [secondary.lighter(0.2), secondary.darker(0.25)], P(0, 106), P(0, 132)); stroke(brim, outline, 4 * s)
    }
    // Goggles on the hat.
    stroke(poly([P(118, 94), P(242, 94)]), Col(hex: 0x2E2A3A), 9 * s)
    for x in [150.0, 210] {
        fill(circle(P(x, 92), 19 * s), Col(hex: 0x3A3646))
        radialFill(circle(P(x, 92), 13 * s), [glowCol.lighter(0.6), glowCol, glowCol.darker(0.3)], P(x - 4, 86), 16 * s)
        fill(circle(P(x - 5, 87), 4 * s), Col.white.alpha(0.85))
    }

    // Top accessories.
    switch skin {
    case "sparrow":
        for (x, dir) in [(100.0, -1.0), (260.0, 1.0)] {
            let wing = CGMutablePath(); wing.move(to: P(x, 100)); wing.addCurve(to: P(x + 52 * dir, 50), control1: P(x + 10 * dir, 60), control2: P(x + 40 * dir, 40)); wing.addCurve(to: P(x, 116), control1: P(x + 46 * dir, 80), control2: P(x + 20 * dir, 110)); wing.closeSubpath()
            linearFill(wing, [Col.white, primary.lighter(0.3)], P(x, 50), P(x, 116)); stroke(wing, outline.alpha(0.7), 3 * s)
        }
    case "zenith":
        let crown = poly([P(140, 52), P(150, 18), P(166, 40), P(180, 8), P(194, 40), P(210, 18), P(220, 52)])
        shadowed(3, 6) { linearFill(crown, [Col(hex: 0xFFF0A0), Col(hex: 0xF5B532)], P(0, 8), P(0, 52)) }
        stroke(crown, Col(hex: 0xA8620E), 3 * s)
        for p in [P(60, 60), P(300, 200), P(70, 260)] { fill(star(p, 14 * s, 5 * s, points: 4), Col(hex: 0xFFE68A)) }
    case "comet":
        fill(rr(R(174, 20, 12, 34), 6 * s), Col(hex: 0x8792A8)); fill(circle(P(180, 18), 10 * s), Col(hex: 0xFF5C40)); glow(P(180, 18), 26 * s, Col(hex: 0xFF8C40, 0.8))
    default: break
    }
}

let builderColours: [String: (UInt32, UInt32, UInt32)] = [
    "sparrow": (0xFACC66, 0x734D2E, 0x66CCFF),
    "kite": (0xFA8066, 0x8C2E38, 0xFFD973),
    "heron": (0x9EE0E6, 0x2E6685, 0xCCFFF2),
    "aurora": (0x8CEAB3, 0x337366, 0xBF99FF),
    "comet": (0xFF9E40, 0x8C3314, 0xFFE680),
    "zenith": (0xF5F0E0, 0x404773, 0xFFE066)
]
for skin in skins {
    let c = builderColours[skin]!
    begin(360, 420)
    drawBuilder(skin, primary: Col(hex: c.0), secondary: Col(hex: c.1), glowCol: Col(hex: c.2))
    finish("builder-\(skin)")
}

// MARK: - Workshop items

func itemCanvas(_ name: String, _ draw: () -> Void) { begin(300, 300); draw(); finish(name) }

itemCanvas("upgrade-foundation") {
    fill(ellipse(CGRect(x: 40, y: 250, width: 220, height: 28)), Col(0.05, 0.1, 0.25, 0.25))
    drawBlockFace(CGRect(x: 30, y: 196, width: 240, height: 62), Col(hex: 0x8A93A8), windows: false)
    drawBlockFace(CGRect(x: 50, y: 136, width: 200, height: 62), Col(hex: 0xA3ACC0), windows: false)
    drawBlockFace(CGRect(x: 72, y: 76, width: 156, height: 62), Col(hex: 0xC2C9D8), windows: false)
    // Trowel.
    ctx.saveGState(); ctx.translateBy(x: 210, y: 70); ctx.rotate(by: 0.6)
    shadowed(4, 6) {
        fill(poly([CGPoint(x: -34, y: 0), CGPoint(x: 34, y: 0), CGPoint(x: 0, y: 70)]), Col(hex: 0xD8DFEA))
        fill(rr(CGRect(x: -6, y: -50, width: 12, height: 54), 5), Col(hex: 0x8A5530))
    }
    stroke(poly([CGPoint(x: -34, y: 0), CGPoint(x: 34, y: 0), CGPoint(x: 0, y: 70)]), Col.ink.alpha(0.5), 3)
    ctx.restoreGState()
}
itemCanvas("upgrade-precision") {
    for (i, r) in [110.0, 80, 50, 22].enumerated() {
        fill(circle(CGPoint(x: 150, y: 170), r), i % 2 == 0 ? Col(hex: 0xFFFFFF, 0.92) : Col(hex: 0xFA6B66))
    }
    stroke(circle(CGPoint(x: 150, y: 170), 110), Col.ink.alpha(0.4), 4)
    stroke(poly([CGPoint(x: 150, y: 20), CGPoint(x: 150, y: 120)]), Col(hex: 0x4A4A55), 3)
    shadowed(5, 8) {
        let bob = CGMutablePath(); bob.move(to: CGPoint(x: 126, y: 120)); bob.addLine(to: CGPoint(x: 174, y: 120)); bob.addQuadCurve(to: CGPoint(x: 150, y: 190), control: CGPoint(x: 176, y: 160)); bob.addQuadCurve(to: CGPoint(x: 126, y: 120), control: CGPoint(x: 124, y: 160)); bob.closeSubpath()
        linearFill(bob, [Col(hex: 0xFFE07A), Col(hex: 0xC98A1E)], CGPoint(x: 126, y: 0), CGPoint(x: 174, y: 0))
    }
    fill(circle(CGPoint(x: 150, y: 20), 8), Col(hex: 0x4A4A55))
}
itemCanvas("upgrade-windbreak") {
    for (i, y) in [70.0, 120, 170, 220].enumerated() {
        let p = CGMutablePath(); p.move(to: CGPoint(x: 10, y: y)); p.addCurve(to: CGPoint(x: 150, y: y - 20 + CGFloat(i) * 6), control1: CGPoint(x: 60, y: y - 20), control2: CGPoint(x: 100, y: y + 20))
        stroke(p, Col(hex: 0xBFE3FF, 0.9), 8)
    }
    let sail = CGMutablePath(); sail.move(to: CGPoint(x: 150, y: 40)); sail.addCurve(to: CGPoint(x: 160, y: 260), control1: CGPoint(x: 230, y: 100), control2: CGPoint(x: 230, y: 200)); sail.closeSubpath()
    shadowed(5, 10) { linearFill(sail, [Col(hex: 0x7AD0FF), Col(hex: 0x3875F5)], CGPoint(x: 150, y: 40), CGPoint(x: 230, y: 260)) }
    stroke(sail, Col.ink.alpha(0.6), 5)
    for y in [100.0, 150, 200] { stroke(poly([CGPoint(x: 156, y: y), CGPoint(x: 205, y: y + 6)]), Col.white.alpha(0.6), 4) }
    fill(rr(CGRect(x: 144, y: 30, width: 12, height: 250), 6), Col(hex: 0x8A5530))
}
itemCanvas("upgrade-ballast") {
    fill(ellipse(CGRect(x: 60, y: 252, width: 180, height: 26)), Col(0.05, 0.1, 0.25, 0.3))
    shadowed(6, 10) {
        let handle = CGMutablePath(); handle.addArc(center: CGPoint(x: 150, y: 110), radius: 54, startAngle: .pi, endAngle: 0, clockwise: false)
        stroke(handle, Col(hex: 0x3A4256), 26)
        let body = CGMutablePath(); body.move(to: CGPoint(x: 80, y: 120)); body.addLine(to: CGPoint(x: 220, y: 120)); body.addCurve(to: CGPoint(x: 210, y: 262), control1: CGPoint(x: 266, y: 170), control2: CGPoint(x: 250, y: 250)); body.addLine(to: CGPoint(x: 90, y: 262)); body.addCurve(to: CGPoint(x: 80, y: 120), control1: CGPoint(x: 50, y: 250), control2: CGPoint(x: 34, y: 170)); body.closeSubpath()
        linearFill(body, [Col(hex: 0x6E7A96), Col(hex: 0x3A4256), Col(hex: 0x232838)], CGPoint(x: 60, y: 120), CGPoint(x: 240, y: 262))
    }
    fill(rr(CGRect(x: 104, y: 170, width: 92, height: 44), 12), Col(hex: 0xFFC65C))
    text("50", CGPoint(x: 150, y: 192), size: 34, color: Col(hex: 0x3A2A10))
}
itemCanvas("upgrade-charm") {
    let ribbon = poly([CGPoint(x: 110, y: 180), CGPoint(x: 90, y: 290), CGPoint(x: 125, y: 268), CGPoint(x: 150, y: 296), CGPoint(x: 150, y: 190)])
    fill(ribbon, Col(hex: 0x8C6BFA)); fill(poly([CGPoint(x: 190, y: 180), CGPoint(x: 210, y: 290), CGPoint(x: 175, y: 268), CGPoint(x: 150, y: 296), CGPoint(x: 150, y: 190)]), Col(hex: 0x6E4FE0))
    drawCoin(CGPoint(x: 150, y: 140), 105)
    for p in [CGPoint(x: 40, y: 50), CGPoint(x: 262, y: 70), CGPoint(x: 268, y: 220)] { glow(p, 26, Col(hex: 0xFFF2B0, 0.9)); fill(star(p, 16, 5, points: 4, rotation: 0), .white) }
}

// MARK: - Small game and HUD art

begin(180, 180); drawCoin(CGPoint(x: 90, y: 88), 76); finish("coin-star")

begin(180, 240)
glow(CGPoint(x: 90, y: 120), 110, Col(hex: 0xFFC65C, 0.8))
do {
    let body = CGMutablePath(); body.move(to: CGPoint(x: 40, y: 50)); body.addLine(to: CGPoint(x: 140, y: 50)); body.addCurve(to: CGPoint(x: 116, y: 190), control1: CGPoint(x: 170, y: 120), control2: CGPoint(x: 150, y: 170)); body.addLine(to: CGPoint(x: 64, y: 190)); body.addCurve(to: CGPoint(x: 40, y: 50), control1: CGPoint(x: 30, y: 170), control2: CGPoint(x: 10, y: 120)); body.closeSubpath()
    radialFill(body, [Col(hex: 0xFFF6D0), Col(hex: 0xFFB84D), Col(hex: 0xE0662E)], CGPoint(x: 90, y: 150), 130)
    for x in [70.0, 90, 110] { stroke(poly([CGPoint(x: x, y: 52), CGPoint(x: x + (x - 90) * 0.4, y: 188)]), Col(hex: 0xC2551E, 0.5), 3) }
    stroke(body, Col(hex: 0xA8441A), 4)
    fill(rr(CGRect(x: 60, y: 186, width: 60, height: 14), 5), Col(hex: 0x6B3A1E))
    fill(ellipse(CGRect(x: 80, y: 196, width: 20, height: 28)), Col(hex: 0xFFE07A)); glow(CGPoint(x: 90, y: 206), 30, Col(hex: 0xFFF0A0, 0.9))
}
finish("lantern")

begin(720, 110)
do {
    let bar = rr(CGRect(x: 6, y: 16, width: 708, height: 80), 26)
    shadowed(4, 8) { linearFill(bar, [Col(hex: 0xFFD66B), Col(hex: 0xF5A833), Col(hex: 0xC97A12)], CGPoint(x: 0, y: 16), CGPoint(x: 0, y: 96)) }
    stroke(bar, Col(hex: 0x8A4F0E), 4)
    let vial = rr(CGRect(x: 120, y: 32, width: 480, height: 48), 24)
    linearFill(vial, [Col(hex: 0xE8FFD6), Col(hex: 0xB8F0A0), Col(hex: 0x7ACC70)], CGPoint(x: 0, y: 32), CGPoint(x: 0, y: 80))
    ctx.saveGState(); ctx.addPath(vial); ctx.clip()
    fill(CGPath(rect: CGRect(x: 120, y: 32, width: 70, height: 48), transform: nil), Col(hex: 0xFF5C5C, 0.45)); fill(CGPath(rect: CGRect(x: 530, y: 32, width: 70, height: 48), transform: nil), Col(hex: 0xFF5C5C, 0.45))
    fill(CGPath(rect: CGRect(x: 120, y: 36, width: 480, height: 8), transform: nil), Col.white.alpha(0.5))
    ctx.restoreGState()
    stroke(vial, Col(hex: 0x4A7A3A), 4)
    for x in [330.0, 390] { stroke(poly([CGPoint(x: x, y: 30), CGPoint(x: x, y: 82)]), Col(hex: 0x2E4A24), 4) }
    for x in [40.0, 680] { fill(circle(CGPoint(x: x, y: 56), 12), Col(hex: 0x8A4F0E, 0.6)) }
}
finish("spirit-level")

begin(84, 54)
radialFill(ellipse(CGRect(x: 4, y: 4, width: 76, height: 46)), [Col.white, Col(hex: 0xF2FFE8), Col(hex: 0xC8EFB0)], CGPoint(x: 30, y: 18), 50)
stroke(ellipse(CGRect(x: 4, y: 4, width: 76, height: 46)), Col(hex: 0x4A7A3A, 0.7), 3)
finish("level-bubble")

begin(210, 150)
do {
    fill(rr(CGRect(x: 12, y: 10, width: 10, height: 136), 5), Col(hex: 0x8792A8))
    fill(circle(CGPoint(x: 17, y: 12), 9), Col(hex: 0xFFC65C))
    let sock = CGMutablePath(); sock.move(to: CGPoint(x: 22, y: 20)); sock.addLine(to: CGPoint(x: 200, y: 48)); sock.addLine(to: CGPoint(x: 200, y: 80)); sock.addLine(to: CGPoint(x: 22, y: 100)); sock.closeSubpath()
    ctx.saveGState(); ctx.addPath(sock); ctx.clip()
    for i in 0..<5 { fill(CGPath(rect: CGRect(x: 22 + CGFloat(i) * 36, y: 0, width: 36, height: 150), transform: nil), i % 2 == 0 ? Col(hex: 0xFA5C5C) : Col(hex: 0xFFFFFF)) }
    ctx.drawLinearGradient(gradient([Col(0, 0, 0, 0), Col(0, 0, 0, 0.25)]), start: CGPoint(x: 0, y: 20), end: CGPoint(x: 0, y: 100), options: [])
    ctx.restoreGState()
    stroke(sock, Col(hex: 0x7A2A2A), 4)
}
finish("windsock")

func stamp(_ name: String, _ outer: Col, _ inner: Col) {
    begin(240, 240)
    let c = CGPoint(x: 120, y: 120)
    var pts: [CGPoint] = []
    for i in 0..<48 { let a = CGFloat(i) / 48 * .pi * 2; let r: CGFloat = i % 2 == 0 ? 112 : 100; pts.append(CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r)) }
    shadowed(4, 8) { linearFill(poly(pts), [outer.lighter(0.25), outer, outer.darker(0.25)], CGPoint(x: 0, y: 8), CGPoint(x: 0, y: 232)) }
    linearFill(circle(c, 84), [inner.lighter(0.2), inner], CGPoint(x: 0, y: 36), CGPoint(x: 0, y: 204))
    stroke(circle(c, 76), outer.lighter(0.4).alpha(0.8), 4)
    for i in 0..<12 { let a = CGFloat(i) / 12 * .pi * 2; fill(circle(CGPoint(x: c.x + cos(a) * 94, y: c.y + sin(a) * 94), 3), outer.lighter(0.5)) }
    finish(name)
}
stamp("stamp-earned", Col(hex: 0xF5B532), Col(hex: 0x3B4C9A))
stamp("stamp-locked", Col(hex: 0x5A6584), Col(hex: 0x2A3150))

begin(240, 240)
fill(CGPath(rect: CGRect(x: 0, y: 0, width: 240, height: 240), transform: nil), Col(hex: 0x173A73))
for i in 0...24 {
    let v = CGFloat(i) * 10
    let major = i % 6 == 0
    ctx.setStrokeColor(Col.white.alpha(major ? 0.16 : 0.06).cg); ctx.setLineWidth(major ? 2 : 1)
    ctx.move(to: CGPoint(x: v, y: 0)); ctx.addLine(to: CGPoint(x: v, y: 240)); ctx.move(to: CGPoint(x: 0, y: v)); ctx.addLine(to: CGPoint(x: 240, y: v)); ctx.strokePath()
}
finish("blueprint-grid")

// MARK: - Logo

begin(1080, 300)
do {
    let letters = Array("SKYSTACK")
    let cols: [UInt32] = [0xFA6B66, 0xFFB84D, 0x73D173, 0x59A6FA, 0xB880F2, 0xFA8CBF, 0xFFB84D, 0x59A6FA]
    var x: CGFloat = 22
    for (i, ch) in letters.enumerated() {
        if i == 3 { x += 40 }
        let y: CGFloat = 70 + (i % 2 == 0 ? 0 : 26) - CGFloat(i == 7 ? 10 : 0)
        let r = CGRect(x: x, y: y, width: 112, height: 150)
        shadowed(8, 12) { drawBlockFace(r, Col(hex: cols[i]), radius: 30) }
        text(String(ch), CGPoint(x: r.midX, y: r.midY + 4), size: 104, color: Col(hex: 0x1B2340, 0.25))
        text(String(ch), CGPoint(x: r.midX, y: r.midY), size: 104, color: .white)
        x += 120
    }
}
finish("logo-wordmark")

// MARK: - Tutorial illustrations (240 x 160 pt)

func tutorial(_ name: String, sky: [Col] = [Col(hex: 0x6FB6FF), Col(hex: 0xCFE9FF)], _ draw: () -> Void) {
    begin(720, 480)
    let panel = rr(CGRect(x: 0, y: 0, width: 720, height: 480), 48)
    linearFill(panel, sky, .zero, CGPoint(x: 0, y: 480))
    ctx.saveGState(); ctx.addPath(panel); ctx.clip()
    draw()
    ctx.restoreGState()
    finish(name)
}
func miniTower(_ x: CGFloat, floors: Int, width: CGFloat = 220, tilt: CGFloat = 0, palette: [UInt32] = palettes["sparrow"]!) {
    ctx.saveGState(); ctx.translateBy(x: x, y: 480); ctx.rotate(by: tilt)
    fill(CGPath(rect: CGRect(x: -width * 0.43, y: -60, width: width * 0.86, height: 80), transform: nil), Col(hex: 0x2A386A))
    for i in 0..<floors {
        drawBlockFace(CGRect(x: -width / 2, y: -60 - CGFloat(i + 1) * 58, width: width, height: 58), Col(hex: palette[i % palette.count]), windows: true, seed: UInt64(i + 3))
    }
    ctx.restoreGState()
}

tutorial("howto-drop") {
    drawCloud(CGRect(x: 470, y: 40, width: 220, height: 100), seed: 301, alpha: 0.8, shadow: false)
    miniTower(300, floors: 3)
    drawBlockFace(CGRect(x: 200, y: 60, width: 220, height: 58), Col(hex: 0x59A6FA), windows: true, seed: 9)
    for dir in [-1.0, 1.0] { let a = poly([CGPoint(x: 310 + dir * 160, y: 89), CGPoint(x: 310 + dir * 130, y: 70), CGPoint(x: 310 + dir * 130, y: 108)]); fill(a, Col.white.alpha(0.85)) }
    for y in [140.0, 165, 190] { stroke(poly([CGPoint(x: 310, y: y), CGPoint(x: 310, y: y + 12)]), Col.white.alpha(0.9), 6) }
    for r in [26.0, 46, 66] { stroke(circle(CGPoint(x: 590, y: 330), r), Col.white.alpha(0.9 - r / 90), 5) }
    fill(circle(CGPoint(x: 590, y: 330), 14), Col.white)
}
tutorial("howto-trim") {
    miniTower(300, floors: 3)
    drawBlockFace(CGRect(x: 190, y: 228, width: 180, height: 58), Col(hex: 0x59A6FA), windows: true, seed: 4)
    ctx.saveGState(); ctx.translateBy(x: 470, y: 290); ctx.rotate(by: 0.5)
    drawBlockFace(CGRect(x: -40, y: -29, width: 80, height: 58), Col(hex: 0x59A6FA), seed: 5)
    ctx.restoreGState()
    let crack = CGMutablePath(); crack.move(to: CGPoint(x: 410, y: 222)); crack.addLine(to: CGPoint(x: 400, y: 245)); crack.addLine(to: CGPoint(x: 414, y: 262)); crack.addLine(to: CGPoint(x: 404, y: 292))
    stroke(crack, Col.white, 6)
    for (dx, dy) in [(520.0, 360.0), (560, 400)] { fill(circle(CGPoint(x: dx, y: dy), 8), Col(hex: 0x59A6FA)) }
}
tutorial("howto-wind") {
    miniTower(360, floors: 3)
    for (i, y) in [70.0, 110, 150].enumerated() {
        let p = CGMutablePath(); p.move(to: CGPoint(x: 30, y: y)); p.addCurve(to: CGPoint(x: 330 - CGFloat(i) * 30, y: y + 10), control1: CGPoint(x: 120, y: y - 30), control2: CGPoint(x: 220, y: y + 30))
        stroke(p, Col.white.alpha(0.85), 8)
    }
    drawBlockFace(CGRect(x: 300, y: 120, width: 220, height: 58), Col(hex: 0xB880F2), windows: true, seed: 7)
    let dots = CGMutablePath(); dots.move(to: CGPoint(x: 410, y: 186)); dots.addQuadCurve(to: CGPoint(x: 450, y: 238), control: CGPoint(x: 430, y: 220))
    ctx.saveGState(); ctx.setLineDash(phase: 0, lengths: [10, 12]); stroke(dots, Col.white, 5); ctx.restoreGState()
    ctx.saveGState(); ctx.translateBy(x: 560, y: 40); ctx.scaleBy(x: 0.9, y: 0.9)
    fill(rr(CGRect(x: 12, y: 10, width: 10, height: 200), 5), Col(hex: 0x8792A8))
    let sock = poly([CGPoint(x: 22, y: 20), CGPoint(x: 150, y: 44), CGPoint(x: 150, y: 70), CGPoint(x: 22, y: 90)])
    fill(sock, Col(hex: 0xFA5C5C)); stroke(sock, Col(hex: 0x7A2A2A), 4)
    ctx.restoreGState()
}
tutorial("howto-lean") {
    miniTower(330, floors: 4, tilt: 0.12)
    ctx.saveGState(); ctx.translateBy(x: 40, y: 30)
    let bar = rr(CGRect(x: 0, y: 0, width: 300, height: 50), 20)
    linearFill(bar, [Col(hex: 0xFFD66B), Col(hex: 0xC97A12)], .zero, CGPoint(x: 0, y: 50)); stroke(bar, Col(hex: 0x8A4F0E), 4)
    let vial = rr(CGRect(x: 40, y: 10, width: 220, height: 30), 15)
    fill(vial, Col(hex: 0xB8F0A0)); fill(CGPath(rect: CGRect(x: 210, y: 10, width: 50, height: 30), transform: nil), Col(hex: 0xFF5C5C, 0.5)); stroke(vial, Col(hex: 0x4A7A3A), 3)
    fill(ellipse(CGRect(x: 200, y: 13, width: 40, height: 24)), Col.white)
    ctx.restoreGState()
    let arrow = CGMutablePath(); arrow.addArc(center: CGPoint(x: 330, y: 480), radius: 330, startAngle: -.pi / 2 + 0.05, endAngle: -.pi / 2 + 0.3, clockwise: false)
    stroke(arrow, Col(hex: 0xFF5C5C), 8)
}
tutorial("howto-cloud") {
    miniTower(300, floors: 3)
    glow(CGPoint(x: 300, y: 225), 200, Col(hex: 0xFFFFFF, 0.8))
    drawBlockFace(CGRect(x: 160, y: 196, width: 280, height: 58), Col(hex: 0x59A6FA), windows: true, seed: 11)
    drawCloud(CGRect(x: 360, y: 150, width: 260, height: 120), seed: 302)
    for dir in [-1.0, 1.0] { let x = 300 + dir * 165; fill(poly([CGPoint(x: x + dir * 30, y: 225), CGPoint(x: x, y: 205), CGPoint(x: x, y: 245)]), Col(hex: 0xFFD25C)) }
}
tutorial("howto-storm", sky: [Col(hex: 0x262E4A), Col(hex: 0x56607F)]) {
    drawCloud(CGRect(x: -40, y: -30, width: 460, height: 190), seed: 303, top: Col(hex: 0x6B7594), bottom: Col(hex: 0x262E4A), shadow: false)
    drawCloud(CGRect(x: 330, y: -10, width: 420, height: 170), seed: 304, top: Col(hex: 0x7A84A3), bottom: Col(hex: 0x2E3550), shadow: false)
    fill(poly([CGPoint(x: 400, y: 130), CGPoint(x: 370, y: 230), CGPoint(x: 400, y: 230), CGPoint(x: 360, y: 340), CGPoint(x: 440, y: 205), CGPoint(x: 410, y: 205), CGPoint(x: 440, y: 130)]), Col(hex: 0xF2F6FF))
    ctx.saveGState(); ctx.setStrokeColor(Col(hex: 0xBFD0FF, 0.5).cg); ctx.setLineWidth(4)
    var g = Rng(s: 30); for _ in 0..<40 { let x = g.r(0, 720), y = g.r(140, 480); ctx.move(to: CGPoint(x: x, y: y)); ctx.addLine(to: CGPoint(x: x - 8, y: y + 34)) }
    ctx.strokePath(); ctx.restoreGState()
    miniTower(220, floors: 2, palette: palettes["aurora"]!)
    drawCoin(CGPoint(x: 560, y: 340), 60)
    text("×2", CGPoint(x: 560, y: 430), size: 54, color: .white)
}
tutorial("howto-lantern", sky: [Col(hex: 0x1C2E73), Col(hex: 0x4A5CA0)]) {
    miniTower(300, floors: 3, palette: palettes["zenith"]!)
    ctx.saveGState(); ctx.setLineDash(phase: 0, lengths: [14, 12]); stroke(poly([CGPoint(x: 300, y: 120), CGPoint(x: 300, y: 300)]), Col(hex: 0xFFE07A), 6); ctx.restoreGState()
    glow(CGPoint(x: 300, y: 90), 120, Col(hex: 0xFFC65C, 0.8))
    ctx.saveGState(); ctx.translateBy(x: 255, y: 20); ctx.scaleBy(x: 0.5, y: 0.5)
    let body = CGMutablePath(); body.move(to: CGPoint(x: 40, y: 50)); body.addLine(to: CGPoint(x: 140, y: 50)); body.addCurve(to: CGPoint(x: 116, y: 190), control1: CGPoint(x: 170, y: 120), control2: CGPoint(x: 150, y: 170)); body.addLine(to: CGPoint(x: 64, y: 190)); body.addCurve(to: CGPoint(x: 40, y: 50), control1: CGPoint(x: 30, y: 170), control2: CGPoint(x: 10, y: 120)); body.closeSubpath()
    radialFill(body, [Col(hex: 0xFFF6D0), Col(hex: 0xFFB84D), Col(hex: 0xE0662E)], CGPoint(x: 90, y: 150), 130)
    ctx.restoreGState()
    for (i, x) in [520.0, 590, 660].enumerated() { glow(CGPoint(x: x, y: 120), 40, Col(hex: 0xFFF0A0, 0.8)); fill(star(CGPoint(x: x, y: 120), 26, 11), Col(hex: i < 3 ? 0xFFE07A : 0xFFFFFF)) }
}

tutorial("howto-workshop", sky: [Col(hex: 0x1D4A8C), Col(hex: 0x173A73)]) {
    ctx.saveGState(); ctx.setStrokeColor(Col.white.alpha(0.12).cg); ctx.setLineWidth(2)
    for i in 0...24 { let v = CGFloat(i) * 30; ctx.move(to: CGPoint(x: v, y: 0)); ctx.addLine(to: CGPoint(x: v, y: 480)); ctx.move(to: CGPoint(x: 0, y: v)); ctx.addLine(to: CGPoint(x: 720, y: v)) }
    ctx.strokePath(); ctx.restoreGState()
    for (i, x) in [150.0, 360, 570].enumerated() {
        ctx.saveGState(); ctx.translateBy(x: x - 90, y: 90); ctx.scaleBy(x: 0.6, y: 0.6)
        ctx.setStrokeColor(Col.white.alpha(0.6).cg); ctx.setLineWidth(5); ctx.setLineDash(phase: 0, lengths: [16, 12])
        ctx.addPath(rr(CGRect(x: 0, y: 0, width: 300, height: 300), 40)); ctx.strokePath()
        ctx.restoreGState()
        _ = i
    }
    drawBlockFace(CGRect(x: 90, y: 230, width: 120, height: 34), Col(hex: 0x8A93A8))
    drawBlockFace(CGRect(x: 104, y: 196, width: 92, height: 34), Col(hex: 0xA3ACC0))
    for (i, r) in [56.0, 40, 24, 10].enumerated() { fill(circle(CGPoint(x: 360, y: 180), r), i % 2 == 0 ? Col.white : Col(hex: 0xFA6B66)) }
    fill(rr(CGRect(x: 520, y: 150, width: 100, height: 90), 24), Col(hex: 0x3A4256)); fill(rr(CGRect(x: 545, y: 180, width: 50, height: 28), 8), Col(hex: 0xFFC65C))
    for x in [150.0, 360, 570] { drawCoin(CGPoint(x: x, y: 360), 34) }
    text("UPGRADE WITH STARS", CGPoint(x: 360, y: 440), size: 30, color: .white)
}

print("Generated assets into \(outputRoot.path)")
