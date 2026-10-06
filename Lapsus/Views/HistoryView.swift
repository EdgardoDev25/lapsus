import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: WorkStore
    @Environment(\.palette) private var pal

    @State private var month = Fmt.cal.dateInterval(of: .month, for: Date())?.start ?? Date()
    @State private var expandedID: String?
    @State private var didPickDefault = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ScreenTitle(title: "Historial")
                    calendar
                        .padding(.top, 16)
                    SectionLabel("Días recientes")
                        .padding(.top, 24)
                        .padding(.bottom, 10)
                    if store.history.isEmpty {
                        empty
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(store.history) { d in
                                DayCard(day: d, expanded: expandedID == d.id) {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                        expandedID = expandedID == d.id ? nil : d.id
                                    }
                                    Haptics.tick()
                                }
                                .id(d.id)
                            }
                        }
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .background(pal.bg.ignoresSafeArea())
            .onAppear {
                if !didPickDefault {
                    expandedID = store.history.first?.id
                    didPickDefault = true
                }
            }
            .onChange(of: expandedID) { _, id in
                guard let id else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation { proxy.scrollTo(id, anchor: .top) }
                }
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 30))
                .foregroundStyle(pal.faint)
            Text("Todavía no hay días registrados.")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(pal.sub)
            Text("Toca la ilustración en el Timer para empezar tu primera jornada.")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(pal.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .card(padding: 26)
    }

    // MARK: Mapa de calor del mes

    private var calendar: some View {
        let cells = monthCells()
        let byID = Dictionary(store.days.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let todayID = Fmt.dayID(Date())
        return VStack(spacing: 12) {
            HStack {
                Text(Fmt.monthTitle(month))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(pal.text)
                Spacer()
                HStack(spacing: 18) {
                    Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                    Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                        .disabled(isCurrentMonth)
                        .opacity(isCurrentMonth ? 0.3 : 1)
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(pal.sub)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(Array(Fmt.weekInitials.enumerated()), id: \.offset) { _, d in
                    Text(d)
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(pal.faint)
                }
                ForEach(Array(cells.enumerated()), id: \.offset) { _, date in
                    if let date {
                        let id = Fmt.dayID(date)
                        cell(date: date, day: byID[id], isToday: id == todayID)
                    } else {
                        Color.clear.aspectRatio(1, contentMode: .fit)
                    }
                }
            }
            HStack(spacing: 6) {
                Spacer()
                Text("menos")
                ForEach(0..<5, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 3).fill(heat(level)).frame(width: 11, height: 11)
                }
                Text("más")
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(pal.faint)
        }
        .card(padding: 16)
    }

    private func cell(date: Date, day: WorkDay?, isToday: Bool) -> some View {
        let level = heatLevel(day)
        let future = date > Date()
        return Button {
            if let day, day.hasData {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { expandedID = day.id }
                Haptics.tick()
            }
        } label: {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(future ? Color.clear : heat(level))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(isToday ? pal.primary : (future ? pal.border : Color.clear), lineWidth: isToday ? 1.5 : 1)
                }
                .overlay {
                    Text("\(Fmt.cal.component(.day, from: date))")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(level >= 3 ? Color.white.opacity(0.9) : pal.muted.opacity(future ? 0.5 : 0.9))
                }
                .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
    }

    private func heat(_ level: Int) -> Color {
        switch level {
        case 0: return pal.track
        case 1: return pal.primary.opacity(0.22)
        case 2: return pal.primary.opacity(0.42)
        case 3: return pal.primary.opacity(0.7)
        default: return pal.primary
        }
    }

    /// Intensidad según horas enfocadas contra la meta del día.
    private func heatLevel(_ day: WorkDay?) -> Int {
        guard let day, day.counts else { return 0 }
        // Los días libres se comparan contra 8 h para que igual se vean en el mapa.
        let goal = Double(day.hasGoal ? day.goalMinutes : 480) * 60
        let v = day.focused(nil) / goal
        switch v {
        case ..<0.25: return 1
        case ..<0.5: return 2
        case ..<0.85: return 3
        default: return 4
        }
    }

    /// Fechas del mes con huecos al inicio para que el día 1 caiga en su columna (lunes primero).
    private func monthCells() -> [Date?] {
        guard let range = Fmt.cal.range(of: .day, in: .month, for: month) else { return [] }
        let weekday = Fmt.cal.component(.weekday, from: month) // 1 = domingo
        let offset = (weekday + 5) % 7
        var cells: [Date?] = Array(repeating: nil, count: offset)
        for d in range {
            cells.append(Fmt.cal.date(byAdding: .day, value: d - 1, to: month))
        }
        return cells
    }

    private var isCurrentMonth: Bool {
        Fmt.cal.isDate(month, equalTo: Date(), toGranularity: .month)
    }

    private func shiftMonth(_ delta: Int) {
        if let m = Fmt.cal.date(byAdding: .month, value: delta, to: month) {
            month = m
            Haptics.tick()
        }
    }
}

/// Fila de un día: compacta (barra de horas) o abierta (línea de tiempo completa).
struct DayCard: View {
    @Environment(\.palette) private var pal
    var day: WorkDay
    var expanded: Bool
    var onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onTap) {
                if expanded { expandedHeader } else { compactRow }
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 0) {
                    Rectangle().fill(pal.divider).frame(height: 1).padding(.vertical, 15)
                    if day.didWork {
                        DayTimeline(items: day.timeline())
                        tasks
                        overtimeBadge
                    } else {
                        Text("Marcado como día sin trabajo.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(pal.sub)
                    }
                }
                .transition(.opacity)
            }
        }
        .card(padding: expanded ? 18 : 15, radius: expanded ? 20 : 16)
    }

    private var focused: TimeInterval { day.focused(.normal) }
    private var ratio: Double? { day.focusRatio(.normal) }

    private var compactRow: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 1) {
                Text(Fmt.weekdayShort(day.date))
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(pal.ink)
                Text(Fmt.dayShort(day.date))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(pal.muted)
            }
            .frame(width: 50, alignment: .leading)
            VStack(alignment: .leading, spacing: 5) {
                ProgressBar(value: ratio ?? 0)
                Text(day.didWork ? "\(Fmt.hm(focused)) enfocado" : "Sin trabajo")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(pal.sub)
            }
            Text(ratio.map(Fmt.percent) ?? "—")
                .font(.system(size: 15, weight: .heavy).monospacedDigit())
                .foregroundStyle(pal.text)
                .frame(minWidth: 42, alignment: .trailing)
        }
        .contentShape(Rectangle())
    }

    private var expandedHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Fmt.dayTitle(day.date))
                    .font(.system(size: 15.5, weight: .heavy))
                    .foregroundStyle(pal.ink)
                let n = day.pauseCount(.normal)
                Text("\(Fmt.hm(focused)) enfocado · \(n) \(n == 1 ? "pausa" : "pausas")")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(pal.sub)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text(ratio.map(Fmt.percent) ?? "—")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundStyle(pal.primary)
                Text("focus")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(pal.muted)
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var tasks: some View {
        let list = day.tasks.filter { !$0.overtime }
        if !list.isEmpty {
            FlowLayout(spacing: 6, lineSpacing: 6) {
                ForEach(list) { t in taskChip(t.text) }
            }
            .padding(.top, 14)
        }
    }

    @ViewBuilder
    private var overtimeBadge: some View {
        let extra = day.focused(.overtime)
        if extra > 0 {
            VStack(alignment: .leading, spacing: 8) {
                Text("+ \(Fmt.hm(extra)) de horas extra")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(pal.goldDeep)
                let list = day.tasks.filter { $0.overtime }
                if !list.isEmpty {
                    FlowLayout(spacing: 6, lineSpacing: 6) {
                        ForEach(list) { t in taskChip(t.text) }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(pal.goldSoft, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(pal.goldBorder, lineWidth: 1))
            .padding(.top, 12)
        }
    }

    private func taskChip(_ text: String) -> some View {
        Text("✓ \(text)")
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(pal.text)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(pal.bg, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(pal.border, lineWidth: 1))
    }
}
