import Foundation
import Testing
@testable import TreggaFood

@Suite("Costco: contrato con el servidor")
struct CostcoContratoTests {

    static let pedidoJSON = """
    {"id":"6f1c1e7a-0000-4000-8000-000000000001","viaje_id":"6f1c1e7a-0000-4000-8000-000000000002",
     "viaje_estado":"abierto","fecha_viaje":"2026-11-14","fecha_cierre":"2026-11-13T05:59:59+00:00",
     "estado":"esperando_anticipo",
     "direccion":{"label":"Casa","address":"Av. Morelos 12","lat":19.8,"lng":-100.8,"referencias":null,
                  "instrucciones":null,"calle":null,"colonia":null,"municipio":null,"estado":null,"codigo_postal":null},
     "comision_pct":10,"anticipo_pct":50,"subtotal_estimado":900.00,"comision":90.00,"total_estimado":990.00,
     "anticipo":495.00,"comprobante_path":null,"comprobante_subido_at":null,"anticipo_rechazo_motivo":null,
     "anticipo_verificado_at":null,"total_real":null,"resto":null,"reembolso_monto":null,"reembolso_pendiente":false,
     "reembolso_at":null,"entrega_acordada_at":null,"comprado_at":null,"entregado_at":null,"cancel_motivo":null,
     "cancel_nota":null,"cancelado_at":null,"created_at":"2026-11-06T18:20:47.464221+00:00",
     "limite_cancelacion":"2026-11-13T05:59:59+00:00","puede_cancelar":true,"anticipo_vencido":false,
     "items":[{"id":"6f1c1e7a-0000-4000-8000-000000000003","producto_id":"6f1c1e7a-0000-4000-8000-000000000004",
               "descripcion":"Papel higiénico","presentacion":"30 rollos","es_libre":false,"cantidad":2,
               "precio_estimado":300.00,"importe_estimado":600.00,"precio_real":null,"estado":"pendiente","sustituto_de":null},
              {"id":"6f1c1e7a-0000-4000-8000-000000000005","producto_id":null,"descripcion":"Pastel de chocolate",
               "presentacion":null,"es_libre":true,"cantidad":1,"precio_estimado":300.00,"importe_estimado":300.00,
               "precio_real":null,"estado":"no_encontrado","sustituto_de":null}]}
    """

    @Test func decodificaPedidoConMicrosegundosYOffsetUTC() throws {
        let p = try CostcoJSON.decoder.decode(CostcoPedido.self, from: Data(Self.pedidoJSON.utf8))
        #expect(p.estado == .esperandoAnticipo)
        #expect(p.anticipo == 495)
        #expect(p.items.count == 2)
        #expect(p.pendientesDeDecision.map(\.descripcion) == ["Pastel de chocolate"])
        #expect(p.puedeCancelar)
        let esperado = ISO8601DateFormatter().date(from: "2026-11-06T18:20:47Z")!
        #expect(abs(p.createdAt.timeIntervalSince(esperado) - 0.464) < 0.01)
    }

    @Test func decodificaEstadoSinViajeYSinSesion() throws {
        let json = """
        {"viaje":null,"config":{"comision_pct":10,"anticipo_pct":50,"minimo":800,"dias_limite_cancelacion":2,"clabe":null,"titular":null}}
        """
        let e = try CostcoJSON.decoder.decode(CostcoEstado.self, from: Data(json.utf8))
        #expect(e.viaje == nil)
        #expect(e.puedePedir == false)
        #expect(e.config.minimo == 800)
    }

    @Test func mapeaSQLStateAErrores() {
        #expect(CostcoError.from(code: "P0003", message: "Bajo el mínimo") == .bajoMinimo("Bajo el mínimo"))
        #expect(CostcoError.from(code: "P0002", message: "x") == .noEncontrado("x"))
        #expect(CostcoError.from(code: "28000", message: "x") == .sinSesion("x"))
        #expect(CostcoError.from(code: nil, message: nil) == .red)
        #expect(CostcoError.red.mensaje == CostcoCopy.errorRed)
    }
}

@MainActor
@Suite("Costco: carrito persistente")
struct CostcoCartStoreTests {
    let viaje = UUID()
    let usuarioA = UUID()
    let usuarioB = UUID()

    func defaults() -> UserDefaults {
        let name = "costco-tests-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    func config() -> CostcoConfig {
        CostcoConfig(comisionPct: 10, anticipoPct: 50, minimo: 800, diasLimiteCancelacion: 2, clabe: nil, titular: nil)
    }

    func producto(_ id: UUID, precio: Decimal) -> CostcoProducto {
        CostcoProducto(id: id, nombre: "P", presentacion: nil, fotoURL: nil, precio: precio, precioConComision: precio * 1.1)
    }

    func estado(viajeId: UUID?, acepta: Bool = true) -> CostcoEstado {
        CostcoEstado(
            viaje: viajeId.map { CostcoViaje(id: $0, estado: "abierto", fechaViaje: "2026-11-14",
                                             fechaCierre: Date(), nota: nil, aceptaPedidos: acepta) },
            config: config()
        )
    }

    @Test func persistePorUsuarioYNoSeHereda() {
        let d = defaults()
        let p = UUID()
        let a = CostcoCartStore(defaults: d)
        a.activar(userId: usuarioA)
        a.setCantidad(3, productoId: p, viajeId: viaje)

        let reabierto = CostcoCartStore(defaults: d)
        reabierto.activar(userId: usuarioA)
        #expect(reabierto.cantidad(de: p) == 3)

        let otro = CostcoCartStore(defaults: d)
        otro.activar(userId: usuarioB)
        #expect(otro.isEmpty)
    }

    @Test func cerrarSesionBorraLoGuardado() {
        let d = defaults()
        let s = CostcoCartStore(defaults: d)
        s.activar(userId: usuarioA)
        s.agregarLibre(descripcion: "Pastel", cantidad: 1, precioEstimado: 300, viajeId: viaje)
        s.cerrarSesion()
        #expect(s.isEmpty)

        let reabierto = CostcoCartStore(defaults: d)
        reabierto.activar(userId: usuarioA)
        #expect(reabierto.isEmpty)
    }

    @Test func seVaciaSiElViajeCambiaOYaNoAcepta() {
        let s = CostcoCartStore(defaults: defaults())
        s.activar(userId: usuarioA)
        s.setCantidad(1, productoId: UUID(), viajeId: viaje)
        #expect(s.sincronizar(estado: estado(viajeId: viaje), catalogo: nil) == nil)
        #expect(s.sincronizar(estado: estado(viajeId: viaje, acepta: false), catalogo: nil) == .viajeCambio)
        #expect(s.isEmpty)

        s.setCantidad(1, productoId: UUID(), viajeId: viaje)
        #expect(s.sincronizar(estado: estado(viajeId: UUID()), catalogo: nil) == .viajeCambio)
        #expect(s.isEmpty)
    }

    @Test func quitaProductosInactivosYConservaLibres() {
        let s = CostcoCartStore(defaults: defaults())
        s.activar(userId: usuarioA)
        let activo = UUID(), inactivo = UUID()
        s.setCantidad(1, productoId: activo, viajeId: viaje)
        s.setCantidad(1, productoId: inactivo, viajeId: viaje)
        s.agregarLibre(descripcion: "Pastel", cantidad: 1, precioEstimado: 300, viajeId: viaje)
        let aviso = s.sincronizar(estado: estado(viajeId: viaje), catalogo: [producto(activo, precio: 100)])
        #expect(aviso == .productosQuitados)
        #expect(s.cantidad(de: inactivo) == 0)
        #expect(s.cantidad(de: activo) == 1)
        #expect(s.snapshot.libres.count == 1)
    }

    @Test func totalesYMinimo() {
        let s = CostcoCartStore(defaults: defaults())
        s.activar(userId: usuarioA)
        let p = UUID()
        s.setCantidad(2, productoId: p, viajeId: viaje)                       // 2 × 250.55 = 501.10
        s.agregarLibre(descripcion: "Pastel", cantidad: 1, precioEstimado: 199.99, viajeId: viaje)
        let t = s.totales(catalogo: [producto(p, precio: Decimal(string: "250.55")!)], config: config())
        #expect(t.subtotal == Decimal(string: "701.09")!)
        #expect(t.comision == Decimal(string: "70.11")!)
        #expect(t.total == Decimal(string: "771.20")!)
        #expect(t.anticipo == Decimal(string: "385.60")!)
        #expect(t.faltaParaMinimo == Decimal(string: "98.91")!)
    }

    @Test func cantidadesAcotadasYCeroQuita() {
        let s = CostcoCartStore(defaults: defaults())
        s.activar(userId: usuarioA)
        let p = UUID()
        s.setCantidad(500, productoId: p, viajeId: viaje)
        #expect(s.cantidad(de: p) == 99)
        s.setCantidad(0, productoId: p, viajeId: viaje)
        #expect(s.isEmpty)
        s.agregarLibre(descripcion: "   ", cantidad: 1, precioEstimado: 10, viajeId: viaje)
        #expect(s.isEmpty)
    }
}

@Suite("Costco: formato de fechas (CDMX)")
struct CostcoFormatTests {
    @Test func fechaDelViajeSinHora() {
        #expect(CostcoFormat.fechaCorta(dia: "2026-11-14") == "sáb 14 nov")
    }

    @Test func cierreEnUTCSeMuestraEnCDMX() {
        // 05:59:59Z del 13 = 11:59:59 p.m. del 12 en CDMX (UTC−6, sin horario de verano).
        let d = CostcoJSON.parse("2026-11-13T05:59:59+00:00")!
        #expect(CostcoFormat.fechaHora(d) == "jue 12 nov, 11:59 p.m.")
    }
}

@Suite("Costco: ruta de entrega (§9)")
struct CostcoRutaTests {
    static func pedido(_ extra: String) -> String {
        CostcoContratoTests.pedidoJSON
            .replacingOccurrences(of: "\"estado\":\"esperando_anticipo\"", with: "\"estado\":\"comprado\"")
            .replacingOccurrences(of: "\"items\":[", with: extra + ",\"items\":[")
    }

    @Test func pedidoEnRutaConUbicacion() throws {
        let json = Self.pedido("""
        "ruta_orden":3,"ruta_total":5,"en_ruta_at":"2026-11-14T22:00:00+00:00","entrega_fallida_at":null,
        "entrega_fallida_nota":null,"resto_cobrado":null,"resto_metodo":null,
        "ruta":{"lat":19.8,"lng":-100.8,"ubicacion_at":"2026-11-14T22:05:00.123456+00:00","paradas_antes":0}
        """)
        let p = try CostcoJSON.decoder.decode(CostcoPedido.self, from: Data(json.utf8))
        #expect(p.enCamino)
        #expect(p.rutaOrden == 3 && p.rutaTotal == 5)
        #expect(p.ruta?.paradasAntes == 0)
        #expect(p.direccion?.lat == 19.8)
    }

    @Test func rutaSinUbicacionTodaviaYEntregaFallida() throws {
        let json = Self.pedido("""
        "ruta_orden":1,"ruta_total":2,"en_ruta_at":"2026-11-14T22:00:00+00:00",
        "entrega_fallida_at":"2026-11-14T22:30:00+00:00","entrega_fallida_nota":"No había nadie",
        "ruta":null
        """)
        let p = try CostcoJSON.decoder.decode(CostcoPedido.self, from: Data(json.utf8))
        #expect(p.enCamino == false)
        #expect(p.ruta == nil)
        #expect(p.entregaFallidaNota == "No había nadie")
    }

    @Test func pedidoViejoSinCamposDeRutaSigueDecodificando() throws {
        let p = try CostcoJSON.decoder.decode(CostcoPedido.self, from: Data(CostcoContratoTests.pedidoJSON.utf8))
        #expect(p.rutaOrden == nil && p.ruta == nil && p.enCamino == false)
    }
}

@Suite("Costco: renglones activos y copy de estados")
struct CostcoLineasActivasTests {
    @Test func cuentaSoloLosRenglonesQueSiguenEnElPedido() throws {
        let json = CostcoContratoTests.pedidoJSON
            .replacingOccurrences(of: "\"estado\":\"no_encontrado\"", with: "\"estado\":\"quitado\"")
        let p = try CostcoJSON.decoder.decode(CostcoPedido.self, from: Data(json.utf8))
        #expect(p.items.count == 2)
        #expect(p.lineasActivas == 1)
    }

    @Test func noEncontradoSigueContando() throws {
        let p = try CostcoJSON.decoder.decode(CostcoPedido.self, from: Data(CostcoContratoTests.pedidoJSON.utf8))
        #expect(p.lineasActivas == 2)
    }

    @Test func quitadoNoPrometeReembolsoAparte() {
        #expect(CostcoCopy.itemEstado(.quitado) == "Quitado")
    }
}

@Suite("Costco: condiciones del checkout")
struct CostcoCondicionesTests {
    @Test func conLimiteVigenteMuestraLaFecha() {
        #expect(CostcoCopy.condiciones(cancelarHasta: "vie 6 nov").contains("Puedes cancelar hasta el vie 6 nov; después no hay cancelaciones."))
    }

    @Test func conLimiteVencidoNoPrometeCancelar() {
        let c = CostcoCopy.condiciones(cancelarHasta: nil)
        #expect(c.contains("Este viaje ya no admite cancelaciones."))
        #expect(!c.contains { $0.hasPrefix("Puedes cancelar") })
    }
}
