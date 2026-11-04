import Testing
import UIKit
@testable import TreggaFood

/// Regresión del launch screen nativo (splash v2, spec compartida con Android).
/// Es verde liso #079247, sin logo ni texto: el splash SwiftUI arranca desde
/// opacidad 0 sobre ese mismo color, así que el paso launch → splash no salta.
@MainActor
@Test func launchScreenIsPlainSplashGreen() throws {
    let sb = UIStoryboard(name: "LaunchScreen", bundle: .main)
    let vc = try #require(sb.instantiateInitialViewController())
    vc.view.layoutIfNeeded()

    #expect(vc.view.subviews.isEmpty)

    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    try #require(vc.view.backgroundColor).getRed(&r, green: &g, blue: &b, alpha: &a)
    #expect(Int((r * 255).rounded()) == 0x07)
    #expect(Int((g * 255).rounded()) == 0x92)
    #expect(Int((b * 255).rounded()) == 0x47)
    #expect(a == 1)
}
