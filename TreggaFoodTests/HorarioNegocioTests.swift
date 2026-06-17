import Testing
import Foundation
@testable import TreggaFood

/// Calendario determinista (UTC) para que el día/hora no dependan del entorno.
private let cal: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "UTC")!
    return c
}()

private func fecha(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
    cal.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
}

/// ISO 1=Lun … 7=Dom para una fecha (misma fórmula que el cálculo real).
private func iso(_ date: Date) -> Int { (cal.component(.weekday, from: date) + 5) % 7 + 1 }

@Test func abiertoAMediaJornada() {
    let ahora = fecha(2026, 6, 15, 12, 0)
    let h = [HorarioNegocio(diaSemana: iso(ahora), horaApertura: "09:00", horaCierre: "18:00", isActive: true)]
    let e = EstadoApertura.calcular(h, ahora: ahora, calendar: cal)
    #expect(e?.abierto == true)
    #expect(e?.detalle == "Cierra 6:00 PM")
}

@Test func cerradoAntesDeAbrirMismoDia() {
    let ahora = fecha(2026, 6, 15, 8, 0)
    let h = [HorarioNegocio(diaSemana: iso(ahora), horaApertura: "09:00", horaCierre: "18:00", isActive: true)]
    let e = EstadoApertura.calcular(h, ahora: ahora, calendar: cal)
    #expect(e?.abierto == false)
    #expect(e?.detalle == "Abre hoy 9:00 AM")
}

@Test func cerradoAbreManana() {
    let ahora = fecha(2026, 6, 15, 20, 0)
    let hoy = iso(ahora)
    let manana = hoy == 7 ? 1 : hoy + 1
    let h = [
        HorarioNegocio(diaSemana: hoy, horaApertura: "09:00", horaCierre: "18:00", isActive: true),
        HorarioNegocio(diaSemana: manana, horaApertura: "10:00", horaCierre: "18:00", isActive: true),
    ]
    let e = EstadoApertura.calcular(h, ahora: ahora, calendar: cal)
    #expect(e?.abierto == false)
    #expect(e?.detalle == "Abre mañana 10:00 AM")
}

@Test func sinHorariosDevuelveNil() {
    let ahora = fecha(2026, 6, 15, 12, 0)
    #expect(EstadoApertura.calcular([], ahora: ahora, calendar: cal) == nil)
}

@Test func diaInactivoNoCuenta() {
    let ahora = fecha(2026, 6, 15, 12, 0)
    let h = [HorarioNegocio(diaSemana: iso(ahora), horaApertura: "09:00", horaCierre: "18:00", isActive: false)]
    // Único día está inactivo → como si no hubiera horarios.
    #expect(EstadoApertura.calcular(h, ahora: ahora, calendar: cal) == nil)
}
