//
//  ViewController.swift
//  Curiosity
//
//  Created by Tanel Lebedev on 28.07.2025.
//

import Cocoa
import AVFoundation

class ViewController: NSViewController {
    var playerLayer: AVPlayerLayer?
    var audioLoop = AudioLoop()
    
    // Sensor settings
    let maxSensorDistance: Float = 400.0

    // Audio settings
    let heartbeatMinVolume: Float = 0.5
    let heartbeatMaxVolume: Float = 1.0
    let heartbeatMinBPM: Float = 50    // calm, resting heart rate
    let heartbeatMaxBPM: Float = 140   // intense, stressed state
    let heartbeatMinRate: Float = 0.8
    let heartbeatMaxRate: Float = 3

    override func viewDidLoad() {
        super.viewDidLoad()

        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor

        let videoURL = Bundle.main.url(forResource: "video_forward", withExtension: "mp4")!
        let player = AVPlayer(url: videoURL)
        player.actionAtItemEnd = .pause

        let layer = AVPlayerLayer(player: player)
        layer.frame = view.bounds
        layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        view.layer?.addSublayer(layer)
        playerLayer = layer

        // Audio setup
        audioLoop.setVolume(0.5)
        audioLoop.setRate(1.0)
        audioLoop.start()
    }

    override var representedObject: Any? {
        didSet {
            // Update the view, if already loaded.
        }
    }
    
    @IBAction func distanceChanged(_ sender: NSSlider) {
        let simulatedDistance = sender.floatValue
        let normalized = max(0, min(1, simulatedDistance / maxSensorDistance))

        if let player = playerLayer?.player {
            let duration = player.currentItem?.duration ?? .zero
            let targetTime = CMTimeMultiplyByFloat64(duration, multiplier: Float64(normalized))
            player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }

        // Audio parameters
        let forward = 1 - normalized
        let inverse = 1 - forward

        let rate = heartbeatMinRate + inverse * (heartbeatMaxRate - heartbeatMinRate)
        let volume = heartbeatMinVolume + inverse * (heartbeatMaxVolume - heartbeatMinVolume)
        audioLoop.setVolume(Float(volume))
        audioLoop.setRate(Float(rate))

        print("Distance: \(Int(simulatedDistance)) → position: \(normalized)")
    }
}
