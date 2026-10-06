import SwiftUI

/// Lista de los 7 días, cada uno con su horario. Se usa en Ajustes y en el onboarding.
struct ScheduleEditor: View {
    @Environment(\.palette) private var pal
    @Binding var schedule: WorkSchedule
    var use24h: Bool

    @State private var expanded: Int?

    init(schedule: Binding<WorkSchedule>, use24h: Bool) {
        _schedule = schedule
        self.use24h = use24h
    }

    var body: some View {
        VStack(spacing: 10) {
            ForEach(0..<7, id: \.self) { i in
                dayRow(i)
            }
        }
    }

    private func dayRow(_ i: Int) -> some View {
        let plan = schedule.days[i]
        let open = expanded == i && plan.enabled
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        expanded = expanded == i ? nil : i
                    }
                    Haptics.tick()
                } label: {
                    HStack(spacing: 12) {
                        Text(Fmt.weekInitials[i])
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundStyle(plan.enabled ? .white : pal.muted)
                            .frame(width: 30, height: 30)
                            .background(plan.enabled ? AnyShapeStyle(pal.gradient) : AnyShapeStyle(pal.track), in: Circle())
                        VStack(alignment: .leading, spacing: 1) {
                            Text(Fmt.weekdaysMonFirst[i])
                                .font(.system(size: 14.5, weight: .bold))
                                .foregroundStyle(pal.ink)
                            Text(subtitle(plan))
                                .font(.system(size: 12, weight: .medium).monospacedDigit())
                                .foregroundStyle(plan.isValid ? pal.sub : pal.bad)
                        }
                        Spacer(minLength: 0)
                        if plan.enabled {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(pal.faint)
                                .rotationEffect(.degrees(open ? 180 : 0))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Toggle("", isOn: Binding(
                    get: { schedule.days[i].enabled },
                    set: { on in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            schedule.days[i].enabled = on
                            if on {
                                expanded = i
                            } else if expanded == i {
                                expanded = nil
                            }
                        }
                    }
                ))
                .labelsHidden()
                .tint(pal.primary)
            }

            if open {
                VStack(spacing: 12) {
                    Rectangle().fill(pal.divider).frame(height: 1)
                    timeRow("Entrada", minutes: Binding(
                        get: { schedule.days[i].start },
                        set: { schedule.days[i].start = $0 }
                    ))
                    timeRow("Salida", minutes: Binding(
                        get: { schedule.days[i].end },
                        set: { schedule.days[i].end = $0 }
                    ))
                    HStack {
                        Text("Descanso (almuerzo)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(pal.text)
                        Spacer()
                        stepButton("minus", enabled: plan.breakMinutes > 0) {
                            schedule.days[i].breakMinutes = max(0, plan.breakMinutes - 15)
                        }
                        Text(plan.breakMinutes == 0 ? "Sin" : Fmt.hm(Double(plan.breakMinutes) * 60))
                            .font(.system(size: 14, weight: .bold).monospacedDigit())
                            .foregroundStyle(pal.primary)
                            .frame(minWidth: 58)
                        stepButton("plus", enabled: plan.breakMinutes < 240) {
                            schedule.days[i].breakMinutes = min(240, plan.breakMinutes + 15)
                        }
                    }
                    if !plan.isValid {
                        Text("La salida tiene que ser después de la entrada más el descanso.")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(pal.bad)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Button {
                        copyToOthers(i)
                    } label: {
                        Label("Usar este horario en los demás días activos", systemImage: "doc.on.doc")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(pal.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 12)
                .transition(.opacity)
            }
        }
        .card(padding: 14, radius: 16)
    }

    private func subtitle(_ plan: DayPlan) -> String {
        guard plan.enabled else { return "Día libre" }
        let hours = "\(Fmt.clockTime(plan.start, use24h)) – \(Fmt.clockTime(plan.end, use24h))"
        guard plan.isValid else { return "\(hours) · revisa las horas" }
        return "\(hours) · \(Fmt.hm(Double(plan.minutes) * 60))"
    }

    private func timeRow(_ title: String, minutes: Binding<Int>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(pal.text)
            Spacer()
            DatePicker(title, selection: dateBinding(minutes), displayedComponents: .hourAndMinute)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: use24h ? "es_ES" : "en_US"))
        }
    }

    /// El DatePicker trabaja con fechas; el horario, con minutos desde la medianoche.
    private func dateBinding(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding(
            get: {
                let base = Fmt.cal.startOfDay(for: Date())
                return Fmt.cal.date(byAdding: .minute, value: minutes.wrappedValue, to: base) ?? base
            },
            set: { date in
                let c = Fmt.cal.dateComponents([.hour, .minute], from: date)
                minutes.wrappedValue = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            }
        )
    }

    private func stepButton(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            Haptics.tick()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(pal.primary)
                .frame(width: 30, height: 30)
                .background(pal.primarySoft, in: Circle())
        }
        .buttonStyle(PressStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }

    private func copyToOthers(_ i: Int) {
        let source = schedule.days[i]
        for j in 0..<7 where j != i && schedule.days[j].enabled {
            schedule.days[j].start = source.start
            schedule.days[j].end = source.end
            schedule.days[j].breakMinutes = source.breakMinutes
        }
        Haptics.success()
    }
}

/// Hoja de Ajustes → Horario de trabajo.
struct ScheduleSheet: View {
    @EnvironmentObject private var prefs: Preferences
    @EnvironmentObject private var store: WorkStore
    @Environment(\.palette) private var pal
    @Environment(\.dismiss) private var dismiss

    @State private var draft = WorkSchedule.standard
    @State private var loaded = false

    init() {}

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Define la entrada, la salida y el descanso de cada día. Tu meta diaria sale de aquí.")
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(pal.sub)
                        .fixedSize(horizontal: false, vertical: true)
                    ScheduleEditor(schedule: $draft, use24h: prefs.s.use24h)
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(pal.primary)
                        Text("Los cambios cuentan desde hoy. Los días que ya registraste conservan el horario que tenían, así tus estadísticas anteriores no cambian.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(pal.sub)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 4)
                    Text("Semana: \(Fmt.hm(Double(draft.weeklyMinutes) * 60)) en \(draft.workDays) días")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(pal.text)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .background(pal.bg.ignoresSafeArea())
            .navigationTitle("Horario de trabajo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(pal.bg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        prefs.s.schedule = draft
                        store.applySchedule()
                        Haptics.success()
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(!draft.days.allSatisfy(\.isValid))
                }
            }
        }
        .tint(pal.primary)
        .onAppear {
            if !loaded {
                draft = prefs.s.schedule
                loaded = true
            }
        }
    }
}
