//
//  HammerTrackApp.swift
//  HammerTrack
//
//  Created by Claude on 2025-10-21.
//

import SwiftUI

@main
struct HammerTrackApp: App {

    init() {
        // Initialize ML model on app launch
        Task {
            do {
                try await MLModelService.shared.loadModel()
            } catch {
                print("Failed to load ML model: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)  // Optimal for Liquid Glass design
        }
    }
}
