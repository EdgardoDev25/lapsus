import SwiftUI

/// Ánimo de la ilustración según el estado del día.
enum OrbMood: Equatable {
    case idle, running, paused, overtime, overtimePaused, finished

    init(_ phase: DayPhase) {
        switch phase {
        case .idle: self = .idle
        case .running: self = .running
        case .paused: self = .paused
        case .overtimeRunning: self = .overtime
        case .overtimePaused: self = .overtimePaused
        case .finished, .overtimeFinished: self = .finished
        }
    }
}

/// Parámetros de animación que se mezclan suavemente al cambiar de estado.
private struct OrbParams {
    var energy: Double      // cuánto se deforma
    var speed: Double       // qué tan rápido se mueve
    var breath: Double      // amplitud de la respiración (escala)
    var breathSpeed: Double // radianes por segundo
    var glow: Double
    var colorA: RGBA
    var colorB: RGBA

    func mixed(toward o: OrbParams, _ t: Double) -> OrbParams {
        OrbParams(energy: energy + (o.energy - energy) * t,
                  speed: speed + (o.speed - speed) * t,
                  breath: breath + (o.breath - breath) * t,
                  breathSpeed: breathSpeed + (o.breathSpeed - breathSpeed) * t,
                  glow: glow + (o.glow - glow) * t,
                  colorA: colorA.mix(o.colorA, t),
                  colorB: colorB.mix(o.colorB, t))
    }
}

/// Estado de la animación entre cuadros. Es una clase para poder avanzar
/// las fases dentro del Canvas sin redibujar la vista.
private final class OrbMotion {
    var params: OrbParams?
    var lastTime: Double?
    var phase: Double = 0
    var breathPhase: Double = 0

    func step(toward target: OrbParams, time: Double) -> OrbParams {
        let dt = min(0.1, max(0, time - (lastTime ?? time)))
        lastTime = time
        let current = (params ?? target).mixed(toward: target, 1 - exp(-dt * 3.2))
        params = current
        phase += dt * current.speed
        breathPhase += dt * current.breathSpeed
        return current
    }
}

struct FocusOrb: View {
    var style: OrbStyle
    var mood: OrbMood
    var palette: Palette

    @State private var motion = OrbMotion()

    init(style: OrbStyle, mood: OrbMood, palette: Palette) {
        self.style = style
        self.mood = mood
        self.palette = palette
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let p = motion.step(toward: target, time: timeline.date.timeIntervalSinceReferenceDate)
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) * 0.34
                let scale = 1 + p.breath * sin(motion.breathPhase)
                switch style {
                case .blob: drawBlob(ctx, center, radius * scale, p)
                case .waves: drawWaves(ctx, center, radius, scale, p)
                case .particles: drawParticles(ctx, center, radius, scale, p)
                }
            }
        }
    }

    // MARK: Objetivos por estado

    private var target: OrbParams {
        let a = RGBA(palette.gradA), b = RGBA(palette.gradB)
        let gold = RGBA(Color(hex: 0xF0B64A)), goldDeep = RGBA(Color(hex: 0xE08A2E))
        let base = RGBA(palette.bg)
        switch mood {
        case .idle:
            return OrbParams(energy: 0.45, speed: 0.35, breath: 0.03, breathSpeed: Double.pi * 2 / 4,
                             glow: 0.28, colorA: a.mix(base, 0.35), colorB: b.mix(base, 0.35))
        case .running:
            return OrbParams(energy: 1.0, speed: 1.0, breath: 0.018, breathSpeed: Double.pi * 2 / 2.6,
                             glow: 0.55, colorA: a, colorB: b)
        case .paused:
            return OrbParams(energy: 0.18, speed: 0.18, breath: 0.04, breathSpeed: Double.pi * 2 / 6,
                             glow: 0.12, colorA: a.desaturated(0.8).mix(base, 0.25), colorB: b.desaturated(0.8).mix(base, 0.25))
        case .overtime:
            return OrbParams(energy: 1.0, speed: 0.95, breath: 0.018, breathSpeed: Double.pi * 2 / 2.6,
                             glow: 0.55, colorA: gold, colorB: goldDeep.mix(a, 0.35))
        case .overtimePaused:
            return OrbParams(energy: 0.18, speed: 0.18, breath: 0.04, breathSpeed: Double.pi * 2 / 6,
                             glow: 0.12, colorA: gold.desaturated(0.75).mix(base, 0.25), colorB: goldDeep.desaturated(0.75).mix(base, 0.25))
        case .finished:
            return OrbParams(energy: 0.25, speed: 0.2, breath: 0.022, breathSpeed: Double.pi * 2 / 5,
                             glow: 0.2, colorA: a.mix(base, 0.55), colorB: b.mix(base, 0.55))
        }
    }

    // MARK: Blob orgánico

    private func blobPath(_ c: CGPoint, _ r: Double, _ phase: Double, _ energy: Double) -> Path {
        var path = Path()
        let n = 180
        for i in 0...n {
            let a = Double(i) / Double(n) * 2 * Double.pi
            let wobble = 0.060 * sin(3 * a + phase * 1.1)
                + 0.045 * sin(2 * a - phase * 1.4 + 1.1)
                + 0.028 * sin(5 * a + phase * 0.8 + 2.0)
                + 0.015 * sin(7 * a - phase * 1.9)
            let rr = r * (1 + energy * wobble)
            let pt = CGPoint(x: c.x + cos(a) * rr, y: c.y + sin(a) * rr)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }

    private func gradient(_ p: OrbParams, _ c: CGPoint, _ r: Double, angle: Double, alpha: Double = 1) -> GraphicsContext.Shading {
        let dx = cos(angle) * r, dy = sin(angle) * r
        return .linearGradient(Gradient(colors: [p.colorA.with(alpha: p.colorA.a * alpha).color,
                                                 p.colorB.with(alpha: p.colorB.a * alpha).color]),
                               startPoint: CGPoint(x: c.x - dx, y: c.y - dy),
                               endPoint: CGPoint(x: c.x + dx, y: c.y + dy))
    }

    private func drawBlob(_ ctx: GraphicsContext, _ c: CGPoint, _ r: Double, _ p: OrbParams) {
        let angle = Double.pi / 4 + motion.phase * 0.25
        let shape = blobPath(c, r, motion.phase, p.energy)

        // Halo
        ctx.drawLayer { g in
            g.addFilter(.blur(radius: r * 0.28))
            g.fill(blobPath(c, r * 1.06, motion.phase + 0.6, p.energy), with: gradient(p, c, r, angle: angle, alpha: p.glow))
        }
        // Cuerpo
        ctx.fill(shape, with: gradient(p, c, r, angle: angle))
        // Brillo
        var lit = ctx
        lit.clip(to: shape)
        let hl = CGPoint(x: c.x - r * 0.32, y: c.y - r * 0.38)
        lit.fill(Path(ellipseIn: CGRect(x: hl.x - r * 0.7, y: hl.y - r * 0.7, width: r * 1.4, height: r * 1.4)),
                 with: .radialGradient(Gradient(colors: [Color.white.opacity(0.28), Color.white.opacity(0)]),
                                       center: hl, startRadius: 0, endRadius: r * 0.7))
    }

    // MARK: Ondas concéntricas

    private func drawWaves(_ ctx: GraphicsContext, _ c: CGPoint, _ r: Double, _ scale: Double, _ p: OrbParams) {
        let core = r * 0.56 * scale
        let rings = 4
        for i in 0..<rings {
            var f = (motion.phase * 0.32 + Double(i) / Double(rings)).truncatingRemainder(dividingBy: 1)
            if f < 0 { f += 1 }
            let rr = core + f * r * 0.85
            let alpha = (1 - f) * (0.25 + 0.5 * min(1, p.energy))
            let color = p.colorA.mix(p.colorB, f)
            ctx.stroke(Path(ellipseIn: CGRect(x: c.x - rr, y: c.y - rr, width: rr * 2, height: rr * 2)),
                       with: .color(color.with(alpha: color.a * alpha).color),
                       lineWidth: 1.5 + (1 - f) * 3)
        }
        ctx.drawLayer { g in
            g.addFilter(.blur(radius: core * 0.35))
            g.fill(Path(ellipseIn: CGRect(x: c.x - core * 1.1, y: c.y - core * 1.1, width: core * 2.2, height: core * 2.2)),
                   with: gradient(p, c, core, angle: Double.pi / 4, alpha: p.glow))
        }
        let disc = Path(ellipseIn: CGRect(x: c.x - core, y: c.y - core, width: core * 2, height: core * 2))
        ctx.fill(disc, with: gradient(p, c, core, angle: Double.pi / 4 + motion.phase * 0.3))
        var lit = ctx
        lit.clip(to: disc)
        let hl = CGPoint(x: c.x - core * 0.35, y: c.y - core * 0.4)
        lit.fill(Path(ellipseIn: CGRect(x: hl.x - core * 0.8, y: hl.y - core * 0.8, width: core * 1.6, height: core * 1.6)),
                 with: .radialGradient(Gradient(colors: [Color.white.opacity(0.3), Color.white.opacity(0)]),
                                       center: hl, startRadius: 0, endRadius: core * 0.8))
    }

    // MARK: Partículas en órbita

    private func rand(_ i: Int, _ salt: Double) -> Double {
        let v = sin(Double(i) * 12.9898 + salt * 78.233) * 43758.5453
        return v - floor(v)
    }

    private func drawParticles(_ ctx: GraphicsContext, _ c: CGPoint, _ r: Double, _ scale: Double, _ p: OrbParams) {
        let core = r * 0.4 * scale
        ctx.drawLayer { g in
            g.addFilter(.blur(radius: core * 0.5))
            g.fill(Path(ellipseIn: CGRect(x: c.x - core * 1.3, y: c.y - core * 1.3, width: core * 2.6, height: core * 2.6)),
                   with: gradient(p, c, core, angle: Double.pi / 4, alpha: p.glow))
        }
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - core, y: c.y - core, width: core * 2, height: core * 2)),
                 with: gradient(p, c, core, angle: Double.pi / 4 + motion.phase * 0.3))

        let count = 30
        for i in 0..<count {
            let orbit = r * (0.62 + 0.5 * rand(i, 1))
            let squash = 0.55 + 0.4 * rand(i, 2)
            let tilt = rand(i, 3) * Double.pi
            let speed = (0.35 + 0.8 * rand(i, 4)) * (rand(i, 5) > 0.5 ? 1 : -1)
            let a = rand(i, 6) * 2 * Double.pi + motion.phase * speed
            let wobble = 1 + 0.06 * p.energy * sin(motion.phase * 2 + Double(i))
            let x0 = cos(a) * orbit * wobble, y0 = sin(a) * orbit * squash * wobble
            let x = c.x + x0 * cos(tilt) - y0 * sin(tilt)
            let y = c.y + x0 * sin(tilt) + y0 * cos(tilt)
            let size = (2.5 + 4 * rand(i, 7)) * scale
            let col = (i % 2 == 0 ? p.colorA : p.colorB)
            let alpha = 0.45 + 0.5 * rand(i, 8)
            ctx.fill(Path(ellipseIn: CGRect(x: x - size / 2, y: y - size / 2, width: size, height: size)),
                     with: .color(col.with(alpha: col.a * alpha).color))
        }
    }
}
