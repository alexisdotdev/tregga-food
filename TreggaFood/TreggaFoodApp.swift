//
//  TreggaFoodApp.swift
//  TreggaFood — app de cliente del ecosistema Tregga
//

import SwiftUI

@main
struct TreggaFoodApp: App {
    @State private var deps = AppDependencies()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.appDependencies, deps)
        }
    }
}
