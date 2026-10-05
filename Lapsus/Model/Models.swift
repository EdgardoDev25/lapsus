import Foundation

/// Jornada normal u horas extra.
enum WorkKind: String, Codable {
    case normal, overtime
}

/// Máquina de estados del día. Un solo valor decide color, ilustración,
/// textos y botones visibles en la pantalla del timer.
enum DayPhase: String, Codable {
    case idle
    case running
    case paused
    case finished
    case overtimeRunning
    case overtimePaused
    case overtimeFinished

    var isRunning: Bool { self == .running || self == .overtimeRunning }
    var isPaused: Bool { self == .paused || self == .overtimePaused }
    /// Hay un bloque abierto (corriendo o en pausa).
    var isActive: Bool { isRunning || isPaused }
    var isOvertime: Bool { self == .overtimeRunning || self == .overtimePaused || self == .overtimeFinished }
    var isClosed: Bool { self == .finished || self == .overtimeFinished }
    var kind: WorkKind { isOvertime ? .overtime : .normal }
}

/// Bloque continuo de trabajo entre un inicio y la siguiente pausa o cierre.
struct FocusSession: Codable, Identifiable, Equatable {
    var id = UUID()
    var kind: WorkKind
    var start: Date
    var end: Date?

    func duration(now: Date) -> TimeInterval {
        max(0, (end ?? now).timeIntervalSince(start))
    }
}

/// Una pausa con lo que la persona hizo en ella. Es el dato más valioso de la app.
struct PauseEvent: Codable, Identifiable, Equatable {
    var id = UUID()
    var kind: WorkKind
    var start: Date
    var end: Date?
    /// Ids del catálogo `PauseCategory`.
    var categories: [String] = []
    var note: String = ""

    init(kind: WorkKind, start: Date) {
        self.kind = kind
        self.start = start
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        kind = try c.decodeIfPresent(WorkKind.self, forKey: .kind) ?? .normal
        start = try c.decode(Date.self, forKey: .start)
        end = try c.decodeIfPresent(Date.self, forKey: .end)
        categories = try c.decodeIfPresent([String].self, forKey: .categories) ?? []
        note = try c.decodeIfPresent(String.self, forKey: .note) ?? ""
    }

    func duration(now: Date) -> TimeInterval {
        max(0, (end ?? now).timeIntervalSince(start))
    }

    var categoryNames: String {
        categories.compactMap { PauseCategory.byID[$0]?.short }.joined(separator: ", ")
    }
}

/// Tarea realizada, anotada al cerrar el día o las horas extra.
struct TaskEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    var text: String
    var overtime: Bool
    var date: Date
}

struct WorkDay: Codable, Identifiable, Equatable {
    /// "AAAA-MM-DD" del día en que empezó la jornada.
    var id: String
    /// Medianoche de ese día.
    var date: Date
    var phase: DayPhase = .idle
    var sessions: [FocusSession] = []
    var pauses: [PauseEvent] = []
    var tasks: [TaskEntry] = []
    var goalMinutes: Int
    var finishedAt: Date?
    var overtimeFinishedAt: Date?
    /// "¿Trabajaste hoy?" → No. El día queda guardado pero fuera de las estadísticas.
    var didWork = true

    init(date: Date, goalMinutes: Int) {
        self.id = Fmt.dayID(date)
        self.date = Fmt.cal.startOfDay(for: date)
        self.goalMinutes = goalMinutes
    }

    /// Tolerante con versiones anteriores: si falta una clave, usa el valor por defecto.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        date = try c.decode(Date.self, forKey: .date)
        phase = try c.decodeIfPresent(DayPhase.self, forKey: .phase) ?? .idle
        sessions = try c.decodeIfPresent([FocusSession].self, forKey: .sessions) ?? []
        pauses = try c.decodeIfPresent([PauseEvent].self, forKey: .pauses) ?? []
        tasks = try c.decodeIfPresent([TaskEntry].self, forKey: .tasks) ?? []
        goalMinutes = try c.decodeIfPresent(Int.self, forKey: .goalMinutes) ?? 480
        finishedAt = try c.decodeIfPresent(Date.self, forKey: .finishedAt)
        overtimeFinishedAt = try c.decodeIfPresent(Date.self, forKey: .overtimeFinishedAt)
        didWork = try c.decodeIfPresent(Bool.self, forKey: .didWork) ?? true
    }

    // MARK: Bloques abiertos

    var openSessionIndex: Int? {
        sessions.lastIndex { $0.end == nil }
    }

    var openPauseIndex: Int? {
        pauses.lastIndex { $0.end == nil }
    }

    var openPause: PauseEvent? {
        openPauseIndex.map { pauses[$0] }
    }

    var openSession: FocusSession? {
        openSessionIndex.map { sessions[$0] }
    }

    // MARK: Totales

    /// Segundos trabajados. `kind == nil` suma jornada y horas extra.
    func focused(_ kind: WorkKind? = .normal, now: Date = Date()) -> TimeInterval {
        sessions.filter { kind == nil || $0.kind == kind }.reduce(0) { $0 + $1.duration(now: now) }
    }

    func paused(_ kind: WorkKind? = .normal, now: Date = Date()) -> TimeInterval {
        pauses.filter { kind == nil || $0.kind == kind }.reduce(0) { $0 + $1.duration(now: now) }
    }

    /// Enfocado ÷ (enfocado + pausado). nil si todavía no hay datos.
    func focusRatio(_ kind: WorkKind? = .normal, now: Date = Date()) -> Double? {
        let f = focused(kind, now: now), p = paused(kind, now: now)
        guard f + p > 0 else { return nil }
        return f / (f + p)
    }

    func pauseCount(_ kind: WorkKind? = .normal) -> Int {
        pauses.filter { kind == nil || $0.kind == kind }.count
    }

    var start: Date? { sessions.first?.start }
    var end: Date? { overtimeFinishedAt ?? finishedAt }

    /// Bloque sin pausas más largo (deep work).
    func longestBlock(now: Date = Date()) -> TimeInterval {
        sessions.map { $0.duration(now: now) }.max() ?? 0
    }

    var hasData: Bool { !sessions.isEmpty }

    /// Cuenta para estadísticas: trabajó y hay datos.
    var counts: Bool { didWork && hasData }

    /// Se cumplió la meta diaria (solo jornada normal).
    var metGoal: Bool {
        counts && focused(.normal) >= Double(goalMinutes) * 60
    }
}

// MARK: - Línea de tiempo

struct TimelineItem: Identifiable {
    enum Kind {
        case start, resume, pause, end, overtimeStart, overtimeEnd
    }

    var id: String
    var date: Date
    var kind: Kind
    var title: String
    var detail: String?
    /// Id de la primera categoría (pausas), para el color del punto.
    var category: String?
    var overtime: Bool
}

extension WorkDay {
    /// Eventos del día en orden: inicio, pausas, reanudaciones y cierres.
    /// Se deduce de sesiones y pausas: un inicio de sesión que coincide con el fin
    /// de una pausa es una reanudación; un fin de sesión sin pausa es un cierre.
    func timeline(now: Date = Date()) -> [TimelineItem] {
        var items: [TimelineItem] = []
        func near(_ a: Date, _ b: Date?) -> Bool {
            guard let b else { return false }
            return abs(a.timeIntervalSince(b)) < 1
        }

        for s in sessions {
            let ot = s.kind == .overtime
            let resumed = pauses.contains { $0.kind == s.kind && near(s.start, $0.end) }
            if resumed {
                items.append(TimelineItem(id: "r-\(s.id)", date: s.start, kind: .resume, title: "Reanudado", detail: nil, category: nil, overtime: ot))
            } else {
                items.append(TimelineItem(id: "s-\(s.id)", date: s.start, kind: ot ? .overtimeStart : .start,
                                          title: ot ? "Inicio de horas extra" : "Inicio de jornada", detail: nil, category: nil, overtime: ot))
            }
            if let end = s.end, !pauses.contains(where: { $0.kind == s.kind && near(end, $0.start) }) {
                items.append(TimelineItem(id: "e-\(s.id)", date: end, kind: ot ? .overtimeEnd : .end,
                                          title: ot ? "Fin de horas extra" : "Fin de jornada", detail: nil, category: nil, overtime: ot))
            }
        }

        for p in pauses {
            let mins = Fmt.minutes(p.duration(now: now))
            let names = p.categoryNames
            let title: String
            if p.end == nil {
                title = "En pausa"
            } else {
                title = names.isEmpty ? "Pausa \(mins)" : "Pausa \(mins) · \(names)"
            }
            let note = p.note.trimmingCharacters(in: .whitespacesAndNewlines)
            items.append(TimelineItem(id: "p-\(p.id)", date: p.start, kind: .pause, title: title,
                                      detail: note.isEmpty ? nil : "“\(note)”", category: p.categories.first, overtime: p.kind == .overtime))
        }

        return items.sorted { a, b in
            if a.date != b.date { return a.date < b.date }
            // A la misma hora: el fin de un bloque va antes del inicio del siguiente.
            return order(a.kind) < order(b.kind)
        }
    }

    private func order(_ k: TimelineItem.Kind) -> Int {
        switch k {
        case .end, .overtimeEnd: return 0
        case .pause: return 1
        case .resume, .start, .overtimeStart: return 2
        }
    }
}
