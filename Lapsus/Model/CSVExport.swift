import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// Todos los registros en un CSV (una fila por bloque de trabajo, pausa o tarea).
/// Se arma en el momento de compartir, no antes.
struct CSVExport: Transferable {
    var days: [WorkDay]
    var use24h: Bool

    var fileName: String { "Lapsus-\(Fmt.dayID(Date())).csv" }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { item in
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(item.fileName)
            try item.csv().data(using: .utf8)?.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }

    func csv() -> String {
        var rows = ["fecha,jornada,registro,inicio,fin,minutos,categorias,grupo,nota"]
        let now = Date()
        for d in days where d.hasData {
            for s in d.sessions {
                rows.append(row([d.id, label(s.kind), "trabajo", Fmt.time(s.start, use24h),
                                 s.end.map { Fmt.time($0, use24h) } ?? "", mins(s.duration(now: now)), "", "", ""]))
            }
            for p in d.pauses {
                let cats = p.categories.compactMap { PauseCategory.byID[$0] }
                rows.append(row([d.id, label(p.kind), "pausa", Fmt.time(p.start, use24h),
                                 p.end.map { Fmt.time($0, use24h) } ?? "", mins(p.duration(now: now)),
                                 cats.map(\.name).joined(separator: " | "),
                                 Array(Set(cats.map(\.group.name))).sorted().joined(separator: " | "),
                                 p.note]))
            }
            for t in d.tasks {
                rows.append(row([d.id, label(t.overtime ? .overtime : .normal), "tarea", Fmt.time(t.date, use24h),
                                 "", "", "", "", t.text]))
            }
        }
        // BOM para que Excel abra bien las tildes.
        return "\u{FEFF}" + rows.joined(separator: "\n")
    }

    private func label(_ k: WorkKind) -> String { k == .overtime ? "horas extra" : "normal" }

    private func mins(_ s: TimeInterval) -> String { String(format: "%.1f", s / 60) }

    private func row(_ fields: [String]) -> String {
        fields.map { f in
            if f.contains(",") || f.contains("\"") || f.contains("\n") {
                return "\"" + f.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            }
            return f
        }.joined(separator: ",")
    }
}
