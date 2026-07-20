# Tregga Food — iOS

App nativa para **clientes** de Tregga (~19k LOC, 127 archivos Swift, 19 features).

## Estado

🧪 **Fase de pruebas** — el flujo del pedido corre end-to-end contra Supabase, sin mocks en la ruta:

| Área | Estado |
|---|---|
| Onboarding/auth: Welcome (correo + Google + Face ID) → OTP → signup 8 pantallas | ✅ |
| Descubrimiento: Home (Realtime), Buscar, Mapa de negocios | ✅ |
| Pedido: menú → modificadores → carrito → checkout (cupones, propina) → RPC `crear_pedido_cliente` | ✅ |
| Tracking en vivo (Google Maps + Routes API, notificación de proximidad a 300 m) | ✅ |
| Chat con repartidor (tabla `mensajes`, polling 3s) | ✅ |
| Calificación post-entrega | ✅ |
| Cuenta (11 rutas): datos, direcciones GPS/SEPOMEX, favoritos, privacidad, exportación, **borrado de cuenta** | ✅ |
| Push FCM (`aps-environment=production`) + notificaciones in-app | ✅ |
| Pagos | Efectivo y transferencia (decisión de producto — Opción C); tarjeta/Stripe diferidos |
| Tests | ⚠️ solo 7 `@Test` — la brecha principal |
| TestFlight / App Store | ⏳ pendiente |

Pendientes principales: tests (CheckoutViewModel, CartStore, PedidoStatus), `deliveryFee` server-side (hoy hardcodeado $25 en cliente), deep-link del push al tracking, persistencia del carrito.

## Stack

- **SwiftUI** · Swift 5 language mode con `MainActor` default isolation + approachable concurrency
- **iOS 18.6+**
- **Observation** (`@Observable`) + Swift Concurrency
- **supabase-swift 2.46** (Auth, PostgREST, Storage, Realtime)
- **Google Maps SDK 10.13** + Routes API
- **Firebase 12.14** (FCM + Crashlytics)
- **GoogleSignIn-iOS 9.2**
- **Swift Testing** (no XCTest)
- Paquetes compartidos: `../tregga-shared/TreggaCore` + `../tregga-shared/TreggaDesignSystem`

Backend compartido del ecosistema: Supabase (`uuvqihdzfvusjtpeixtw`) + API Next.js en `https://tregga.app`.

## Estructura

```
TreggaFood/
├── Core/        DI, Auth, Security, Push, Notifications, UI
├── Domain/      Modelos (Pedido, Tracking, Negocio, Menu…) · OnboardingCoordinator
├── Data/        17 repositorios (protocolo + Supabase + Mock) · Storage
└── Features/    Home · Catalog · Restaurant · ItemDetail · Cart · Checkout · Orders · Tracking ·
                 Chat · Rating · Direcciones · MapaNegocios · Offers · Notifications · Help ·
                 Account · Onboarding · Common · Shell
```

## Compilar

Xcode vive en `/Volumes/devcraftstudio/Aplicaciones/Xcode.app/` (disco externo). Requiere `secrets.xcconfig` (gitignored) con `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `GOOGLE_MAPS_API_KEY`, `GOOGLE_MAPS_MAP_ID`.

```bash
DEVELOPER_DIR="/Volumes/devcraftstudio/Aplicaciones/Xcode.app/Contents/Developer" \
  xcodebuild -project TreggaFood.xcodeproj -scheme TreggaFood \
  -destination 'generic/platform=iOS Simulator' build
```

## Apps del ecosistema

| App | Rol | Bundle ID | Estado |
|---|---|---|---|
| Tregga Food | Cliente | `app.tregga.food` | 🧪 Esta app |
| Tregga Delivery | Repartidor | `app.tregga.delivery` | 🧪 Fase de pruebas |
| Tregga Business | Negocio | `app.tregga.business` | 🧪 Fase de pruebas |
| Tregga Admin | Operador | `app.tregga.admin` | 📋 Pendiente |

Ports Android nativos (Compose) en `../Android/`, activos y con paridad auditada contra iOS.

## Documentación

- `CLAUDE.md` — contexto completo del proyecto (estado, capa de datos, gotchas, pendientes)
- `../docs/` — reglas transversales del ecosistema (identidad/login, contrato de auth API)
- `../docs/ANALISIS-IOS-food-2026-07-19.md` — análisis exhaustivo del código
- `docs/stripe-plan.md` — decisión de pagos (Opción C vigente)
