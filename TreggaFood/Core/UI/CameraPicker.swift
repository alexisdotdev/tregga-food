import SwiftUI
import UIKit

/// Captura una foto con la cámara (frontal por defecto, para selfie de perfil) y
/// devuelve la `UIImage`. La cámara solo está disponible en dispositivo físico.
struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    /// Por defecto frontal (selfie de perfil); `true` usa la trasera (p.ej. fachada).
    var preferRear = false
    @Environment(\.dismiss) private var dismiss

    /// `false` en simulador → ocultar la opción "Tomar selfie".
    static var disponible: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        let device: UIImagePickerController.CameraDevice = preferRear ? .rear : .front
        if UIImagePickerController.isCameraDeviceAvailable(device) {
            picker.cameraDevice = device
        }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImage(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
