# Tregga Food — iOS

# CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

App nativa para **clientes** de Tregga (~19k LOC, 127 archivos Swift, 19 features). **Fase actual: pruebas** — el flujo del pedido completo (descubrir → menú → carrito → checkout con cupones → tracking → chat → calificación) corre end-to-end contra Supabase, sin mocks en la ruta. La app KMP legacy en `/Volumes/devcraftstudio/Developer/tregga-saas/tregga-mobile/` queda en archive mode — consultarla SOLO para lógica de negocio ya resuelta.

## Responder en español

Siempre responde en español.

## Stack

- **SwiftUI** sobre **Swift 5 language mode** (⚠️ NO Swift 6 mode: `SWIFT_VERSION = 5.0` con `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` + `SWIFT_APPROACHABLE_CONCURRENCY`)
- **iOS 18.6+** (nivel proyecto; ⚠️ el target de app dice 26.0 — inconsistencia por unificar)
- `TARGETED_DEVICE_FAMILY = "1,2"` — sin layouts iPad específicos
- **Observation** (`@Observable`) + Swift Concurrency + **Swift Testing** (no XCTest)
- **supabase-swift 2.46** (Supabase, Auth, PostgREST, Storage) — integrado y por default
- **Google Maps SDK 10.13** + **Routes API** (polyline del tracking)
- **Firebase 12.14**: FirebaseMessaging (FCM) + FirebaseCrashlytics — integrados; entitlement `aps-environment = production`
- **GoogleSignIn-iOS 9.2** (login Google nativo con `signInWithIdToken`)
- Paquetes compartidos por ruta relativa: `../tregga-shared/TreggaCore` + `../tregga-shared/TreggaDesignSystem`

Backend: Supabase project `uuvqihdzfvusjtpeixtw` + API Next.js `https://tregga.app` (`Config.API_BASE` en TreggaCore).

## Estructura (Clean Architecture 3 capas — sin UseCases; VMs llaman repos directo)

```
TreggaFood/
├── TreggaFoodApp.swift            # @main, AppDelegate adaptor (FCM), locale es_MX
├── ContentView.swift              # 432 líneas: gate remoto → splash → onboarding → shell
├── Core/
│   ├── DI/AppDependencies.swift   # composition root; inyectado vía EnvironmentValues.appDependencies
│   ├── Auth/ Security/ Push/ Notifications/ Support/ UI/ + GoogleMapsBootstrap, AppearanceMode
├── Domain/
│   ├── Models/                    # Pedido, PedidoHistorial, Tracking, Negocio, MenuModels, Cliente…
│   └── Onboarding/OnboardingCoordinator.swift
├── Data/
│   ├── Repositories/              # 17 archivos: protocolo + SupabaseX + MockX cada uno
│   └── Storage/                   # SupabaseStorageService
└── Features/                      # 19 carpetas:
    Home · Catalog · Restaurant · ItemDetail · Cart · Checkout · Orders · Tracking · Chat ·
    Rating · Direcciones · MapaNegocios · Offers · Notifications · Help · Account ·
    Onboarding · Common · Shell
```

Shell autenticado: `ClientTabView` con 5 tabs keep-alive (inicio · live/mapa · buscar · carrito · cuenta) y barra flotante custom (`ClientBottomBar`).

## Estado actual (2026-07-19 · fase de pruebas)

- ✅ **Onboarding/auth completos**: Welcome (correo + Google + Face ID) → OTP → signup 8 pantallas (`Signup/SignupViews.swift`) → permisos. Re-login **biométrico** solo tras logout (NO candado de arranque — decisión en `ContentView.swift:132-136`); restauración de sesión con refresh REAL contra backend y tolerancia offline (conserva sesión en `networkFailure`/`weakConnection`).
- ✅ **Flujo del pedido e2e contra Supabase**: Home (vista `negocios_publicos` + **Realtime** con backoff y re-auth) → Restaurant (menú + horarios + revalida `acepta_pedidos`) → ItemDetail (modificadores) → CartStore → Checkout → Tracking (polling 4.5s, Google Maps + Routes API, notificación local a 300m) → Chat (polling 3s) → `DeliveryRatingFlow`.
- ✅ **Checkout defensivo**: guard de reentrancia anti doble-pedido, gate `count_repartidores_activos` **fail-open**, resolución de `clienteId` real ANTES de navegar, cupones vía RPC `calcular_descuento`, push al negocio vía POST `https://tregga.app/api/pedidos/notify-negocio` (fire-and-forget).
- ✅ **Cuenta completa** (11 rutas): datos personales, direcciones (mapa/GPS/SEPOMEX), favoritos, preferencias, privacidad, seguridad (cambio de contraseña real), exportación de datos, **eliminación de cuenta vía RPC `delete_my_account`** (App Store 5.1.1(v)), inbox, legal in-app.
- ✅ **Push FCM** con ciclo de vida del token ligado a sesión (`device_tokens`, upsert/desactivar) + feature Notifications real (tabla `notificaciones`).
- ✅ **Gates remotos** mantenimiento/actualización forzada (`app_config`), fail-open.
- ✅ **Pagos — decisión de producto (Opción C, `docs/stripe-plan.md`)**: SOLO efectivo y transferencia, liquidados directo al repartidor. `MetodoPago.seleccionables = [.efectivo, .transferencia]` (`Domain/Models/Pedido.swift:14`); **tarjeta NO seleccionable**. `Features/Checkout/PaymentGateway.swift` (StubStripeGateway) es **código muerto sin referencias** — no hay riesgo funcional; decidir borrar o cablear si se retoma Stripe (Opción B: Connect Express).
- ⚠️ **Solo 7 `@Test` para 19k LOC** — la brecha principal para producción es verificación, no funcionalidad. Prioridad: `CheckoutViewModel`, `CartStore`, `PedidoStatus`, mapeos DTO. Los mocks y protocolos ya existen, están sin usar.
- ⚠️ **`deliveryFee` se calcula en el servidor** (`TarifaRepository`), pero **sigue viajando desde el cliente** a `crear_pedido_cliente`, que lo persiste sin validar → un cliente modificado puede mandar otro monto. **La defensa real es el *floor* server-side que web tiene pendiente.** El `25` ya no es el valor cobrado sino el estimado de arranque: si el cálculo falla (dirección sin pin, negocio sin coordenadas, API caída) el checkout **lo dice** en vez de cobrarlo en silencio (`envioEsEstimado`).
- ⚠️ **Push sin deep-link**: `didReceive response` no navega al tracking del pedido.
- ⚠️ **Carrito sin persistencia** (estado en memoria; matar la app lo vacía).

## Capa de datos

- **17 repositorios** (patrón: `protocol X: Sendable` + `SupabaseX` + `MockX`, DTOs privados snake_case sin CodingKeys + `toDomain()`): Catalog, Pedido, Tracking, DireccionCliente, Cliente, Profile, Mensaje, Calificacion, Notificacion, Preferencias, Favorito, Oferta, AppConfig, Account, Feedback, Storage, DeviceToken.
- **Tablas/vistas (23)**: `negocios_publicos` (vista), `negocios`, `categorias_menu`, `productos`, `grupos_modificadores`, `modificadores`, `horarios_negocio`, `pedidos`, `repartidores`, `vehiculos`, `clientes`, `profiles`, `direcciones_cliente`, `mensajes`, `calificaciones`, `notificaciones`, `preferencias_usuario`, `favoritos`, `promociones`, `reportes`, `solicitudes_export`, `device_tokens`, `app_config`.
- **RPCs (7)**: `crear_pedido_cliente`, `calcular_descuento`, `count_repartidores_activos`, `get_repartidor_phone` (SECURITY DEFINER), `vincular_cliente`, `set_direccion_default`, `delete_my_account`.
- **Realtime** solo en catálogo; tracking y chat van por **polling** (migrar chat a Realtime es mejora pendiente).
- Estados del pedido (`Domain/Models/Tracking.swift`): `pending · assigned · en_recogida · recogido · en_entrega · completed · cancelled` — idénticos en las 6 apps y el enum del server. `pending` sin `negocioConfirmedAt` = "esperando al negocio" (paso −1).

## Flags de desarrollo

- `-USE_MOCK YES` — activa mocks (solo DEBUG). ⚠️ El flag es `USE_MOCK`, NO `USE_SUPABASE_BACKEND` (el docstring viejo de `AppDependencies.swift` miente). Release: siempre backend real.
- `-BYPASS_OTP YES` — acepta cualquier código (solo DEBUG).

## Identidad y login (canónico, ver `../docs/`)

Reglas de producto 2026-07-16/18 (`../docs/IDENTIDAD-Y-LOGIN-reglas.md`, `../docs/APPS-HANDOFF-auth-api-roles-e-ip.md`):
- **Correo = identidad**; login SOLO por correo (código OTP **o** contraseña). Teléfono = contacto, NO login.
- **Persona = una cuenta, roles agregables**: un repartidor que entra a Food se convierte en cliente automáticamente (`vincular_cliente`, idempotente, NO pisa roles). Rol efectivo = `roles[] ∪ {role}`.
- **El REGISTRO de cliente pasa por `POST /api/cliente/register`** (captura IP server-side); login directo a Supabase OK.
- "Recordar sesión" conserva la sesión → CTA "Continuar como <correo>"; si biometría activa, manda el CTA biométrico.

## Convenciones

- **Commits**: español, presente, imperativo, prefijo `[feat]`/`[fix]`/`[docs]`/`[refactor]`/`[test]`/`[chore]`.
- **Idioma código**: inglés. **UI/strings**: español (es-MX). **Comentarios**: default ninguno; español solo cuando el WHY no es obvio.
- **Tests**: Swift Testing (`@Test`, `#expect`), no XCTest.
- **Branches**: `main` estable; `feat/<name>`, `fix/<name>`.
- **Patrones defensivos ya establecidos** (mantener al tocar checkout/sesión): reentrancia por `phase`, fail-open en gates de red, ids reales antes de navegar, errores visibles en vez de `try?` silencioso, revalidar `acepta_pedidos` al entrar al detalle.

## Comandos útiles

Xcode está en `/Volumes/devcraftstudio/Aplicaciones/Xcode.app/` (disco externo). `xcodebuild` necesita `DEVELOPER_DIR` explícito:

```bash
DEVELOPER_DIR="/Volumes/devcraftstudio/Aplicaciones/Xcode.app/Contents/Developer" \
  xcodebuild -project TreggaFood.xcodeproj -scheme TreggaFood \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/tregga-app-dd build 2>&1 | grep -E "(error|warning|BUILD)"

DEVELOPER_DIR="/Volumes/devcraftstudio/Aplicaciones/Xcode.app/Contents/Developer" \
  xcodebuild test -project TreggaFood.xcodeproj -scheme TreggaFood \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Vía XcodeBuildMCP: usar **id explícito** de sims iOS 26 (iPhone 17 Pro `CBE92E2E-10DF-478E-A87F-DB40EEF3BE52`, iPad Pro 11" `654E7117-1EFA-4BE0-AAAD-076EEEE1B2AA`).

## Diseño

Brand: `primary` `#0DB55C` · `primaryDeep` `#055E2D` · `primarySoft` `#E4F7EC` · `accent` `#FF6B2C`. Light + dark completo (`AppearanceMode`). Tokens y componentes en `../tregga-shared/TreggaDesignSystem`; iconos vía `TreggaIcon` (Hugeicons). El handoff original en `/tmp/tregga-handoff/` es efímero; el canon vigente son las pantallas ya portadas (iOS es la fuente de verdad de paridad con Android).

## Apps del ecosistema

| App | Rol | Repo | Bundle ID | Estado |
|---|---|---|---|---|
| Tregga Delivery | Repartidor | `tregga-delivery` | `app.tregga.delivery` | 🧪 Fase de pruebas (beta avanzada; pagos mock) |
| Tregga Food | Cliente | `tregga-food` | `app.tregga.food` | 🧪 Fase de pruebas (flujo e2e completo) |
| Tregga Business | Negocio | `tregga-business` | `app.tregga.business` | 🧪 Fase de pruebas (la más completa) |
| Tregga Admin | Operador | `tregga-admin` | `app.tregga.admin` | 📋 Pendiente (carpeta vacía) |

Ports **Android nativos** (Compose) viven en `../Android/` y están ACTIVOS — paridad auditada (`../tregga-business/docs/paridad-ui-2026-07.md`).

## Gotchas conocidos

- **`Config.SUPABASE_URL`/`SUPABASE_ANON_KEY` hacen `fatalError()`** si falta `secrets.xcconfig` (gitignored). La cabecera del xcconfig dice "Tregga Delivery" — copia/pega, ignorar.
- **`PaymentMethodsView` está hardcodeada** (`Account/AccountSecondaryViews.swift`) — NO refleja `MetodoPago.seleccionables`; si cambia el enum, actualizarla a mano.
- **`ScreenOffers`: botón "Aprovechar" es cosmético** (`Features/Offers/OffersView.swift:5`) — el cupón real se aplica en Checkout.
- **`HelpData.swift` y `LegalDocuments.swift` son estáticos in-app** (sin backend, a propósito). Los legales declaran a Stripe como sub-encargado aunque no hay integración — revisar al publicar.
- **Diagnostics del LSP pueden ser falsos positivos** — la verdad la dice `xcodebuild`.
- **Bundle IDs de tests** con formato viejo. **`print()` como logging** en AppDelegate/PushTokenCoordinator.
- `BuscarTabView` no tiene realtime (solo refresca al reactivar la app — comentario en `:86`).

## Pendientes para producción

1. **Tests** (prioridad 1: CheckoutViewModel, CartStore, PedidoStatus, DTOs).
2. `deliveryFee` server-side.
3. Deep-link del push al tracking.
4. `os.Logger` + configurar/usar Crashlytics (linkeado, sin evidencia de uso).
5. Persistencia del carrito.
6. Borrar o cablear `PaymentGateway.swift`.
7. Unificar deployment target (26.0 vs 18.6) y postura Swift 6.
8. Chat a Realtime.

## Documentación relacionada

- `../docs/` — **reglas transversales del ecosistema** (identidad/login, contrato de auth API, handoffs).
- `docs/stripe-plan.md` — decisión de pagos (Opción C vigente; plan técnico de Stripe diferido).
- `../tregga-business/docs/auditoria-cross-app-2026-07.md` — auditoría de las 6 apps (críticos corregidos; el 🟠#5 "desglose sin línea de descuento" ya se muestra en `OrderDetailView`).
- `README.md` — overview público del repo (creado 2026-07-19).

## Metodología de desarrollo
- **Principios SOLID** y **Clean Architecture** (capas UI/Domain/Data, dependencias unidireccionales).
- **TDD** cuando aplique; **code reviews**; **documentación actualizada**.

## Animaciones y transiciones suaves usando `withAnimation` y `matchedGeometryEffect` para mejorar la experiencia de usuario. Evitar animaciones complejas que puedan afectar el rendimiento en dispositivos más antiguos. Priorizar la fluidez y la simplicidad en las interacciones visuales. También verificar animaciones en el simulador (distintos dispositivos, versiones de iOS y Liquid Glass).
