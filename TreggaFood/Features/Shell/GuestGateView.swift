import SwiftUI
import TreggaDesignSystem

/// Muro de login para invitados: se muestra en las pestañas que requieren cuenta
/// (Carrito, Cuenta). Explica por qué hace falta iniciar sesión y ofrece el CTA
/// que abre el flujo de login. App Store 5.1.1(v): el resto de la app (descubrir
/// negocios y ver menús) es libre; solo lo "de cuenta" pide sesión.
struct GuestGateView: View {
    let icon: TreggaIcon.Name
    let titulo: String
    let mensaje: String
    let onLogin: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(TreggaColors.primarySoft)
                    .frame(width: 96, height: 96)
                TreggaIcon(icon, size: 40, color: TreggaColors.primary)
            }

            VStack(spacing: 8) {
                Text(titulo)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(TreggaColors.text)
                Text(mensaje)
                    .font(.system(size: 15))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(TreggaColors.textSec)
                    .padding(.horizontal, 32)
            }

            Button(action: onLogin) {
                Text("Iniciar sesión")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(TreggaColors.primary, in: RoundedRectangle(cornerRadius: TreggaRadius.md))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32)
            .padding(.top, 8)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TreggaColors.bg)
    }
}
