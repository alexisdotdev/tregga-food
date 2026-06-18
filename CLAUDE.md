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

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

App nativa para clientes de Tregga. Segunda de las 4 apps nativas del ecosistema en migrar desde KMP. La app KMP legacy vive en `/Volumes/devcraftstudio/Developer/tregga-saas/tregga-mobile/` y queda en archive mode — consultarla SOLO para entender lógica de negocio ya resuelta (Supabase, pedidos, pagos, push).

## Responder en español

Siempre responde en español.

## Stack

- **Swift 6** + **SwiftUI**
- **iOS 18.0+** (deployment real: 18.6, default de Xcode 26)
- **Observation** framework (`@Observable`) para state management
- **Swift Concurrency** (async/await + actors)
- **Swift Testing** (no XCTest)
- `supabase-swift` (oficial) — pendiente integrar
- `URLSession` para Next.js API
- **Google Maps** para mapas y rutas
- **Firebase Messaging** (FCM) para push — pendiente
- **TreggaDesignSystem** Swift Package local

Backend sin cambios respecto al KMP legacy: Supabase project `uuvqihdzfvusjtpeixtw` + Next.js API en `../../tregga-saas/tregga-frontend/` (legacy path) o `https://tregga.app`.

## Estructura

```
tregga-Food/
├── TreggaFood.xcodeproj           # bundle ID: app.tregga.food
├── TreggaFood/                    # app target (synchronized folders)
│   ├── Features/                      # Una carpeta por feature
│   │   └── Onboarding/Splash/         # ✓ DScreenSplash
│   ├── DevTools/                      # DesignShowcase (preview-only)
│   ├── Assets.xcassets/               # logo-tregga.imageset
│   ├── TreggaFoodApp.swift        # @main
│   └── ContentView.swift              # root del runtime
├── Packages/
│   └── TreggaDesignSystem/            # SPM local — design system
│       ├── Package.swift
│       ├── Sources/TreggaDesignSystem/
│       │   ├── Tokens/                # Color+Tregga, Typography, Spacing
│       │   ├── Components/            # Screen, TreggaButton, Chip, Tag,
│       │   │                          # SearchBar, TreggaDivider, SectionHeader
│       │   ├── Driver/                # DStat, DKV, DriverHeader, DriverBottomNav,
│       │   │                          # DStepProgress, MotoIcon
│       │   ├── Patterns/              # MotionStripes
│       │   └── Icons/                 # TreggaIcon
│       └── Tests/TreggaDesignSystemTests/
├── TreggaFoodTests/
└── TreggaFoodUITests/
```

`TreggaFood/` y `Packages/TreggaDesignSystem/Sources/TreggaDesignSystem/` usan **synchronized folders** (Xcode 26). Crear `.swift` en cualquier subcarpeta lo hace aparecer en Xcode automáticamente, sin "Add Files to Project".

## Estado actual (al cierre 2026-05-16)

- ✅ Proyecto Xcode 26 inicializado, bundle ID `app.tregga.food`, iOS 18+
- ✅ Paquete `TreggaDesignSystem` completo (19 archivos fuente), build verificado contra iOS 18 SDK
- ✅ Pantalla **00 Splash** corriendo en simulador, validada por el usuario
- ⏳ **Siguiente**: pantalla **01 Welcome** (teléfono MX + OTP) + `OnboardingCoordinator` + auto-advance del Splash

22 pantallas totales a implementar. Lista en `README.md`.

## Convenciones

- **Commits**: español, presente, imperativo. Uso de corchetes al principio para indicar el tipo de cambio: `[feat]`, `[fix]`, `[docs]`, `[refactor]`, `[test]`, `[chore]`.
- **Idioma código**: inglés (clases, funciones, variables).
- **Idioma UI/strings**: español (es-MX). Locale `es`.
- **Comentarios**: español cuando sea necesario. **Default: ningún comentario**, solo cuando el WHY no es obvio (constraint oculta, workaround específico).
- **Tests**: Swift Testing (`@Test`, `#expect`), no XCTest.
- **Branches**: `main` estable. Feature branches `feat/<name>`, `fix/<name>`.

## Comandos útiles

Xcode está en `/Volumes/devcraftstudio/Aplicaciones/Xcode.app/` (disco externo, NO `/Applications/`). Cualquier `xcodebuild` necesita `DEVELOPER_DIR` explícito:

```bash
# Compilar paquete TreggaDesignSystem standalone (rápido, no necesita el .xcodeproj)
cd Packages/TreggaDesignSystem
DEVELOPER_DIR="/Volumes/devcraftstudio/Aplicaciones/Xcode.app/Contents/Developer" \
  xcodebuild -scheme TreggaDesignSystem \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/treggads-dd build 2>&1 | tail -40

# Compilar app completa
DEVELOPER_DIR="/Volumes/devcraftstudio/Aplicaciones/Xcode.app/Contents/Developer" \
  xcodebuild -project TreggaFood.xcodeproj -scheme TreggaFood \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/tregga-app-dd build 2>&1 | grep -E "(error|warning|BUILD)"

# Tests
DEVELOPER_DIR="/Volumes/devcraftstudio/Aplicaciones/Xcode.app/Contents/Developer" \
  xcodebuild test -project TreggaFood.xcodeproj -scheme TreggaFood \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'

# Abrir en Xcode
open TreggaFood.xcodeproj
```

## Diseño

Toda la dirección visual viene del **handoff de Claude Design** en `/tmp/tregga-handoff/tregga/` (vida limitada — re-fetchear si se borra el `/tmp`).

Brand:
- `primary` `#0DB55C` · `primaryDeep` `#055E2D` · `primarySoft` `#E4F7EC`
- `accent` `#FF6B2C` (promos, cobros externos)
- Light + dark mode completo
- Fonts: Plus Jakarta Sans (body) + Sora (display) — pendientes de registrar; ahora SF Pro de fallback en `TreggaFontResolver`.

Al portar una pantalla del handoff:
1. Leer el `.jsx` correspondiente (e.g. `driver-onboarding.jsx`)
2. Traducir estructura + valores literales (sizes, colors, radii) a SwiftUI
3. Usar tokens del paquete (`TreggaColors.X`, `.treggaStyle(.h2)`, `TreggaRadius.lg`) en lugar de literales

## Apps del ecosistema

| App | Repo | Bundle ID | Estado |
|---|---|---|---|
| Tregga Delivery (repartidor) | `tregga-delivery` | `app.tregga.delivery` | Listo |
| Tregga Food (cliente) | `tregga-food` | `app.tregga.food` | 🚧 En desarrollo |
| Tregga Admin | `tregga-admin` | `app.tregga.admin` | 📋 Pendiente |
| Tregga Food Place (negocio) | `tregga-food-place` | `app.tregga.foodplace` | 📋 Pendiente |

Versiones Android nativas (Compose + Material 3 Expressive, Android 10+) viven en repos paralelos `*-android` — futuro.

## Gotchas conocidos

- **"Add Local Package" en Xcode tiene 2 pasos**: agregar la referencia AL PROYECTO + vincular el producto AL TARGET. El segundo paso es fácil de saltar; si se salta, build falla con `error: Unable to find module dependency: 'TreggaDesignSystem'`. Fix: Target → General → Frameworks, Libraries, and Embedded Content → `+` → seleccionar la library del paquete.
- **Diagnostics del LSP (SourceKit) pueden ser falsos positivos** — "No such module 'TreggaDesignSystem'" o "Cannot find 'TreggaColors' in scope" aparecen cuando el LSP lintea archivos individuales sin contexto de proyecto. La verdad la dice `xcodebuild`.
- **Test target bundle IDs** quedaron con formato viejo (`app.tregga.TreggaDeliveryTests` en vez de `app.tregga.delivery.tests`). Cosmético, no bloquea. Fix futuro: Target settings → Bundle Identifier.

## Documentación relacionada

- `README.md` — overview público del repo + plan de 22 pantallas
- `../../tregga-saas/tregga-mobile/MIGRATION.md` — razones de la migración (uncommitted; el usuario lo commitea)
- `../../tregga-saas/tregga-mobile/CLAUDE.md` — contexto KMP legacy. Útil para consultar lógica de negocio (Supabase, pedidos, pagos, push) ya resuelta.
- `/tmp/tregga-handoff/tregga/` — design handoff con todos los `.jsx` y screenshots


## Metodología de desarrollo
- **Pincipios SOLID**: Single Responsibility, Open/Closed, Liskov Substitution, Interface Segregation, Dependency Inversion.
- **Clean Architecture**: separación clara entre capas (UI, Domain, Data) y dependencias unidireccionales.
- **Test-Driven Development (TDD)**: escribir tests antes de implementar la funcionalidad, asegurando código testeable y de calidad.
- **Code Reviews**: revisión de código entre pares para mantener estándares de calidad y compartir conocimiento.
- **Continuous Integration**: integración continua con pipelines de build y test para detectar errores temprano.
- **Documentación**: mantener documentación actualizada y clara para facilitar onboarding y mantenimiento.

## Animaciones y transiciones suaves usando `withAnimation` y `matchedGeometryEffect` para mejorar la experiencia de usuario. Evitar animaciones complejas que puedan afectar el rendimiento en dispositivos más antiguos. Priorizar la fluidez y la simplicidad en las interacciones visuales. tambien recordar que puedes verificar el uso de animaciones en el simulador de Xcode para asegurarte de que se ejecutan sin problemas en diferentes dispositivos y versiones de iOS y liquidglass.