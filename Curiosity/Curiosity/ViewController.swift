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
    var cfg = loadConfiguration()
    
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
        audioLoop.setVolume(cfg.heartbeatStartVolume)
        audioLoop.setRate(cfg.heartbeatStartRate)
        audioLoop.start()
    }

    @IBAction func distanceChanged(_ sender: NSSlider) {
        let simulatedDistance = sender.floatValue
        let normalized = max(cfg.minDistance, min(1, simulatedDistance / cfg.maxDistance))

        if let player = playerLayer?.player {
            let duration = player.currentItem?.duration ?? .zero
            let targetTime = CMTimeMultiplyByFloat64(duration, multiplier: Float64(normalized))
            player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }

        // Audio parameters
        let forward = 1 - normalized
        let inverse = 1 - forward

        let rate = cfg.heartbeatMinRate + inverse * (cfg.heartbeatMaxRate - cfg.heartbeatMinRate)
        let volume = cfg.heartbeatMinVolume + inverse * (cfg.heartbeatMaxVolume - cfg.heartbeatMinVolume)
        audioLoop.setVolume(Float(volume))
        audioLoop.setRate(Float(rate))

        print("Distance: \(Int(simulatedDistance)) → position: \(normalized)")
    }
}
