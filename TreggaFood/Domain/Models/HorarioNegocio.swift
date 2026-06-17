import Foundation

/// Horario de atención de un día (tabla `horarios_negocio`).
/// `diaSemana`: ISO 8601 → 1=Lunes … 7=Domingo. Horas en `"HH:mm"`.
public struct HorarioNegocio: Sendable, Equatable {
    public let diaSemana: Int
    public let horaApertura: String
    public let horaCierre: String
    public let isActive: Bool

    public init(diaSemana: Int, horaApertura: String, horaCierre: String, isActive: Bool) {
        self.diaSemana = diaSemana
        self.horaApertura = horaApertura
        self.horaCierre = horaCierre
        self.isActive = isActive
    }
}

/// Estado abierto/cerrado de un negocio derivado de sus horarios y la hora actual.
public struct EstadoApertura: Equatable, Sendable {
    public let abierto: Bool
    /// Detalle secundario: "Cierra 10:00 PM", "Abre hoy 11:00 AM", "Abre mañana 9:00 AM".
    public let detalle: String

    /// Calcula el estado para `ahora`. Devuelve `nil` si el negocio no tiene
    /// horarios configurados (en ese caso no se muestra badge).
    public static func calcular(
        _ horarios: [HorarioNegocio],
        ahora: Date = Date(),
        calendar: Calendar = .current
    ) -> EstadoApertura? {
        let activos = horarios.filter { $0.isActive }
        guard !activos.isEmpty else { return nil }
        let porDia = Dictionary(grouping: activos, by: { $0.diaSemana })

        let comps = calendar.dateComponents([.weekday, .hour, .minute], from: ahora)
        let isoHoy = isoDay(from: comps.weekday ?? 1)
        let ahoraMin = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)

        // 1) ¿Abierto por un horario de hoy?
        for h in porDia[isoHoy] ?? [] {
            let a = minutos(h.horaApertura)
            let c0 = minutos(h.horaCierre)
            let c = c0 <= a ? c0 + 24 * 60 : c0   // cierre tras medianoche
            if ahoraMin >= a && ahoraMin < c {
                return EstadoApertura(abierto: true, detalle: "Cierra \(doce(h.horaCierre))")
            }
        }
        // 2) ¿Abierto por un horario de ayer que cruzó la medianoche?
        let isoAyer = isoHoy == 1 ? 7 : isoHoy - 1
        for h in porDia[isoAyer] ?? [] where minutos(h.horaCierre) <= minutos(h.horaApertura) {
            if ahoraMin < minutos(h.horaCierre) {
                return EstadoApertura(abierto: true, detalle: "Cierra \(doce(h.horaCierre))")
            }
        }
        // 3) Cerrado → próxima apertura hoy más tarde…
        if let prox = (porDia[isoHoy] ?? []).map({ minutos($0.horaApertura) }).filter({ $0 > ahoraMin }).min() {
            return EstadoApertura(abierto: false, detalle: "Abre hoy \(doce(hhmm(prox)))")
        }
        // 4) …o el siguiente día con horario.
        for offset in 1...7 {
            let dia = ((isoHoy - 1 + offset) % 7) + 1
            if let apertura = (porDia[dia] ?? []).map({ minutos($0.horaApertura) }).min() {
                let etiqueta = offset == 1 ? "mañana" : nombreDia(dia)
                return EstadoApertura(abierto: false, detalle: "Abre \(etiqueta) \(doce(hhmm(apertura)))")
            }
        }
        return EstadoApertura(abierto: false, detalle: "Cerrado")
    }

    // MARK: - Helpers

    /// Foundation: 1=Domingo … 7=Sábado → ISO 1=Lunes … 7=Domingo.
    private static func isoDay(from weekday: Int) -> Int { (weekday + 5) % 7 + 1 }

    private static func minutos(_ hhmm: String) -> Int {
        let p = hhmm.split(separator: ":")
        guard p.count >= 2, let h = Int(p[0]), let m = Int(p[1]) else { return 0 }
        return h * 60 + m
    }

    private static func hhmm(_ min: Int) -> String {
        String(format: "%02d:%02d", (min / 60) % 24, min % 60)
    }

    private static let nombres = ["lun", "mar", "mié", "jue", "vie", "sáb", "dom"]
    private static func nombreDia(_ iso: Int) -> String { nombres[(iso - 1) % 7] }

    /// "22:00" → "10:00 PM".
    private static func doce(_ hhmm: String) -> String {
        let total = minutos(hhmm)
        let h = total / 60, m = total % 60
        let ampm = h < 12 ? "AM" : "PM"
        var h12 = h % 12
        if h12 == 0 { h12 = 12 }
        return String(format: "%d:%02d %@", h12, m, ampm)
    }
}
