import Charts
import SwiftUI

private struct Delta: Identifiable {
    var value: String
    var label: String
    var good: Bool
    var id: String { label }
}

struct StatsView: View {
    @EnvironmentObject private var store: WorkStore
    @EnvironmentObject private var prefs: Preferences
    @Environment(\.palette) private var pal

    @State private var weekStart = Stats.weekStart(Date())

    var body: some View {
        // Se recalcula cada minuto para que el día en curso se vea al día.
        TimelineView(.periodic(from: .now, by: 60)) { tl in
            let now = tl.date
            let w = Stats.week(weekStart, days: store.days, now: now)
            let prevStart = Fmt.cal.date(byAdding: .day, value: -7, to: weekStart) ?? weekStart
            let p = Stats.week(prevStart, days: store.days, now: now)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    if w.hasData {
                        HStack(spacing: 12) {
                            goalCard(w)
                            streakCard
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)
                        barsCard(w)
                        ForEach(Stats.insights(w, previous: p), id: \.self) { text in
                            insightCard(text)
                        }
                        if !w.byGroup.isEmpty {
                            donutCard(w)
                        }
                        if p.hasData {
                            deltasCard(w, p)
                        }
                        HStack(spacing: 12) {
                            deepWorkCard(w)
                            overtimeCard(w)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        rankingCard(w, p)
                    } else {
                        emptyCard.padding(.top, 6)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
        }
        .background(pal.bg.ignoresSafeArea())
    }

    // MARK: Encabezado

    private var isCurrentWeek: Bool {
        Fmt.cal.isDate(weekStart, equalTo: Date(), toGranularity: .weekOfYear)
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            ScreenTitle(title: "Estadísticas", subtitle: Fmt.weekTitle(weekStart))
            HStack(spacing: 18) {
                Button { shiftWeek(-1) } label: { Image(systemName: "chevron.left") }
                Button { shiftWeek(1) } label: { Image(systemName: "chevron.right") }
                    .disabled(isCurrentWeek)
                    .opacity(isCurrentWeek ? 0.3 : 1)
            }
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(pal.sub)
            .padding(.bottom, 4)
        }
    }

    private func shiftWeek(_ delta: Int) {
        if let d = Fmt.cal.date(byAdding: .day, value: 7 * delta, to: weekStart) {
            withAnimation(.easeInOut(duration: 0.2)) { weekStart = d }
            Haptics.tick()
        }
    }

    private var emptyCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 30))
                .foregroundStyle(pal.faint)
            Text(isCurrentWeek ? "Aún no hay datos esta semana." : "No registraste días esta semana.")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(pal.sub)
            Text("Cada pausa que clasificas alimenta estas gráficas.")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(pal.muted)
        }
        .frame(maxWidth: .infinity)
        .card(padding: 26)
    }

    // MARK: Meta y racha

    private func goalCard(_ w: WeekStats) -> some View {
        let ratio = w.ratio ?? 0
        let goal = Double(prefs.s.goalMinutes) * 60
        let avg = w.focused / Double(max(1, w.worked.count))
        let met = goal > 0 ? avg / goal : 0
        return HStack(spacing: 14) {
            ZStack {
                Ring(value: ratio, lineWidth: 9)
                VStack(spacing: 0) {
                    Text(Fmt.percent(ratio))
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(pal.ink)
                    Text("focus")
                        .font(.system(size: 8.5, weight: .semibold))
                        .foregroundStyle(pal.muted)
                }
            }
            .frame(width: 70, height: 70)
            VStack(alignment: .leading, spacing: 2) {
                Text("Meta diaria")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(pal.sub)
                Text("\(Fmt.hm(goal)) · \(Fmt.percent(met)) cumplida")
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(pal.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .card(padding: 15)
        .frame(maxHeight: .infinity)
    }

    private var streakCard: some View {
        let n = Stats.streak(store.days)
        return VStack(alignment: .leading, spacing: 4) {
            Text("\(n)")
                .font(.system(size: 30, weight: .heavy))
                .foregroundStyle(.white)
            Text(n == 1 ? "día cumpliendo la meta" : "días seguidos cumpliendo la meta")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(15)
        .frame(width: 128, alignment: .leading)
        .frame(maxHeight: .infinity)
        .background(pal.gradient, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: pal.primary.opacity(0.28), radius: 14, x: 0, y: 10)
    }

    // MARK: Barras semanales

    private func barsCard(_ w: WeekStats) -> some View {
        let maxV = max(1, w.days.map { $0.focused + $0.overtime }.max() ?? 1)
        let bestID = w.best?.id, worstID = w.worst?.id
        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Horas trabajadas")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(pal.text)
                Spacer()
                Text("total \(Fmt.hm(w.focused))")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(pal.muted)
            }
            HStack(alignment: .bottom, spacing: 9) {
                ForEach(Array(w.days.enumerated()), id: \.element.id) { i, d in
                    bar(d, label: Fmt.weekInitials[i], maxV: maxV, isBest: d.id == bestID, isWorst: d.id == worstID)
                }
            }
            .frame(height: 170)
            .padding(.top, 14)
        }
        .card()
    }

    private func bar(_ d: DayStat, label: String, maxV: Double, isBest: Bool, isWorst: Bool) -> some View {
        let focusH = max(d.focused > 0 ? 4.0 : 3.0, 120.0 * d.focused / maxV)
        let extraH = max(3.0, 120.0 * d.overtime / maxV)
        let fill: AnyShapeStyle = isBest
            ? AnyShapeStyle(LinearGradient(colors: [pal.gradA, pal.primary], startPoint: .top, endPoint: .bottom))
            : AnyShapeStyle(pal.primary.opacity(isWorst ? 0.18 : 0.38))
        return VStack(spacing: 6) {
            Spacer(minLength: 0)
            if isBest || isWorst {
                Text(isBest ? "MEJOR" : "FLOJO")
                    .font(.system(size: 7.5, weight: .heavy))
                    .tracking(0.3)
                    .foregroundStyle(isBest ? pal.primary : pal.muted)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(isBest ? pal.primarySoft : pal.track, in: RoundedRectangle(cornerRadius: 5))
                    .fixedSize()
            }
            VStack(spacing: 0) {
                if d.overtime > 0 {
                    Rectangle().fill(pal.goldGradient).frame(height: extraH)
                }
                Rectangle().fill(fill).frame(height: focusH)
            }
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(pal.muted)
        }
        .frame(maxWidth: .infinity)
    }

    private func insightCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("INSIGHT")
                .font(.system(size: 11, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(pal.primary)
            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(pal.text)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(pal.primarySoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(pal.primary.opacity(0.18), lineWidth: 1))
    }

    // MARK: Dona de pausas

    private func donutCard(_ w: WeekStats) -> some View {
        let total = w.byGroup.reduce(0) { $0 + $1.seconds }
        return VStack(alignment: .leading, spacing: 12) {
            Text("¿Qué te roba el tiempo?")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(pal.text)
            HStack(spacing: 18) {
                Chart(w.byGroup) { s in
                    SectorMark(angle: .value("Tiempo", s.seconds), innerRadius: .ratio(0.6), angularInset: 1.5)
                        .cornerRadius(3)
                        .foregroundStyle(s.color)
                }
                .chartLegend(.hidden)
                .frame(width: 108, height: 108)
                .overlay {
                    VStack(spacing: 0) {
                        Text(Fmt.hm(total))
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundStyle(pal.ink)
                        Text("en pausa")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(pal.muted)
                    }
                }
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(w.byGroup.prefix(5)) { s in
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 3).fill(s.color).frame(width: 10, height: 10)
                            Text(s.name)
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(pal.text)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Spacer(minLength: 4)
                            Text(Fmt.percent(total > 0 ? s.seconds / total : 0))
                                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                                .foregroundStyle(pal.muted)
                        }
                    }
                }
            }
        }
        .card()
    }

    // MARK: Comparativa

    private func deltasCard(_ w: WeekStats, _ p: WeekStats) -> some View {
        var items: [Delta] = []
        if let r = w.ratio, let pr = p.ratio {
            let d = Int(((r - pr) * 100).rounded())
            items.append(Delta(value: (d >= 0 ? "+" : "−") + "\(abs(d))%", label: "focus ratio", good: d >= 0))
        }
        if p.distraction > 0 {
            let d = Int(((w.distraction - p.distraction) / p.distraction * 100).rounded())
            items.append(Delta(value: (d > 0 ? "+" : "−") + "\(abs(d))%", label: "tiempo en distracciones", good: d <= 0))
        }
        let dh = w.focused - p.focused
        items.append(Delta(value: (dh >= 0 ? "+" : "−") + Fmt.hm(abs(dh)), label: "horas enfocadas", good: dh >= 0))

        return VStack(alignment: .leading, spacing: 14) {
            Text("Esta semana vs. la anterior")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(pal.text)
            HStack(spacing: 10) {
                ForEach(items) { item in
                    VStack(spacing: 4) {
                        Text(item.value)
                            .font(.system(size: 20, weight: .heavy).monospacedDigit())
                            .foregroundStyle(item.good ? pal.good : pal.bad)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(item.label)
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(pal.sub)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 8)
                    .background(pal.bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
        .card()
    }

    // MARK: Deep work y horas extra

    private func deepWorkCard(_ w: WeekStats) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("DEEP WORK")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(pal.muted)
            Text(Fmt.hm(w.longest))
                .font(.system(size: 25, weight: .heavy))
                .foregroundStyle(pal.ink)
                .padding(.top, 2)
            Text("bloque sin pausas más largo")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(pal.sub)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .card(padding: 16)
        .frame(maxHeight: .infinity)
    }

    private func overtimeCard(_ w: WeekStats) -> some View {
        let maxOT = max(1, w.days.map(\.overtime).max() ?? 1)
        return VStack(alignment: .leading, spacing: 6) {
            Text("HORAS EXTRA")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(pal.goldDeep)
            Text(Fmt.hm(w.overtime))
                .font(.system(size: 25, weight: .heavy))
                .foregroundStyle(pal.goldDeep)
                .padding(.top, 2)
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(w.days) { d in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(d.overtime > 0 ? pal.gold : pal.goldBorder)
                        .frame(height: max(4, 26 * d.overtime / maxOT))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 26, alignment: .bottom)
            .padding(.top, 4)
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(pal.goldSoft, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(pal.goldBorder, lineWidth: 1))
    }

    // MARK: Ranking

    @ViewBuilder
    private func rankingCard(_ w: WeekStats, _ p: WeekStats) -> some View {
        let top = w.byCategory.filter { PauseCategory.byID[$0.id]?.weight.isDistraction == true }.prefix(3)
        if let first = top.first {
            let prevByID = Dictionary(p.byCategory.map { ($0.id, $0.seconds) }, uniquingKeysWith: { a, _ in a })
            VStack(alignment: .leading, spacing: 12) {
                Text("Top distracciones de la semana")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(pal.text)
                ForEach(Array(top.enumerated()), id: \.element.id) { i, s in
                    let prev = prevByID[s.id] ?? 0
                    let up = s.seconds > prev
                    HStack(spacing: 12) {
                        Text("\(i + 1)")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(pal.faint)
                            .frame(width: 16)
                        Text(s.name)
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(pal.text)
                            .frame(width: 96, alignment: .leading)
                            .lineLimit(1)
                        ProgressBar(value: s.seconds / first.seconds, height: 8,
                                    fill: AnyShapeStyle(LinearGradient(colors: [Color(hex: 0xE7C06A), Color(hex: 0xD99A2B)], startPoint: .leading, endPoint: .trailing)))
                        Text(Fmt.hm(s.seconds))
                            .font(.system(size: 11.5, weight: .semibold).monospacedDigit())
                            .foregroundStyle(pal.muted)
                            .frame(width: 48, alignment: .trailing)
                        if p.hasData {
                            Image(systemName: up ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(up ? pal.bad : pal.good)
                        }
                    }
                }
            }
            .card()
        }
    }
}
