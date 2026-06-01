import SwiftUI
import TreggaCore
import TreggaDesignSystem

/// Root del runtime de Tregga Food. En F0 muestra el Splash de marca; los
/// módulos (auth, discovery, carrito, tracking, cuenta) se cablean por fase.
struct ContentView: View {
    var body: some View {
        SplashScreen()
    }
}

/// Pantalla 00 — Splash. Equivalente a `ScreenSplash` del handoff de cliente:
/// fondo verde con motion stripes, logo Tregga y tagline.
struct SplashScreen: View {
    var body: some View {
        ZStack {
            TreggaColors.primary.ignoresSafeArea()
            MotionStripes(color: TreggaColors.primaryDeep, tint: TreggaColors.primary)
                .ignoresSafeArea()
                .opacity(0.6)

            VStack(spacing: 14) {
                Image("logo-tregga")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 64)

                Text("Tregga Food")
                    .font(.system(size: 30, weight: .heavy))
                    .foregroundStyle(.white)
                    .tracking(-0.5)

                Text("Tu antojo, al instante")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }
}

#Preview {
    ContentView()
}
