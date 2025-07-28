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

    override func viewDidLoad() {
        super.viewDidLoad()

        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor

        let videoURL = Bundle.main.url(forResource: "video_forward", withExtension: "mp4")!
        let player = AVPlayer(url: videoURL)
        player.actionAtItemEnd = .pause
        player.play()

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


}

