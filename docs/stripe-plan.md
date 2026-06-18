# Plan: pagos con Stripe en Tregga Food

> Estado: **plan / discusión** (sin código). Última actualización 2026-06-05.
> ⚠️ Las implicaciones fiscales aquí son orientativas — **validar con un contador en México** antes de decidir.

> **DECISIÓN 2026-06-05 → Opción C.** Por ahora solo **efectivo y transferencia**,
> ambos pagados **directo al repartidor al recibir**. Stripe queda diferido para no
> asumir la carga fiscal de Tregga como empresa de pagos. Cuando se quiera tarjeta
> sin formalizar Tregga, retomar **Opción B (Connect a repartidores)**. La app ya
> está en este estado (`MetodoPago.seleccionables = [.efectivo, .transferencia]`).

## 1. La restricción que manda: lo fiscal, no lo técnico

Hoy Tregga **no toca dinero**: el cliente paga efectivo/transferencia **directo al repartidor** al recibir. Eso mantiene a Tregga fuera del circuito de dinero del pedido → **cero obligaciones fiscales de pagos** para Tregga.

El momento en que se abre una cuenta Stripe **a nombre de Tregga** y ésta recibe dinero del cliente, Tregga pasa a ser un negocio que **cobra un servicio (envío)** y debe:
- Tener RFC (persona física con actividad empresarial, o persona moral).
- Emitir CFDI por cada envío cobrado.
- Declarar y pagar **IVA (16%)** e **ISR** sobre esos ingresos.
- Llevar contabilidad.

Conclusión: **no es "prender Stripe", es "formalizar Tregga como empresa de servicios de envío".** Por eso conviene elegir la arquitectura según quién quieres que aparezca como el que cobra.

## 2. Tres arquitecturas posibles (con su costo fiscal)

### Opción A — Cuenta Stripe única de Tregga
- El **envío** entra a la cuenta Stripe de Tregga. Tregga luego paga (cashout) al repartidor.
- ✅ Control total, un solo onboarding (el de Tregga), reporting central.
- ❌ Tregga **factura y paga impuestos** por todos los envíos. Requiere constituir/operar Tregga formalmente. Es justo la carga que quieres evitar hoy.
- Encaja con el modelo "Tregga procesa solo el envío" del business model, **pero** asumiendo que Tregga ya es una entidad fiscal.

### Opción B — Stripe Connect, el repartidor recibe directo  ⭐ (la más alineada al gremio)
- Cada repartidor tiene una **subcuenta Stripe Connect (Express)**. El envío va **directo a su cuenta**; Tregga solo orquesta el cobro (puede tomar un `application_fee` = 0 o su comisión futura).
- Tregga **no toca el dinero del envío** → **no lo factura ni paga impuestos por él**. Tregga sigue cobrando su **cuota semanal** aparte (como hoy).
- Cada repartidor (persona física, RESICO/RIF) declara lo suyo — igual que ya hace con el efectivo.
- ✅ Mantiene el modelo gremio intacto, mínima carga fiscal para Tregga, el repartidor cobra digital igual que cobraba efectivo.
- ❌ Cada repartidor debe completar **onboarding KYC con Stripe** (RFC/CURP, cuenta bancaria). Más fricción de alta. Connect tiene su propia complejidad técnica.

### Opción C — No usar Stripe aún (mantener efectivo + transferencia)
- Seguir con lo que ya funciona y **no toca dinero**: efectivo y transferencia directa al repartidor.
- ✅ Cero carga fiscal nueva, cero comisión Stripe (~3.6% + IVA en MX), cero onboarding.
- ❌ Menos "moderno"; el cliente sigue necesitando efectivo/hacer transferencia manual.
- Válido como **decisión de negocio**: el valor de "pagar el envío con tarjeta" puede no compensar el costo fiscal+comisión todavía.

## 3. Recomendación

1. **Corto plazo:** quédate en **Opción C** (efectivo + transferencia). Es coherente con que aún no quieres la carga fiscal de Tregga. La transferencia ya cubre el "pago digital" sin que Tregga toque el dinero.
2. **Cuando quieras pago con tarjeta sin volverte empresa:** ve a **Opción B (Connect a repartidores)**. Es la única que da tarjeta **sin** que Tregga tenga que facturar/pagar impuestos por los envíos.
3. **Opción A** solo cuando decidas formalizar Tregga como empresa de servicios de envío (con contador y RFC). Ahí ya tiene sentido la cuenta única.

> En las 3, **Stripe cobra solo el envío** (nunca el producto) — eso no cambia.

## 4. Qué ya existe (no hay que rehacer)
- App: `PaymentGateway` (protocolo) + `StubStripeGateway` (hoy `.pendienteConfiguracion`). `MetodoPago.tarjeta` en el enum, fuera de `seleccionables`.
- Supabase: `STRIPE_SECRET_KEY` guardada; cuenta Stripe de **PRUEBA** `acct_1T6HO8…`. Tabla `pagos` (vacía). RPC `crear_pedido_cliente`.
- **Falta** en backend: edge function de PaymentIntent (no existe; solo `payment-reminders`).

## 5. Plan técnico (cuando se decida A o B)

### Común a A y B
1. **Edge function `create-payment-intent`** (Deno + Stripe SDK):
   - Input: `pedido_id` (o `delivery_fee`), `cliente_id`. Calcula el monto del **envío** server-side (no confiar en el cliente).
   - Crea `PaymentIntent(amount=delivery_fee*100, currency='mxn')`.
   - Devuelve `client_secret`.
2. **Stripe iOS SDK** vía SPM + **PaymentSheet** en `CheckoutView` (método "Pagar envío con tarjeta").
3. **`StripeGateway`** real que implementa `PaymentGateway`, reemplaza el stub, usa el `client_secret`.
4. Habilitar `.tarjeta` en `MetodoPago.seleccionables`.
5. **Webhook** `stripe-webhook` (edge function) que escucha `payment_intent.succeeded` → marca `pedidos.payment_status='paid'` y registra en `pagos`. (No confiar solo en el cliente).
6. `crear_pedido_cliente` con `payment_method='tarjeta'`, `payment_status` según el webhook.

### Extra solo para Opción B (Connect)
- Modelo de datos: `repartidores.stripe_account_id`.
- Edge function `create-connect-account` + `create-account-link` (onboarding Express del repartidor).
- En `create-payment-intent`: `transfer_data[destination] = repartidor.stripe_account_id`, `application_fee_amount = 0` (o comisión futura).
- UI de onboarding Stripe en la app del **repartidor** (tregga-delivery), no en Food.

### Tarjetas de prueba (cuenta test)
- Éxito: `4242 4242 4242 4242` · cualquier fecha futura · CVC 3 díg.
- Requiere 3DS: `4000 0027 6000 3184`.
- Rechazada: `4000 0000 0000 9995`.

## 6. Decisiones pendientes (tuyas / con contador)
- [ ] ¿Formalizar Tregga como entidad fiscal (Opción A) o mantener al repartidor como receptor (Opción B)?
- [ ] Si B: ¿los repartidores están dispuestos al onboarding KYC de Stripe (RFC/CURP/banco)?
- [ ] ¿El cobro del envío con tarjeta justifica la comisión Stripe (~3.6% + IVA) sobre un envío de ~$25?
- [ ] ¿Quién absorbe la comisión Stripe: Tregga, el repartidor, o se suma al cliente?
