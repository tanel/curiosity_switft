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
    
    let maxSensorDistance: Float = 400.0

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
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    @IBAction func distanceChanged(_ sender: NSSlider) {
        let simulatedDistance = sender.floatValue          // already inverted
        let normalized = max(0, min(1, simulatedDistance / maxSensorDistance))

        if let player = playerLayer?.player {
            let duration = player.currentItem?.duration ?? .zero
            let targetTime = CMTimeMultiplyByFloat64(duration, multiplier: Float64(normalized))
            player.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }

        print("Distance: \(Int(simulatedDistance)) → position: \(normalized)")
    }


}

