import SwiftUI

/// Todos los días registrados y la máquina de estados del día en curso.
/// Se guarda en un JSON local (Application Support); no hay servidor ni cuenta.
@MainActor
final class WorkStore: ObservableObject {
    /// Ordenados del más antiguo al más reciente.
    @Published private(set) var days: [WorkDay] = []
    /// Id del día que muestra el timer. Puede ser de ayer si la jornada quedó abierta.
    @Published private(set) var currentID: String
    /// Se tocó la ilustración estando en pausa: hay que preguntar "¿Qué hacías?".
    @Published var askResume = false

    private let prefs: Preferences
    private let fileURL: URL

    init(prefs: Preferences) {
        self.prefs = prefs
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Lapsus", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("dias.json")
        currentID = Fmt.dayID(Date())

        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode(SavedState.self, from: data) {
            days = saved.days.sorted { $0.id < $1.id }
            currentID = saved.currentID
        }
        rollover()
    }

    private struct SavedState: Codable {
        var version = 1
        var currentID: String
        var days: [WorkDay]
    }

    // MARK: Día en curso

    var current: WorkDay {
        days.first { $0.id == currentID } ?? newDay()
    }

    var phase: DayPhase { current.phase }

    /// La jornada abierta es de un día anterior (no se cerró antes de medianoche).
    var currentIsStale: Bool { currentID != Fmt.dayID(Date()) }

    /// Días anteriores con datos, del más reciente al más antiguo.
    var history: [WorkDay] {
        days.filter { $0.hasData }.reversed()
    }

    func day(_ id: String) -> WorkDay? {
        days.first { $0.id == id }
    }

    /// Si el día visible ya terminó (o quedó sin usar) y cambió la fecha, abre el día de hoy.
    /// Una jornada abierta de ayer se respeta hasta que se cierre.
    func rollover() {
        let todayID = Fmt.dayID(Date())
        if let cur = days.first(where: { $0.id == currentID }), cur.phase.isActive {
            return
        }
        if currentID != todayID {
            // Un día sin nada registrado no vale la pena guardarlo.
            days.removeAll { $0.id == currentID && !$0.hasData }
            currentID = todayID
        }
        if !days.contains(where: { $0.id == todayID }) {
            days.append(newDay())
            days.sort { $0.id < $1.id }
        }
        save()
    }

    private func mutateCurrent(_ change: (inout WorkDay) -> Void) {
        guard let i = days.firstIndex(where: { $0.id == currentID }) else {
            var d = newDay()
            change(&d)
            days.append(d)
            days.sort { $0.id < $1.id }
            save()
            return
        }
        change(&days[i])
        save()
    }

    // MARK: Gesto central

    /// Tocar la ilustración: iniciar, pausar o pedir el "¿Qué hacías?" para reanudar.
    func tapOrb() {
        let now = Date()
        switch phase {
        case .idle:
            mutateCurrent { d in
                d.sessions.append(FocusSession(kind: .normal, start: now))
                d.phase = .running
            }
            Haptics.orb()
        case .running, .overtimeRunning:
            mutateCurrent { d in
                let kind = d.phase.kind
                if let i = d.openSessionIndex { d.sessions[i].end = now }
                d.pauses.append(PauseEvent(kind: kind, start: now))
                d.phase = kind == .overtime ? .overtimePaused : .paused
            }
            Haptics.pause()
            if prefs.s.pauseReminder {
                Notifier.schedulePauseReminder(after: prefs.s.pauseReminderMinutes)
            }
        case .paused, .overtimePaused:
            Haptics.tap()
            askResume = true
        case .finished, .overtimeFinished:
            Haptics.tick()
        }
    }

    /// Cierra la pausa con lo que hizo la persona y vuelve a correr el reloj.
    func resume(categories: [String], note: String) {
        guard phase.isPaused, !categories.isEmpty else { return }
        let now = Date()
        mutateCurrent { d in
            let kind = d.phase.kind
            if let i = d.openPauseIndex {
                d.pauses[i].end = now
                d.pauses[i].categories = categories
                d.pauses[i].note = note.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            d.sessions.append(FocusSession(kind: kind, start: now))
            d.phase = kind == .overtime ? .overtimeRunning : .running
        }
        askResume = false
        Notifier.cancelPauseReminder()
        Haptics.success()
    }

    // MARK: Cierre

    /// Momento en que termina el bloque si se cierra ahora: si está en pausa,
    /// el trabajo terminó cuando empezó la pausa.
    func closingTime(now: Date = Date()) -> Date {
        current.openPause?.start ?? now
    }

    /// Cierra la jornada normal (o las horas extra) en `at`.
    /// La pausa abierta, si la había, se descarta: no fue pausa, fue el final.
    func finish(at: Date, didWork: Bool, tasks: [String]) {
        let kind = phase.kind
        guard phase.isActive || (phase == .idle && !didWork) else { return }
        mutateCurrent { d in
            if let i = d.openPauseIndex { d.pauses.remove(at: i) }
            if let i = d.openSessionIndex { d.sessions[i].end = max(d.sessions[i].start, at) }
            for t in tasks {
                let text = t.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    d.tasks.append(TaskEntry(text: text, overtime: kind == .overtime, date: at))
                }
            }
            if kind == .overtime {
                d.overtimeFinishedAt = at
                d.phase = .overtimeFinished
            } else {
                d.finishedAt = at
                d.didWork = didWork
                d.phase = .finished
            }
        }
        Notifier.cancelPauseReminder()
        Haptics.success()
        // Si era una jornada de ayer, pasa al día de hoy.
        if currentIsStale { rollover() }
    }

    /// Solo existe con el día cerrado.
    func startOvertime() {
        guard phase.isClosed, !currentIsStale else { return }
        let now = Date()
        mutateCurrent { d in
            d.sessions.append(FocusSession(kind: .overtime, start: now))
            d.phase = .overtimeRunning
        }
        Haptics.orb()
    }

    /// Reabre la jornada normal recién cerrada por error (solo si no hay horas extra).
    func reopenDay() {
        guard phase == .finished, !current.sessions.contains(where: { $0.kind == .overtime }),
              let lastEnd = current.finishedAt else { return }
        // El rato entre el cierre y ahora queda como una pausa, y se pregunta qué fue.
        mutateCurrent { d in
            d.pauses.append(PauseEvent(kind: .normal, start: lastEnd))
            d.finishedAt = nil
            d.didWork = true
            d.phase = .paused
        }
        askResume = true
    }

    /// Alguna pausa registrada usa esta categoría.
    func isCategoryUsed(_ id: String) -> Bool {
        days.contains { d in d.pauses.contains { $0.categories.contains(id) } }
    }

    /// Día nuevo con una copia del horario vigente para hoy.
    private func newDay(_ date: Date = Date()) -> WorkDay {
        WorkDay(date: date, plan: prefs.s.schedule.plan(for: date))
    }

    /// Cambio de horario en Ajustes: aplica desde hoy (si el día sigue abierto).
    /// Los días anteriores conservan el horario con el que se registraron.
    func applySchedule() {
        guard !phase.isClosed, !currentIsStale else { return }
        let plan = prefs.s.schedule.plan(for: current.date)
        guard current.plan != plan else { return }
        mutateCurrent { d in
            d.plan = plan
            d.goalMinutes = plan.minutes
        }
    }

    // MARK: Datos

    func deleteAll() {
        days.removeAll()
        currentID = Fmt.dayID(Date())
        askResume = false
        Notifier.cancelPauseReminder()
        rollover()
    }

    func saveNow() { save() }

    private func save() {
        let state = SavedState(currentID: currentID, days: days)
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
