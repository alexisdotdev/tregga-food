import SwiftUI
import UIKit

extension View {
    /// Agrega una barra sobre el teclado con un botón "Listo" para cerrarlo.
    /// El usuario a veces solo quiere bajar el teclado para ver mejor.
    func keyboardDoneToolbar() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Listo") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }
                .font(.system(size: 16, weight: .semibold))
            }
        }
    }
}
