//
//  AppDelegate.swift
//  Curiosity
//
//  Created by Tanel Lebedev on 28.07.2025.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    var cfg = ConfigurationManager.shared

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if cfg.fullScreen {
            DispatchQueue.main.async {
                if let window = NSApplication.shared.windows.first {
                    window.toggleFullScreen(nil)
                }
            }
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
