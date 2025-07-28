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
    
    // Distance configuration
    let maxDistance: Float = 400.0
    let minDistance: Float = 0.0

    // Heartbeat volume
    let heartbeatMinVolume: Float = 0.5
    let heartbeatMaxVolume: Float = 1.0
    let heartbeatStartVolume: Float = 0.5

    // Heartbeat rate
    let heartbeatMinRate: Float = 1.0
    let heartbeatMaxRate: Float = 2.0
    let heartbeatStartRate: Float = 1.0

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
        audioLoop.setVolume(heartbeatStartVolume)
        audioLoop.setRate(heartbeatStartRate)
        audioLoop.start()
    }

    @IBAction func distanceChanged(_ sender: NSSlider) {
        let simulatedDistance = sender.floatValue
        let normalized = max(minDistance, min(1, simulatedDistance / maxDistance))

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
