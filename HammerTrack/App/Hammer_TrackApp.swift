//
//  Hammer_TrackApp.swift
//  Hammer Track
//
//  Created by Merlin Hummel on 08.07.25.
//

import SwiftUI

@main
struct Hammer_TrackApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }
}
