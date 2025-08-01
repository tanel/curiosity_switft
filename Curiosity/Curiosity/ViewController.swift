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
    var heartbeatSound = AudioLoop()
    var cfg = ConfigurationManager.shared
    var updateTimer: Timer?
    var introImageView: NSImageView?
    var state = GameState.waiting
    var log = Logger(subsystem: "com.example.Curiosity", category: "App")
    var distance: Float = 0
    var normalizedDistance: Float = 0
    var audioRate: Float = 0
    var audioVolume: Float = 0
    
    @IBOutlet weak var distanceSlider: NSSlider!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Assume max distance before we start
        distance = cfg.maxDistance
        calculateNormalizedDistance()

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
        let videoPlayer = AVPlayer(url: videoURL)
        videoPlayer.actionAtItemEnd = .pause

        // Add video layer to screen
        let layer = AVPlayerLayer(player: videoPlayer)
        layer.frame = view.bounds
        layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        view.layer?.addSublayer(layer)
        playerLayer = layer

        // Audio setup
        heartbeatSound.setVolume(cfg.waitingVolume)
        heartbeatSound.setRate(cfg.heartbeatStartRate)
        heartbeatSound.start()
        
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
        let newDistance = cfg.maxDistance - distanceSlider.floatValue
        if distance != newDistance {
            calculateNormalizedDistance()
            log.info("Distance: \(newDistance), normalized distance \(self.normalizedDistance)")
        }
        
        distance = newDistance
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
        let videoPlayer = playerLayer?.player
        let isVideoPlaying = videoPlayer?.rate != 0 && videoPlayer?.error == nil

        /*
        let duration = player.currentItem?.duration ?? .zero
        let targetTime = CMTimeMultiplyByFloat64(duration, multiplier: Float64(normalized))
        videoPlayer.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
         */
        
        if state == .waiting || state == .statsKilled || state == .statsSaved {
            if isVideoPlaying {
                videoPlayer?.pause()
            }
        } else if state == .killed {
            if !isVideoPlaying {
                let fps: Float64 = 30
                let frameNumber: Int64 = 150
                let targetTime = CMTime(value: frameNumber, timescale: Int32(fps))
                videoPlayer?.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
                videoPlayer?.play()
            }
        }
/*
        } else if state == .killed {
            if !isVideoPlaying() {
                // Jump to kill part
                let targetTime = CMTime(seconds: 5.0, preferredTimescale: 600)
                videoPlayer.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                    videoPlayer.play()
                }
            }

              // Play the video in the needed direction
          } else if (kStateStarted == state.name || kStateSaved == state.name) {
              int currentFrame = videoPlayer.getCurrentFrame();
              int destinationFrame = frameForDistance(distance);
              if (videoPlayer.isPlaying() && !videoPlayer.isPaused()) {
                  if (videoPlayer.getSpeed() == kForward) {
                      if (currentFrame >= destinationFrame) {
                          videoPlayer.setPaused(true);
                      }
                  } else if (videoPlayer.getSpeed() == kBack) {
                      if (currentFrame <= destinationFrame) {
                          videoPlayer.setPaused(true);
                      }
                  }
              } else {
                  if (currentFrame > destinationFrame) {
                      videoPlayer.setSpeed(kBack);
                      videoPlayer.setPaused(false);
                  } else if (currentFrame < destinationFrame) {
                      videoPlayer.setSpeed(kForward);
                      videoPlayer.setPaused(false);
                  }
              }
              videoPlayer.update();

          } else {
              throw("invalid state");
          }
  */
    }
    
    func calculateNormalizedDistance() {
        normalizedDistance = mapValue(value: distance, inputMin: cfg.minDistance, inputMax: cfg.maxDistance, outputMin: 0, outputMax: 1)
    }
    
    func updateAudio() {
        if state == .statsSaved || state == .statsKilled || state == .killed {
            if heartbeatSound.isPlaying() {
                heartbeatSound.stop()
            }
        } else {
            if !heartbeatSound.isPlaying() {
                heartbeatSound.start()
            }
            
            // Adjust rate
            let newAuditoRate = mapValue(value: distance, inputMin: cfg.minDistance, inputMax: cfg.maxDistance, outputMin: cfg.heartbeatMaxRate, outputMax: cfg.heartbeatMinRate)
            if audioRate != newAuditoRate {
                heartbeatSound.setRate(newAuditoRate)
                log.info("Audio rate set to \(newAuditoRate)")
                audioRate = newAuditoRate
            }
            
            // Adjust volume
            var newAudioVolume = mapValue(value: distance, inputMin: cfg.minDistance, inputMax: cfg.maxDistance, outputMin: cfg.finishingVolume, outputMax: cfg.startingVolume)
            if state == .waiting {
                newAudioVolume = cfg.waitingVolume
            }
            
            if audioVolume != newAudioVolume {
                heartbeatSound.setVolume(newAudioVolume)
                log.info("Audio volume set to \(newAudioVolume)")
                audioVolume = newAudioVolume
            }
        }
    }
    
    func mapValue(value: Float, inputMin: Float, inputMax: Float, outputMin: Float, outputMax: Float) -> Float {
        if inputMin == inputMax { return outputMin }
        let normalized = (value - inputMin) / (inputMax - inputMin)
        return outputMin + normalized * (outputMax - outputMin)
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
}
