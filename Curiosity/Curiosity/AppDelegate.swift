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
                NSApp.mainWindow?.toggleFullScreen(nil)
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

