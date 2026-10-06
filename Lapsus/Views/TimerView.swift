import SwiftUI

/// Pedido de cierre: qué se cierra y en qué momento (se fija al abrir la hoja,
/// así el rato que se tarda llenándola no cuenta como trabajo).
struct FinishRequest: Identifiable {
    let id = UUID()
    let kind: WorkKind
    let at: Date
}

struct TimerView: View {
    @EnvironmentObject private var store: WorkStore
    @EnvironmentObject private var prefs: Preferences
    @Environment(\.palette) private var pal

    @State private var finishing: FinishRequest?
    @State private var confirmReopen = false

    private var day: WorkDay { store.current }
    private var phase: DayPhase { day.phase }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                    .padding(.top, 8)
                if store.currentIsStale && phase.isActive {
                    staleBanner.padding(.top, 14)
                }
                orb
                    .padding(.top, 6)
                clock
                    .padding(.top, -6)
                closedSection
                    .padding(.top, 22)
                todayFeed
                    .padding(.top, 26)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .background(pal.bg.ignoresSafeArea())
        .sheet(isPresented: $store.askResume) {
            ResumeSheet(pause: day.openPause) { cats, note in
                store.resume(categories: cats, note: note)
            }
            .environment(\.palette, pal)
            .environmentObject(prefs)
        }
        .sheet(item: $finishing) { req in
            FinishSheet(request: req)
                .environment(\.palette, pal)
                .environmentObject(store)
                .environmentObject(prefs)
        }
        .confirmationDialog("¿Reabrir la jornada?", isPresented: $confirmReopen, titleVisibility: .visible) {
            Button("Reabrir jornada") { store.reopenDay() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("El tiempo desde que la cerraste quedará como una pausa y te preguntaremos qué hiciste.")
        }
        .onAppear { Haptics.warmUp() }
    }

    // MARK: Encabezado

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(Fmt.dayLong(day.date))
                    .font(.system(size: 22, weight: .heavy))
                    .tracking(-0.4)
                    .foregroundStyle(pal.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                phaseChip
            }
            Spacer(minLength: 0)
            if phase.isActive {
                Button {
                    finishing = FinishRequest(kind: phase.kind, at: store.closingTime())
                    Haptics.tap()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: phase.isOvertime ? "stop.fill" : "flag.checkered")
                            .font(.system(size: 12, weight: .bold))
                        Text(phase.isOvertime ? "Detener extra" : "Finalizar día")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(phase.isOvertime ? pal.goldDeep : pal.text)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 9)
                    .background(pal.card, in: Capsule())
                    .overlay(Capsule().strokeBorder(phase.isOvertime ? pal.goldBorder : pal.border, lineWidth: 1))
                }
                .buttonStyle(PressStyle())
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: phase)
    }

    private var phaseChip: some View {
        let (text, color): (String, Color) = {
            switch phase {
            case .idle: return ("Sin iniciar", pal.muted)
            case .running: return ("Trabajando", Color(hex: 0x12B5A8))
            case .paused: return ("En pausa", pal.muted)
            case .finished: return (day.didWork ? "Jornada finalizada" : "Día sin trabajo", pal.primary)
            case .overtimeRunning: return ("Horas extra", pal.gold)
            case .overtimePaused: return ("Horas extra · en pausa", pal.gold)
            case .overtimeFinished: return ("Día completo", pal.primary)
            }
        }()
        return HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text)
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(pal.sub)
        }
    }

    private var staleBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "moon.stars.fill")
                .foregroundStyle(pal.goldDeep)
            Text("Esta jornada empezó el \(Fmt.dayTitle(day.date).lowercased()) y sigue abierta. Finalízala para empezar el día de hoy.")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(pal.goldDeep)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(pal.goldSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(pal.goldBorder, lineWidth: 1))
    }

    // MARK: Ilustración

    private var orb: some View {
        Button {
            store.tapOrb()
        } label: {
            FocusOrb(style: prefs.s.orbStyle, mood: OrbMood(phase), palette: pal)
                .frame(height: 320)
                .frame(maxWidth: .infinity)
                .contentShape(Circle().inset(by: 40))
        }
        .buttonStyle(OrbPressStyle())
        .accessibilityLabel(orbAccessibility)
    }

    private var orbAccessibility: String {
        switch phase {
        case .idle: return "Comenzar a trabajar"
        case .running, .overtimeRunning: return "Pausar"
        case .paused, .overtimePaused: return "Continuar"
        case .finished, .overtimeFinished: return "Jornada finalizada"
        }
    }

    // MARK: Cronómetro

    private var clock: some View {
        TimelineView(.periodic(from: .now, by: 1)) { tl in
            let now = tl.date
            VStack(spacing: 8) {
                Text(Fmt.clock(mainSeconds(now)))
                    .font(.system(size: 60, weight: .thin).monospacedDigit())
                    .tracking(-1)
                    .foregroundStyle(clockColor)
                    .contentTransition(.numericText())
                Text(statusText)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(pal.sub)
                Text(subline(now))
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                    .foregroundStyle(pal.muted)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func mainSeconds(_ now: Date) -> TimeInterval {
        switch phase {
        case .idle: return 0
        case .running, .overtimeRunning: return day.openSession?.duration(now: now) ?? 0
        case .paused, .overtimePaused: return day.openPause?.duration(now: now) ?? 0
        case .finished: return day.focused(.normal, now: now)
        case .overtimeFinished: return day.focused(nil, now: now)
        }
    }

    private var clockColor: Color {
        switch phase {
        case .paused, .overtimePaused: return pal.muted
        case .overtimeRunning: return pal.goldDeep
        default: return pal.ink
        }
    }

    private var statusText: String {
        switch phase {
        case .idle: return "Toca para comenzar a trabajar"
        case .running: return "Trabajando…"
        case .paused: return "En pausa — toca para continuar"
        case .finished: return day.didWork ? "Tiempo enfocado hoy" : "Marcaste hoy como día sin trabajo"
        case .overtimeRunning: return "Horas extra en curso…"
        case .overtimePaused: return "Horas extra en pausa — toca para seguir"
        case .overtimeFinished: return "Enfocado hoy, con horas extra"
        }
    }

    private func subline(_ now: Date) -> String {
        let focused = day.focused(.normal, now: now)
        let pauses = day.pauseCount(.normal)
        switch phase {
        case .idle:
            guard let plan = day.plan, plan.enabled, plan.minutes > 0 else {
                return "Hoy no tienes horario de trabajo"
            }
            return "Horario \(Fmt.clockTime(plan.start, prefs.s.use24h))–\(Fmt.clockTime(plan.end, prefs.s.use24h)) · meta \(Fmt.hm(Double(plan.minutes) * 60))"
        case .running, .paused:
            return "Hoy \(Fmt.hm(focused)) enfocado · \(pauses) \(pauses == 1 ? "pausa" : "pausas")"
        case .finished:
            if let r = day.focusRatio(.normal, now: now) {
                return "Focus \(Fmt.percent(r)) · \(pauses) \(pauses == 1 ? "pausa" : "pausas")"
            }
            return " "
        case .overtimeRunning, .overtimePaused, .overtimeFinished:
            return "Extra \(Fmt.hm(day.focused(.overtime, now: now))) · Jornada \(Fmt.hm(focused))"
        }
    }

    // MARK: Día cerrado

    @ViewBuilder
    private var closedSection: some View {
        if phase.isClosed {
            VStack(spacing: 12) {
                if day.didWork && day.hasData {
                    DaySummaryCard(day: day)
                }
                if !store.currentIsStale {
                    PrimaryButton(title: phase == .finished ? "Iniciar horas extra" : "Retomar horas extra",
                                  icon: "bolt.fill", gold: true) {
                        withAnimation(.easeInOut(duration: 0.3)) { store.startOvertime() }
                    }
                }
                if phase == .finished && !day.sessions.contains(where: { $0.kind == .overtime }) && day.hasData {
                    Button("¿La cerraste por error? Reabrir jornada") { confirmReopen = true }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(pal.sub)
                        .padding(.top, 2)
                }
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    // MARK: Historial de hoy

    @ViewBuilder
    private var todayFeed: some View {
        let items = day.timeline()
        if !items.isEmpty {
            VStack(spacing: 10) {
                SectionLabel(store.currentIsStale ? "Esta jornada" : "Hoy")
                DayTimeline(items: items, compact: true)
                    .card(padding: 16, radius: 18)
            }
        }
    }
}

/// La ilustración se hunde un poco al tocarla.
struct OrbPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

/// Resumen del día cerrado: tiempos, focus, tareas y horas extra.
struct DaySummaryCard: View {
    @Environment(\.palette) private var pal
    var day: WorkDay
    var now: Date = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                metric(Fmt.hm(day.focused(.normal, now: now)), "enfocado")
                metric(Fmt.hm(day.paused(.normal, now: now)), "en pausa")
                metric(day.focusRatio(.normal, now: now).map(Fmt.percent) ?? "—", "focus", accent: true)
            }
            let normalTasks = day.tasks.filter { !$0.overtime }
            if !normalTasks.isEmpty {
                tasks(normalTasks)
            }
            let extra = day.focused(.overtime, now: now)
            if extra > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("+ \(Fmt.hm(extra)) de horas extra")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(pal.goldDeep)
                    let otTasks = day.tasks.filter { $0.overtime }
                    if !otTasks.isEmpty { tasks(otTasks) }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(pal.goldSoft, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(pal.goldBorder, lineWidth: 1))
            }
        }
        .card()
    }

    private func metric(_ value: String, _ label: String, accent: Bool = false) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 19, weight: .heavy).monospacedDigit())
                .foregroundStyle(accent ? pal.primary : pal.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(pal.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(pal.bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func tasks(_ list: [TaskEntry]) -> some View {
        FlowLayout(spacing: 6, lineSpacing: 6) {
            ForEach(list) { t in
                Text("✓ \(t.text)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(pal.text)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(pal.bg, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(pal.border, lineWidth: 1))
            }
        }
    }
}
