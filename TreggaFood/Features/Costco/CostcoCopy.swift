import Foundation

/// Textos de Pedidos Costco. Fuente única para iOS **y Android** (copiar 1:1).
/// `{x}` = valor interpolado. Fechas: `fechaCorta` → "vie 14 nov"; `fechaHora` → "mié 12 nov, 11:59 p.m."
/// (siempre en America/Mexico_City).
enum CostcoCopy {
    // MARK: Tarjeta del Home
    static let homeTitulo = "Compras en Costco"
    static func homeAbierto(viaje: String, cierre: String) -> String {
        "Próximo viaje: \(viaje) · pide antes del \(cierre)"
    }
    static func homeConfirmado(viaje: String) -> String { "Viaje confirmado: \(viaje) · ya no se aceptan pedidos" }
    static let homeSinViaje = "Por ahora no hay viaje programado"
    static let homeSujeto = "Sujeto a juntar pedidos"

    // MARK: Catálogo
    static let catalogoTitulo = "Costco"
    static func catalogoComision(pct: String) -> String { "Precios de Costco + \(pct)% de comisión de compra. El envío va incluido." }
    static let catalogoVacio = "Aún no hay productos en la lista. Puedes pedir lo que necesites con \"Pedir algo que no está en la lista\"."
    static let catalogoPedirLibre = "Pedir algo que no está en la lista"
    static let libreTitulo = "¿Qué necesitas de Costco?"
    static let libreDescripcion = "Producto"
    static let libreDescripcionPlaceholder = "Ej. Pastel de chocolate Kirkland"
    static let librePrecio = "Precio aproximado en Costco"
    static let libreAviso = "El precio final será el del ticket de Costco."
    static let libreAgregar = "Agregar al carrito"
    static let agregar = "Agregar"
    static let verCarrito = "Ver carrito"

    // MARK: Carrito
    static let carritoTitulo = "Carrito Costco"
    static let carritoVacio = "Tu carrito de Costco está vacío."
    static let subtotal = "Subtotal"
    static func comision(pct: String) -> String { "Comisión de compra (\(pct)%)" }
    static let envio = "Envío"
    static let envioIncluido = "Incluido"
    static let totalEstimado = "Total estimado"
    static func faltaMinimo(falta: String, minimo: String) -> String { "Te faltan \(falta) para el mínimo de \(minimo)" }
    static let minimoAlcanzado = "Ya alcanzaste el mínimo"
    static let precioEstimadoTag = "Precio estimado"
    static let continuar = "Continuar"
    static let carritoViajeCambio = "El viaje de tu carrito ya no está disponible, así que lo vaciamos."
    static let carritoProductoQuitado = "Quitamos de tu carrito productos que ya no están en la lista."

    // MARK: Checkout
    static let checkoutTitulo = "Confirmar pedido Costco"
    static let entregarEn = "Entregar en"
    static let elegirDireccion = "Elegir dirección"
    static func anticipoAhora(pct: String) -> String { "Anticipo a pagar ahora (\(pct)%)" }
    static let restoAlRecibir = "Resto al recibir"
    /// `cancelarHasta == nil`: el límite de cancelación de este viaje ya pasó.
    static func condiciones(cancelarHasta: String?) -> [String] {
        [
            "Tu pedido se confirma cuando verifiquemos tu depósito. El resto lo pagas al recibir.",
            "El envío va incluido.",
            "El viaje está sujeto a juntar pedidos; si se cancela te devolvemos tu anticipo.",
            cancelarHasta.map { "Puedes cancelar hasta el \($0); después no hay cancelaciones." }
                ?? "Este viaje ya no admite cancelaciones.",
            "El día del viaje mantente atento a tu teléfono por si algún producto no está disponible.",
        ]
    }
    static let aceptoCondiciones = "Acepto estas condiciones"
    static let hacerPedido = "Hacer pedido"

    // MARK: Estados del pedido (título · descripción)
    static func estado(_ e: CostcoPedido.Estado) -> (titulo: String, detalle: String) {
        switch e {
        case .esperandoAnticipo:
            return ("Esperando tu anticipo", "Deposita el anticipo y sube tu comprobante para confirmar tu pedido.")
        case .anticipoEnRevision:
            return ("Verificando tu depósito", "Estamos revisando tu comprobante. Te avisaremos en cuanto quede confirmado.")
        case .confirmado:
            return ("Pedido confirmado", "Tu pedido va en el viaje del {viaje}.")
        case .comprado:
            return ("Compra realizada", "Ya compramos tu pedido. Te contactaremos para acordar la entrega.")
        case .entregado:
            return ("Entregado", "¡Gracias por tu compra!")
        case .cancelado:
            return ("Pedido cancelado", "")
        }
    }
    static func motivoCancelacion(_ m: CostcoPedido.CancelMotivo?) -> String {
        switch m {
        case .cliente: return "Cancelaste este pedido."
        case .admin: return "Cancelamos este pedido."
        case .viajeCancelado: return "El viaje se canceló porque no se juntaron suficientes pedidos."
        case .anticipoVencido: return "El pedido se canceló porque no recibimos el anticipo a tiempo."
        case nil: return ""
        }
    }

    // MARK: Detalle
    static let detalleTitulo = "Pedido Costco"
    static let datosTransferencia = "Datos para tu depósito"
    static let clabe = "CLABE"
    static let titular = "Titular"
    static let montoADepositar = "Monto a depositar"
    static let copiar = "Copiar"
    static let copiado = "Copiado"
    static let subirComprobante = "Subir comprobante"
    static let cambiarComprobante = "Subir otro comprobante"
    static let subiendo = "Subiendo…"
    static let enviando = "Enviando…"
    static let comprobanteFoto = "Elegir foto o captura"
    static let comprobantePDF = "Elegir archivo PDF"
    static let comprobanteMuyGrande = "El archivo pesa más de 10 MB. Elige uno más ligero."
    static func viajeDel(_ fecha: String) -> String { "Viaje del \(fecha)" }
    static func comprobanteRechazado(motivo: String) -> String { "Rechazamos tu comprobante: \(motivo). Sube uno nuevo." }
    static let totalReal = "Total según ticket"
    static let anticipoPagado = "Anticipo pagado"
    static let restoAPagar = "Resto a pagar al recibir"
    static let pagadoAlRecibir = "Pagado al recibir"
    static func reembolsoPendiente(monto: String) -> String { "Te devolveremos \(monto) a tu cuenta." }
    static func reembolsoHecho(monto: String) -> String { "Te devolvimos \(monto)." }
    static func entregaAcordada(fecha: String) -> String { "Entrega acordada: \(fecha)" }
    static let productos = "Productos"
    static func itemEstado(_ e: CostcoItem.Estado) -> String? {
        switch e {
        case .pendiente: return nil
        case .comprado: return "Comprado"
        case .noEncontrado: return "No lo encontramos"
        case .sustituido: return "Cambiado"
        case .quitado: return "Quitado"
        }
    }
    /// Sin punto final: `fechaHora` ya termina en "p.m."/"a.m.".
    static func puedesCancelarHasta(_ fecha: String) -> String { "Puedes cancelar hasta el \(fecha)" }
    static let yaNoCancelable = "Ya no es posible cancelar: tu pedido está en la lista de compra."
    static let cancelarPedido = "Cancelar pedido"
    static let cancelarConfirmTitulo = "¿Cancelar tu pedido Costco?"
    static let cancelarConfirmSinAnticipo = "Tu pedido se cancelará."
    static let cancelarConfirmConAnticipo = "Tu pedido se cancelará y te devolveremos tu anticipo."
    static let cancelarConfirmSi = "Sí, cancelar"
    static let cancelarConfirmNo = "No"

    // MARK: Ruta de entrega (§9)
    static func enCamino(parada: Int, de total: Int) -> String { "En camino · parada \(parada) de \(total)" }
    static let vamosParaTuCasa = "¡Vamos para tu casa!"
    static func paradasAntes(_ n: Int) -> String { n == 1 ? "Antes de ti hay 1 entrega." : "Antes de ti hay \(n) entregas." }
    static func llegadaAprox(_ minutos: Int) -> String { "Llegamos en aprox. \(minutos) min" }
    static let ubicacionPendiente = "En cuanto salgamos verás aquí nuestra ubicación."
    static func entregaFallida(nota: String) -> String { "No pudimos entregarte: \(nota)" }
    static func cobrado(monto: String, metodo: String?) -> String {
        switch metodo {
        case "efectivo": return "Pagaste \(monto) en efectivo al recibir."
        case "transferencia": return "Pagaste \(monto) por transferencia al recibir."
        default: return "Pagaste \(monto) al recibir."
        }
    }

    // MARK: Producto no encontrado
    static func noEncontradoTitulo(_ producto: String) -> String { "No encontramos \(producto)" }
    static let noEncontradoPregunta = "¿Qué prefieres?"
    static let elegirOtro = "Elegir otro producto"
    static let quitarYReembolsar = "Quitarlo y reembolsar"
    static let noEncontradoAviso = "Si no respondes antes de que terminemos la compra, lo quitaremos y te reembolsaremos."
    static let noEncontradoBanner = "Hay productos que no encontramos. Elige qué hacer."

    // MARK: Mis pedidos
    static let seccionCostco = "Costco"
    static func filaCostco(productos: Int) -> String { productos == 1 ? "1 producto" : "\(productos) productos" }

    // MARK: Errores genéricos
    static let errorRed = "No pudimos conectar. Revisa tu conexión e intenta de nuevo."
    static let errorCarga = "No pudimos cargar la información de Costco."
    static let reintentar = "Reintentar"
}
