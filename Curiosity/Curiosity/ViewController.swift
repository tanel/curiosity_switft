//
//  ViewController.swift
//  Curiosity
//
//  Created by Tanel Lebedev on 28.07.2025.
//

import Cocoa
import AVFoundation
import os

class ViewController: NSViewController {
    var playerLayer: AVPlayerLayer?
    var audioLoop = AudioLoop()
    var cfg = ConfigurationManager.shared
    var updateTimer: Timer?
    var introImageView: NSImageView?
    var state = GameState.waiting
    var log = Logger(subsystem: "com.example.Curiosity", category: "App")
    var distance: Float = 0
    
    @IBOutlet weak var distanceSlider: NSSlider!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Assume max distance before we start
        distance = cfg.maxDistance

        // Set background to black
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        
        // Load intro image
        if let image = NSImage(named: "intro.jpg") {
            let imageView = NSImageView(image: image)
            imageView.frame = view.bounds
            imageView.imageScaling = .scaleAxesIndependently
            imageView.autoresizingMask = [.width, .height]
            view.addSubview(imageView, positioned: .below, relativeTo: nil)
            introImageView = imageView
        }
        
        // Make the simulation slider more visible
        distanceSlider.wantsLayer = true
        distanceSlider.layer?.backgroundColor = NSColor.darkGray.cgColor
        distanceSlider.layer?.cornerRadius = 4
        
        // Reset slider value just in case we changed it in XCode by accident
        distanceSlider.floatValue = 0
        
        // Simulating with slider is not always enabled
        distanceSlider.isHidden = !cfg.showSimulationSlider

        // Initialize video player
        let videoURL = Bundle.main.url(forResource: "video_forward", withExtension: "mp4")!
        let player = AVPlayer(url: videoURL)
        player.actionAtItemEnd = .pause

        // Add video layer to screen
        let layer = AVPlayerLayer(player: player)
        layer.frame = view.bounds
        layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        //view.layer?.addSublayer(layer)
        playerLayer = layer

        // Audio setup
        audioLoop.setVolume(cfg.heartbeatStartVolume)
        audioLoop.setRate(cfg.heartbeatStartRate)
        audioLoop.start()
        
        // Start update loop
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / cfg.frameRate, repeats: true) { [weak self] _ in
            self?.update()
        }
    }
    
    func update() {
        updateDistance()
        updateState()
        updateVideo()
        updateAudio()
    }
    
    func updateDistance() {
        // FIXME: read from serial if not in simulation mode
        distance = cfg.maxDistance - distanceSlider.floatValue
    }
    
    func updateState() {
        switch state {
        case .waiting:
            handleWaiting()
        case .started:
            handleStarted()
        case .saved:
            handleSaved()
        case .killed:
            handleKilled()
        case .statsSaved:
            handleStatsSaved()
        case .statsKilled:
            handleStatsKilled()
        }
    }
    
    func updateVideo() {
        
    }
    
    func updateAudio() {
        
    }
    
    func handleWaiting() {
        if isInSaveZone() {
            startGame()
        }
    }
    
    func handleStarted() {
        
    }
    
    func handleSaved() {
        
    }
    
    func handleKilled() {
        
    }
    
    func handleStatsSaved() {
        
    }
    
    func handleStatsKilled() {
        
    }
    
    func isInSaveZone() -> Bool {
        return distance < cfg.maxDistance && distance >= cfg.maxDistance - cfg.saveZone
    }
    
    func startGame() {
        state = .started
        
        // FIXME: serialReader.Enable();
        
        log.info("Game started")
    }

    /*
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
     */
}
