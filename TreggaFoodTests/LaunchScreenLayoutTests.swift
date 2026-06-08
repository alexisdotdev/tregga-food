import Testing
import UIKit
@testable import TreggaFood

/// Regresión del launch screen nativo. El fondo (gradiente + logo) está horneado
/// en una sola imagen mostrada con `scaleAspectFill` a pantalla completa, así que
/// el logo no puede salir a su tamaño intrínseco. Verificamos esa estructura.
@MainActor
@Test func launchScreenFillsScreenAndShowsTagline() throws {
    let sb = UIStoryboard(name: "LaunchScreen", bundle: .main)
    let vc = try #require(sb.instantiateInitialViewController())
    let size = CGSize(width: 393, height: 852)
    vc.view.frame = CGRect(origin: .zero, size: size)
    vc.view.layoutIfNeeded()

    var imageViews: [UIImageView] = []
    var labels: [UILabel] = []
    func walk(_ v: UIView) {
        if let iv = v as? UIImageView { imageViews.append(iv) }
        if let l = v as? UILabel { labels.append(l) }
        v.subviews.forEach(walk)
    }
    walk(vc.view)

    // Único imageView, a pantalla completa, scaleAspectFill.
    let bg = try #require(imageViews.first)
    #expect(imageViews.count == 1)
    #expect(bg.contentMode == .scaleAspectFill)
    #expect(abs(bg.bounds.width - size.width) < 1)
    #expect(abs(bg.bounds.height - size.height) < 1)

    // Tagline presente.
    #expect(labels.contains { $0.text == "Tu antojo, al instante" })
}
