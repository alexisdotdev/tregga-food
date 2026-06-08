//
//  TreggaFoodApp.swift
//  TreggaFood — app de cliente del ecosistema Tregga
//

import SwiftUI
import TreggaCore

@main
struct TreggaFoodApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var deps = AppDependencies()

    init() {
        GoogleMapsBootstrap.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.appDependencies, deps)
                .environment(\.locale, Locale(identifier: "es_MX"))
        }
    }
}
