//
//  TreggaFoodApp.swift
//  TreggaFood — app de cliente del ecosistema Tregga
//

import SwiftUI
import TreggaCore

@main
struct TreggaFoodApp: App {
    @State private var deps = AppDependencies()

    init() {
        GoogleMapsBootstrap.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.appDependencies, deps)
        }
    }
}
