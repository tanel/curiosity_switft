//
//  Configuration.swift
//  Curiosity
//
//  Created by Tanel Lebedev on 29.07.2025.
//

import Foundation

struct Configuration: Codable {
    // Distance
    var maxDistance: Double
    var minDistance: Double
    
    // Game zones
    var saveZone: Double
    var deathZone: Double

    // Heartbeat volume
    var startingVolume: Double
    var finishingVolume: Double
    var waitingVolume: Double

    // Heartbeat rate
    var startingHeartBeatSpeed: Double
    var finishingHeartBeatSpeed: Double
    
    // Screen
    var fullScreen: Bool
    var showSimulationSlider: Bool
    var debugOverlay: Bool
    
    // Update loop
    var frameRate: Double
    
    // Timing
    var saveActivateSeconds: Double
    var autoSaveSeconds: Double
    var restartIntervalSeconds: Double
    
    // Serial port
    var portPath: String
}

func loadConfiguration() -> Configuration {
    let fileManager = FileManager.default

    // Try to load user-provided config from ~/Library/Application Support/Curiosity/configuration.json
    let userConfigURL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Curiosity/configuration.json")

    if fileManager.fileExists(atPath: userConfigURL.path),
       let data = try? Data(contentsOf: userConfigURL),
       let config = try? JSONDecoder().decode(Configuration.self, from: data) {
        return config
    }

    // Fallback to bundled default config
    if let bundledURL = Bundle.main.url(forResource: "configuration", withExtension: "json"),
       let data = try? Data(contentsOf: bundledURL),
       let config = try? JSONDecoder().decode(Configuration.self, from: data) {
        return config
    }

    fatalError("Failed to load configuration from both user and bundled sources.")
}
