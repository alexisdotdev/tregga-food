import Foundation

// Documentos legales de Tregga Food (cliente). BORRADORES sujetos a revisión
// por abogado antes de publicación. Redactados para el modelo conector: Tregga
// es ÚNICAMENTE una plataforma tecnológica que conecta al cliente con el negocio
// mediante un repartidor independiente. Tregga no produce ni vende los productos,
// no prepara los alimentos y no realiza la entrega.
enum LegalDocuments {

    // MARK: - Términos de servicio (cliente)

    static let terminosServicio = LegalDocument(
        id: "terminos-servicio",
        title: "Términos de servicio",
        version: "1.0",
        effectiveDate: "junio 2026",
        summary: "Condiciones de uso de la plataforma Tregga por parte del cliente: qué es Tregga, cómo funcionan los pedidos, pagos, entregas, cancelaciones y responsabilidades.",
        blocks: [
            .callout("Estos Términos de Servicio (los \"Términos\") son un acuerdo legal entre tú, como cliente, y Tregga Tech S.A. de C.V. Léelos con calma antes de usar la aplicación. Al crear tu cuenta y hacer pedidos a través de Tregga, aceptas todo lo que aquí se establece. Este documento es un borrador sujeto a revisión legal."),
            .keyValues([
                ("Razón social", "Tregga Tech S.A. de C.V."),
                ("Marca", "Tregga"),
                ("Soporte", "Dentro de la aplicación"),
                ("Versión", "1.0"),
                ("Vigencia", "junio 2026"),
            ]),
            .heading("1. Aceptación de los Términos"),
            .paragraph("Al crear una cuenta, acceder o usar la aplicación móvil de Tregga (la \"App\" o la \"Plataforma\"), confirmas que has leído, entendido y aceptado estos Términos, así como el Aviso de Privacidad y demás políticas que Tregga ponga a tu disposición dentro de la App. Si no estás de acuerdo con alguno de estos puntos, no podrás usar la Plataforma."),
            .paragraph("Estos Términos aplican a las personas que usan la App en su carácter de **clientes** para solicitar productos a negocios. Tregga puede tener documentos distintos para negocios y repartidores."),
            .heading("2. Definiciones"),
            .bullets([
                "**Tregga / la Plataforma**: la tecnología, App y servicios provistos por Tregga Tech S.A. de C.V. que conectan a negocios, clientes y repartidores.",
                "**Cliente / tú**: la persona que usa la App para solicitar productos a un Negocio y recibir su entrega.",
                "**Negocio**: el restaurante, tienda o establecimiento que ofrece y vende productos a través de la Plataforma.",
                "**Repartidor**: la persona física independiente que, por su cuenta, recolecta el pedido en el Negocio y lo entrega al Cliente.",
                "**Pedido**: cada solicitud de productos que haces a un Negocio a través de la Plataforma.",
                "**Cuenta**: tu registro personal dentro de la App.",
            ]),
            .heading("3. Qué es Tregga: una plataforma que conecta, no vende ni entrega"),
            .paragraph("Tregga es **únicamente una plataforma tecnológica** que conecta a tres partes independientes entre sí: el **negocio** que vende los productos, el **repartidor** que los entrega y tú, el **cliente**, que los solicita. Tregga facilita el contacto y la coordinación entre ustedes, pero **no participa en la elaboración, venta ni entrega de los productos**."),
            .paragraph("Esto significa, de forma expresa, que:"),
            .bullets([
                "**El Negocio es el vendedor.** El Negocio es el único responsable de preparar, elaborar y vender los productos, de su calidad, higiene, ingredientes, información, peso, precio y disponibilidad. Tregga no produce, prepara ni vende los productos y no los tiene en inventario.",
                "**El Repartidor es independiente.** El Repartidor presta el servicio de entrega por su cuenta y riesgo. No es empleado de Tregga ni del Negocio.",
                "**Tregga es un facilitador tecnológico.** Tregga pone la herramienta que permite que se conecten, hagas tu pedido y se coordine la entrega; no es parte de la compraventa de los productos ni del contrato de entrega.",
            ]),
            .callout("Cuando haces un pedido, celebras una compraventa con el Negocio y recibes el servicio de entrega de un Repartidor independiente. Tregga no es el vendedor de los productos ni quien realiza la entrega: solo conecta a las partes."),
            .heading("4. Tu cuenta"),
            .paragraph("Para usar la Plataforma debes crear una cuenta con datos veraces, completos y actualizados, y ser mayor de edad con capacidad legal para contratar. Eres el único responsable de la confidencialidad de tu cuenta y de toda actividad realizada bajo ella."),
            .bullets([
                "Proporciona información real (nombre, teléfono, correo y dirección de entrega) y mantenla al día.",
                "Tu cuenta es personal e intransferible; no la compartas ni la cedas.",
                "Avísanos de inmediato si detectas un uso no autorizado de tu cuenta.",
            ]),
            .heading("5. Cómo funciona un pedido"),
            .paragraph("Cuando eliges productos de un Negocio y confirmas tu pedido en la App, envías una solicitud de compra a ese Negocio. El Negocio puede aceptarla o rechazarla según su disponibilidad. Una vez aceptado, un Repartidor podrá tomar el pedido para recolectarlo y entregártelo en la dirección que indicaste."),
            .bullets([
                "Los productos, precios, fotos, descripciones y disponibilidad mostrados en la App son proporcionados y administrados por cada **Negocio**.",
                "El Negocio puede tener un tiempo de preparación; el tiempo total de entrega también depende del Repartidor, la distancia y el tránsito.",
                "Cualquier estimación de tiempo o costo que veas en la App es **referencial** y puede variar.",
            ]),
            .heading("6. Precios y pagos"),
            .paragraph("El precio de los productos lo fija cada **Negocio**. El pedido puede incluir, además, un costo de entrega y otros conceptos que se te muestran antes de confirmar. Al confirmar, aceptas pagar el total indicado conforme al método de pago disponible en la App (por ejemplo, efectivo contra entrega o el método que la App habilite)."),
            .bullets([
                "Tregga **no es la vendedora** de los productos; el cobro corresponde al Negocio y, en su caso, al Repartidor por la entrega.",
                "Revisa el desglose de tu pedido antes de confirmarlo. Eres responsable de proporcionar una dirección correcta y de estar disponible para recibir.",
                "Si tu método es efectivo, procura contar con el monto necesario para facilitar el cobro al momento de la entrega.",
            ]),
            .heading("7. Entrega y recepción del pedido"),
            .paragraph("La entrega la realiza un Repartidor independiente en la dirección que registraste. Para que llegue bien y a tiempo:"),
            .bullets([
                "Mantén tu teléfono disponible: el Repartidor puede contactarte para coordinar la entrega.",
                "Proporciona referencias claras de tu domicilio y, si aplica, indicaciones de acceso.",
                "Revisa tu pedido al recibirlo. Si algo no corresponde, repórtalo lo antes posible desde la App.",
            ]),
            .paragraph("Si no es posible completar la entrega por causas atribuibles a ti (dirección incorrecta, ausencia o falta de respuesta), el pedido podría darse por entregado o cancelarse sin derecho a reembolso, según el caso."),
            .heading("8. Cancelaciones y problemas con el pedido"),
            .paragraph("Puedes intentar cancelar un pedido desde la App antes de que el Negocio comience a prepararlo. Una vez que el Negocio inició la preparación o el Repartidor recolectó el pedido, la cancelación puede no ser posible o no dar lugar a reembolso, ya que los productos ya fueron elaborados."),
            .paragraph("Si tienes un problema con tu pedido (faltantes, producto en mal estado, error del Negocio o de la entrega), repórtalo desde **Soporte** o desde el detalle del pedido. Dado que el Negocio vende los productos y el Repartidor los entrega, la solución (reposición, ajuste o reembolso, cuando proceda) depende de la responsabilidad de cada parte. Tregga puede ayudarte a canalizar y dar seguimiento a tu reporte como facilitador."),
            .heading("9. Conducta del cliente"),
            .paragraph("Al usar la Plataforma te obligas a actuar con honestidad y respeto. Queda prohibido, de manera enunciativa y no limitativa:"),
            .bullets([
                "Proporcionar información falsa, suplantar a otra persona o usar la cuenta de alguien más.",
                "Hacer pedidos falsos, fraudulentos o sin intención de recibirlos o pagarlos.",
                "Maltratar, acosar, discriminar o poner en riesgo a Repartidores, personal de Negocios u otras personas.",
                "Manipular las calificaciones, promociones o cualquier mecanismo de la Plataforma.",
                "Usar la App para fines ilícitos o contrarios a la ley o a las buenas costumbres.",
            ]),
            .heading("10. Calificaciones y reseñas"),
            .paragraph("La App puede permitirte calificar al Negocio y al Repartidor. Tus calificaciones deben ser honestas y respetuosas. Tregga puede moderar o retirar contenido que sea ofensivo, falso o que infrinja derechos de terceros."),
            .heading("11. Propiedad intelectual"),
            .paragraph("La App, la marca \"Tregga\", logotipos, diseños, código y demás elementos de la Plataforma son propiedad de Tregga Tech S.A. de C.V. o de sus licenciantes. Estos Términos solo te otorgan una licencia limitada, personal y revocable para usar la App como cliente; no puedes copiar, modificar, distribuir ni realizar ingeniería inversa de la App, salvo lo permitido por la ley."),
            .heading("12. Limitación de responsabilidad"),
            .paragraph("Dado que Tregga es **únicamente un facilitador tecnológico**, no se hace responsable de la conducta, actos u omisiones del Negocio, del Repartidor ni de terceros. En particular, y en la medida que permita la ley, Tregga **no es responsable**:"),
            .bullets([
                "De la calidad, higiene, estado, ingredientes, información o idoneidad de los productos, que son responsabilidad exclusiva del **Negocio**.",
                "De la conducta del Repartidor durante la recolección o entrega, ni de retrasos, daños o pérdidas del pedido en tránsito.",
                "De disputas entre tú, el Negocio y/o el Repartidor, que deberán resolverse entre las partes involucradas.",
                "De interrupciones, fallas o indisponibilidad temporal de la App o de servicios de terceros (mapas, pagos, notificaciones, conectividad).",
            ]),
            .paragraph("La App se provee \"tal cual\" y \"según disponibilidad\". En cualquier caso, y salvo dolo o lo que la ley no permita excluir, la responsabilidad total de Tregga frente a ti se limitará, en su caso, al monto que hayas pagado a través de la Plataforma por el pedido que dé origen a la reclamación."),
            .heading("13. Suspensión y terminación"),
            .paragraph("Puedes dejar de usar la Plataforma y solicitar la eliminación de tu cuenta en cualquier momento desde la App (función \"Eliminar cuenta\")."),
            .paragraph("Tregga podrá suspender o terminar tu acceso en casos como información falsa, fraude, pedidos abusivos, conductas que pongan en riesgo a otras personas, incumplimiento de estos Términos o requerimiento de autoridad competente."),
            .heading("14. Modificaciones a los Términos"),
            .paragraph("Tregga puede actualizar estos Términos para reflejar cambios legales, operativos o del servicio. Cuando haya cambios relevantes, te lo notificaremos dentro de la App y se indicará la nueva fecha de vigencia. El uso de la Plataforma después de la entrada en vigor de los cambios implica tu aceptación de los Términos actualizados."),
            .heading("15. Ley aplicable y jurisdicción"),
            .paragraph("Estos Términos se rigen por las leyes de los Estados Unidos Mexicanos. Para su interpretación y cumplimiento, las partes se someten a la jurisdicción de los **tribunales competentes del Estado de Michoacán**, renunciando a cualquier otro fuero que pudiera corresponderles por su domicilio presente o futuro."),
            .heading("16. Contacto"),
            .keyValues([
                ("Soporte", "Sección de ayuda dentro de la App"),
                ("Privacidad", "privacidad@tregga.app"),
                ("Derechos ARCO", "arco@tregga.app"),
                ("Responsable", "Tregga Tech S.A. de C.V."),
            ]),
            .paragraph("Este documento es un borrador (versión 1.0, vigencia junio 2026) sujeto a revisión por parte de un abogado antes de su publicación definitiva."),
        ]
    )

    // MARK: - Política de privacidad (cliente)

    static let politicaPrivacidad = LegalDocument(
        id: "politica-privacidad",
        title: "Política de privacidad",
        version: "1.0",
        effectiveDate: "junio 2026",
        summary: "Cómo Tregga Tech S.A. de C.V. recaba, usa, protege y comparte tus datos personales como cliente, conforme a la LFPDPPP.",
        blocks: [
            .callout("Este documento es un BORRADOR sujeto a revisión legal. Aquí te explicamos qué datos recabamos como cliente, para qué los usamos y cómo puedes ejercer tus derechos."),
            .heading("1. Identidad del responsable"),
            .paragraph("**Tregga Tech S.A. de C.V.** (en adelante, \"**Tregga**\", \"nosotros\" o \"el responsable\") es responsable del tratamiento de tus datos personales en términos de la **Ley Federal de Protección de Datos Personales en Posesión de los Particulares (LFPDPPP)**, su Reglamento y los Lineamientos del Aviso de Privacidad."),
            .keyValues([
                ("Razón social", "Tregga Tech S.A. de C.V."),
                ("Marca", "Tregga"),
                ("Contacto de privacidad", "privacidad@tregga.app"),
                ("Contacto para derechos ARCO", "arco@tregga.app"),
            ]),
            .callout("Tregga es únicamente una plataforma tecnológica que conecta al cliente con el negocio mediante un repartidor independiente. Tregga no vende los productos ni realiza la entrega. Este aviso describe el tratamiento de tus datos para que puedas usar dicha plataforma y recibir tus pedidos."),
            .heading("2. Datos personales que recabamos"),
            .paragraph("Para crear tu cuenta, procesar tus pedidos y coordinar las entregas, recabamos las siguientes categorías de datos que tú nos proporcionas, que generas al usar la app o que recabamos de forma automática:"),
            .paragraph("**Datos de identificación y contacto:** nombre completo, número de teléfono, correo electrónico y fotografía de perfil (opcional)."),
            .paragraph("**Datos de entrega:** tus direcciones de entrega, referencias del domicilio y, durante un pedido activo, datos de ubicación para coordinar y dar seguimiento a la entrega."),
            .paragraph("**Datos del pedido:** productos solicitados, Negocio elegido, historial de pedidos, importes, método de pago seleccionado, mensajes con el Repartidor o el Negocio y calificaciones que emitas."),
            .paragraph("**Datos de uso y técnicos:** token de notificaciones push, información del dispositivo y datos de uso o reportes de errores (analítica anónima) cuando lo autorizas."),
            .callout("La ubicación puede considerarse un dato de tratamiento especial. Solo la usamos para mostrar Negocios cercanos y coordinar la entrega de un pedido activo. No recabamos datos de salud, origen étnico, creencias religiosas ni preferencias sexuales."),
            .heading("3. Finalidades del tratamiento"),
            .paragraph("**Finalidades necesarias** (indispensables para el funcionamiento de la plataforma):"),
            .bullets([
                "Crear y administrar tu cuenta de cliente.",
                "Mostrarte Negocios y productos disponibles, y procesar tus pedidos.",
                "Conectarte con el Negocio y el Repartidor para preparar, coordinar y entregar tu pedido.",
                "Mostrar la ubicación de la entrega durante un pedido activo para que puedas seguirla.",
                "Permitir la comunicación con el Repartidor y el Negocio durante el pedido.",
                "Registrar tu historial de pedidos, importes y calificaciones.",
                "Enviarte notificaciones operativas y del sistema sobre tus pedidos.",
                "Cumplir obligaciones legales y atender requerimientos de autoridades competentes.",
                "Garantizar la seguridad de la plataforma y prevenir fraudes o usos indebidos.",
            ]),
            .paragraph("**Finalidades voluntarias** (no son indispensables; puedes oponerte sin afectar tu uso de la plataforma):"),
            .bullets([
                "Enviarte promociones, beneficios y comunicaciones comerciales sobre Tregga.",
                "Realizar analítica de uso y reportes de errores de forma anónima para mejorar la app.",
            ]),
            .paragraph("Si no deseas que tus datos se traten para las finalidades voluntarias, puedes ajustarlo desde los controles de la app o escribir a privacidad@tregga.app. Tu negativa no será motivo para negarte los servicios necesarios de la plataforma."),
            .heading("4. Ubicación"),
            .paragraph("La ubicación nos ayuda a mostrarte Negocios cercanos y a coordinar la entrega. Su tratamiento **requiere tu consentimiento**, que otorgas al activar los permisos de ubicación en tu dispositivo."),
            .bullets([
                "Durante un pedido activo, podemos mostrarte la ubicación del Repartidor para que sigas tu entrega; y el Repartidor podrá ver la dirección de entrega para llegar a ti.",
                "Puedes desactivar los permisos de ubicación desde los ajustes de tu dispositivo; algunas funciones (como Negocios cercanos o seguimiento) podrían dejar de funcionar.",
            ]),
            .heading("5. Transferencias de datos y proveedores"),
            .paragraph("Para operar la plataforma utilizamos proveedores tecnológicos (encargados) que tratan datos por cuenta y bajo instrucciones de Tregga. Conforme a la LFPDPPP, las transmisiones a encargados que prestan servicios a Tregga no requieren tu consentimiento adicional."),
            .keyValues([
                ("Supabase", "Infraestructura, base de datos y almacenamiento."),
                ("Google Maps", "Mapas, rutas y servicios de ubicación."),
                ("Stripe", "Procesamiento de pagos, cuando aplique."),
                ("Firebase Cloud Messaging (Google)", "Envío de notificaciones push."),
            ]),
            .paragraph("Para concretar tu pedido, compartimos con el **Negocio** y el **Repartidor** los datos necesarios (por ejemplo, tu nombre, los productos solicitados, la dirección de entrega y un medio de contacto). Podremos divulgar tus datos **sin tu consentimiento** únicamente en los casos previstos por el artículo 37 de la LFPDPPP, entre ellos a autoridades competentes en cumplimiento de obligaciones legales."),
            .heading("6. Conservación de los datos"),
            .paragraph("Conservamos tus datos durante el tiempo que mantengas una cuenta activa y, posteriormente, por los plazos necesarios para cumplir obligaciones legales, fiscales y contractuales, así como para atender posibles responsabilidades. Una vez cumplidas las finalidades y los plazos aplicables, tus datos se bloquean y se suprimen de forma segura."),
            .heading("7. Medidas de seguridad"),
            .paragraph("Implementamos medidas de seguridad administrativas, técnicas y físicas razonables para proteger tus datos contra daño, pérdida, alteración, destrucción o acceso no autorizado, entre ellas cifrado en tránsito, controles de acceso y autenticación mediante tokens de sesión. Ningún sistema es completamente infalible; en caso de una vulneración que afecte de forma significativa tus derechos, te lo notificaremos conforme a la ley."),
            .heading("8. Derechos ARCO, portabilidad y revocación"),
            .paragraph("Tienes derecho a **Acceder** a tus datos, **Rectificarlos** cuando sean inexactos, **Cancelarlos** cuando consideres que no se requieren, y **Oponerte** a su tratamiento para fines específicos (derechos **ARCO**). También puedes solicitar la **portabilidad** de tus datos y **revocar** el consentimiento que nos hayas otorgado."),
            .paragraph("Para ejercer estos derechos, envía tu solicitud a **arco@tregga.app**, indicando tu nombre y medio para recibir respuesta, los documentos que acrediten tu identidad, y la descripción clara de los datos y del derecho que deseas ejercer. Daremos respuesta en un plazo máximo de **20 días hábiles**."),
            .heading("9. \"Descargar mis datos\" y \"Eliminar cuenta\""),
            .bullets([
                "**Descargar mis datos:** desde la app puedes solicitar una exportación de tu información, como mecanismo adicional para ejercer tu derecho de acceso y portabilidad.",
                "**Eliminar cuenta:** desde la app puedes solicitar la eliminación de tu cuenta. Procederemos a suprimir o bloquear tus datos, salvo aquellos que debamos conservar por obligaciones legales o para la defensa de posibles reclamaciones.",
            ]),
            .heading("10. Limitación de responsabilidad sobre el tratamiento"),
            .paragraph("Tregga actúa como facilitador tecnológico. No somos responsables del tratamiento que el Negocio o el Repartidor den a la información que se comparte con ellos para concretar tu pedido, más allá de lo necesario para la entrega. Te recomendamos compartir únicamente la información necesaria."),
            .heading("11. Cambios al aviso de privacidad"),
            .paragraph("Este aviso puede actualizarse por cambios legales, operativos o en nuestras prácticas. Publicaremos la versión vigente dentro de la app y, cuando los cambios sean relevantes, te lo notificaremos por los medios disponibles. La fecha de vigencia y el número de versión te permiten identificar la versión aplicable."),
            .heading("12. Ley aplicable y autoridad"),
            .paragraph("El tratamiento de tus datos se rige por la **LFPDPPP** y su normatividad aplicable en México. Si consideras que tu derecho a la protección de datos ha sido vulnerado, puedes acudir ante la autoridad competente. Para cualquier controversia relacionada con este aviso serán competentes los tribunales del Estado de **Michoacán**, México."),
            .heading("13. Contacto"),
            .keyValues([
                ("Privacidad", "privacidad@tregga.app"),
                ("Derechos ARCO", "arco@tregga.app"),
                ("Soporte", "Dentro de la app"),
                ("Responsable", "Tregga Tech S.A. de C.V."),
            ]),
            .paragraph("Al continuar usando la app de Tregga manifiestas que leíste y entendiste este Aviso de Privacidad y que consientes el tratamiento de tus datos personales en los términos aquí descritos."),
        ]
    )

    // MARK: - Licencias de software libre

    static let licenciasOSS = LegalDocument(
        id: "licencias-oss",
        title: "Licencias de software libre",
        version: "1.0",
        effectiveDate: "junio 2026",
        summary: "Componentes de código abierto y servicios de terceros que hacen posible la app.",
        blocks: [
            .paragraph("Tregga Food se construye sobre componentes de **código abierto** y servicios de terceros. Agradecemos a sus autores. A continuación los listamos junto con su licencia."),
            .heading("Componentes de código abierto"),
            .keyValues([
                ("supabase-swift", "MIT · supabase-community"),
                ("swift-crypto", "Apache-2.0 · Apple"),
                ("swift-asn1", "Apache-2.0 · Apple"),
                ("swift-http-types", "Apache-2.0 · Apple"),
                ("swift-clocks", "MIT · Point-Free"),
                ("swift-concurrency-extras", "MIT · Point-Free"),
            ]),
            .paragraph("Las licencias **MIT** y **Apache-2.0** permiten el uso, copia y distribución del software con sus avisos de derechos de autor. El texto completo de cada licencia está disponible en el repositorio público de cada componente."),
            .heading("Servicios de terceros"),
            .paragraph("La app también usa servicios que **no** son de código abierto y se rigen por sus propios términos:"),
            .bullets([
                "**Google Maps SDK para iOS** — mapas y rutas, sujeto a los Términos de Google Maps Platform.",
                "**Supabase** — base de datos, autenticación y almacenamiento.",
                "**Stripe** — procesamiento de pagos, cuando aplique.",
                "**Firebase Cloud Messaging** — notificaciones push.",
            ]),
            .callout("Este aviso es informativo y no otorga derechos sobre las marcas o el software de terceros. El uso de cada servicio se rige por sus propios términos y avisos de privacidad."),
            .heading("Contacto"),
            .paragraph("¿Dudas sobre licencias o atribuciones? Escríbenos desde **Soporte** en la app o a **privacidad@tregga.app**."),
        ]
    )
}
