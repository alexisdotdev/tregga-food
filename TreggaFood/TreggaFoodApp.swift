//
//  TreggaFoodApp.swift
//  TreggaFood — app de cliente del ecosistema Tregga
//

import SwiftUI
import TreggaCore
import UserNotifications

@main
struct TreggaFoodApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var deps = AppDependencies()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        GoogleMapsBootstrap.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.appDependencies, deps)
                .environment(\.locale, Locale(identifier: "es_MX"))
        }
        // El badge del ícono lo pone el push (badge:1) y no se borraba solo; lo
        // reseteamos al volver al frente, como Business/Delivery.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                UNUserNotificationCenter.current().setBadgeCount(0)
            }
        }
    }
}
