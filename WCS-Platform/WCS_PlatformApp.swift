//
//  WCS_PlatformApp.swift
//  WCS-Platform
//
//  Created by Christopher Appiah-Thompson  on 25/4/2026.
//

import SwiftUI
import UIKit
import os

@main
struct WCS_PlatformApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let logger = Logger(subsystem: "org.worldclassscholars.platform", category: "lifecycle")

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .task {
                    Telemetry.event(.appLaunched)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
                    logger.warning("Memory warning received in app process")
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        logger.info("Scene phase changed: active")
                    case .inactive:
                        logger.info("Scene phase changed: inactive")
                    case .background:
                        logger.info("Scene phase changed: background")
                    @unknown default:
                        logger.info("Scene phase changed: unknown")
                    }
                }
        }
    }
}
