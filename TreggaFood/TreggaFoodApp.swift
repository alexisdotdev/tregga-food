//
//  TreggaFoodApp.swift
//  TreggaFood — app de cliente del ecosistema Tregga
//

import SwiftUI
import TreggaCore
import UserNotifications

@main
struct TreggaFoodApp: App {
    @State private var deps = AppDependencies()

    init() {
        GoogleMapsBootstrap.configure()
        UNUserNotificationCenter.current().delegate = NotificationPresenter.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.appDependencies, deps)
        }
    }
}
