import SwiftUI
import TreggaCore
import Combine
import TreggaDesignSystem

/// Pantalla OTP del diseño client-v2. Cajas de dígitos + timer de reenvío.
public struct OTPView: View {
    @State private var viewModel: OTPViewModel
    @FocusState private var focused: Bool

    private let resendTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    public init(viewModel: OTPViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    Spacer().frame(height: 16)
                    badge
                    Spacer().frame(height: 14)
                    Text("Te mandamos un código")
                        .font(.system(size: 24, weight: .heavy))
                        .tracking(-0.4)
                        .foregroundStyle(TreggaColors.text)
                    Spacer().frame(height: 6)
                    Text("Ingresa el código de \(viewModel.expectedDigits) dígitos que enviamos a \(viewModel.kind.displayDestination).")
                        .font(.system(size: 15))
                        .foregroundStyle(TreggaColors.textSec)
                        .lineSpacing(2)
                    Spacer().frame(height: 28)
                    digitRow
                    hiddenField
                    Spacer().frame(height: 24)
                    resendRow
                    if let err = viewModel.error {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(TreggaColors.danger)
                            .padding(.top, 10)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 140)
            }
            footer
        }
        .background(TreggaColors.bg)
        .onReceive(resendTimer) { _ in viewModel.tickResendCountdown() }
    }

    private var header: some View {
        HStack {
            Button { viewModel.coordinator?.cancelOTP() } label: {
                TreggaIcon(.chevL, size: 20, color: TreggaColors.text)
                    .frame(width: 40, height: 40)
                    .background(TreggaColors.surface)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            Spacer()
            Text("Verificación")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(TreggaColors.text)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.top, 8)
    }

    private var badge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16).fill(TreggaColors.primarySoft)
            TreggaIcon(sfSymbol: viewModel.email != nil ? "envelope.fill" : "phone.fill", size: 24, color: TreggaColors.primaryDeep)
        }
        .frame(width: 56, height: 56)
    }

    private var digitRow: some View {
        HStack(spacing: 12) {
            ForEach(0..<viewModel.expectedDigits, id: \.self) { i in
                digitCell(at: i)
            }
        }
    }

    private func digitCell(at index: Int) -> some View {
        let chars = Array(viewModel.code)
        let digit = index < chars.count ? String(chars[index]) : ""
        let isFocused = index == chars.count && focused
        let filled = !digit.isEmpty
        return ZStack {
            RoundedRectangle(cornerRadius: 16).fill(TreggaColors.surface)
            RoundedRectangle(cornerRadius: 16)
                .stroke(isFocused || filled ? TreggaColors.primary : Color.clear, lineWidth: 2)
            Text(digit)
                .font(.system(size: viewModel.expectedDigits == 6 ? 24 : 30, weight: .heavy))
                .foregroundStyle(TreggaColors.text)
        }
        .frame(maxWidth: .infinity)
        .frame(height: viewModel.expectedDigits == 6 ? 60 : 72)
        .onTapGesture { focused = true }
    }

    private var hiddenField: some View {
        TextField("", text: $viewModel.code)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .focused($focused)
            .opacity(0.001)
            .frame(height: 1)
            .onAppear { focused = true }
            .onChange(of: viewModel.code) { _, new in
                let filtered = new.filter(\.isNumber)
                let cap = viewModel.expectedDigits
                let capped = String(filtered.prefix(cap))
                if capped != new { viewModel.code = capped }
            }
    }

    private var resendRow: some View {
        let countdown = viewModel.resendCountdown
        return HStack(spacing: 4) {
            Text("¿No te llegó?")
                .font(.system(size: 14))
                .foregroundStyle(TreggaColors.textSec)
            Button {
                if countdown == 0 { Task { await viewModel.resend() } }
            } label: {
                Text(countdown == 0 ? "Reenviar" : "Reenviar en 0:\(String(format: "%02d", countdown))")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(countdown == 0 ? TreggaColors.primary : TreggaColors.textTer)
            }
            .disabled(countdown > 0)
        }
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        Button { Task { await viewModel.verify() } } label: {
            HStack(spacing: 8) {
                Text(viewModel.loading ? "Verificando..." : "Verificar")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(.white)
                if !viewModel.loading {
                    TreggaIcon(.arrow, size: 18, color: .white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(viewModel.canVerify ? TreggaColors.primary : TreggaColors.primary.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!viewModel.canVerify || viewModel.loading)
        .padding(.horizontal, 18)
        .padding(.bottom, 34)
        .background(TreggaColors.bg)
    }
}

#Preview("Phone") {
    OTPView(viewModel: OTPViewModel(kind: .phone(e164: "+524431234567"), authService: MockAuthService(), coordinator: nil))
}

#Preview("Email") {
    OTPView(viewModel: OTPViewModel(kind: .email("juan@tregga.app"), authService: MockAuthService(), coordinator: nil))
}
