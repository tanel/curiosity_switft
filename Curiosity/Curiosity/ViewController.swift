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
    // Configuration
    var cfg = ConfigurationManager.shared

    // Logger
    var log = Logger(subsystem: "com.example.Curiosity", category: "App")

    // UI components
    var videoPlayer: AVPlayer?
    var videoPlayerLayer: AVPlayerLayer?
    var killVideoPlayer: AVPlayer?
    var killVideoPlayerLayer: AVPlayerLayer?
    var heartbeatSound = AudioLoop()
    var updateTimer: Timer?
    var introImageView: NSImageView?
    
    // Game state
    var state = GameState.loading
    var distance: Double = 0
    var normalizedDistance: Double = 0
    var audioRate: Double = 0
    var audioVolume: Double = 0
    var saveActivatedAt: TimeInterval?
    var lastUserInputAt: TimeInterval?
    var finishedAt: TimeInterval?
    var totalSaves: Int = 0
    var totalKills: Int = 0
    var totalFrames: Double = 0
    
    // Connected UI components
    @IBOutlet weak var distanceSlider: NSSlider!
    @IBOutlet weak var debugLabel: NSTextField!
    @IBOutlet weak var videoContainerView: NSView!
    @IBOutlet weak var numberLabel: NSTextField!
    @IBOutlet weak var hintLabel: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Assume max distance before we start
        distance = cfg.maxDistance
        calculateNormalizedDistance()

        // Set background to black
        view.wantsLayer = true
        
        // Load intro image
        let image = NSImage(named: "intro.jpg")!
        let imageView = NSImageView(image: image)
        imageView.frame = view.bounds
        imageView.imageScaling = .scaleAxesIndependently
        imageView.autoresizingMask = [.width, .height]
        view.addSubview(imageView, positioned: .below, relativeTo: nil)
        introImageView = imageView
        introImageView?.isHidden = true
            
        // Make the simulation slider more visible
        distanceSlider.wantsLayer = true
        distanceSlider.layer?.backgroundColor = NSColor.darkGray.cgColor
        distanceSlider.layer?.cornerRadius = 4
        
        // Reset slider value just in case we changed it in XCode by accident
        distanceSlider.floatValue = 0
        
        // Show simulation slider, if needed
        distanceSlider.isHidden = !cfg.showSimulationSlider
        
        // Show debug label, if needed
        debugLabel.isHidden = !cfg.debugOverlay

        // Initialize video player
        let videoURL = Bundle.main.url(forResource: "video_forward", withExtension: "mp4")!
        videoPlayer = AVPlayer(url: videoURL)
        videoPlayer?.actionAtItemEnd = .pause
        videoPlayer?.volume = Float(cfg.finishingVolume)
        videoPlayer?.currentItem?.addObserver(self, forKeyPath: "status", options: .new, context: nil)

        // Add video layer to screen
        videoPlayerLayer = AVPlayerLayer(player: videoPlayer)
        videoPlayerLayer?.frame = view.bounds
        videoPlayerLayer?.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        videoContainerView.wantsLayer = true
        videoContainerView.layer?.addSublayer(videoPlayerLayer!)
        videoPlayerLayer?.isHidden = true
        
        // Initialize kill video player
        let killVideoURL = Bundle.main.url(forResource: "video_forward", withExtension: "mp4")!
        killVideoPlayer = AVPlayer(url: killVideoURL)
        killVideoPlayer?.actionAtItemEnd = .pause
        killVideoPlayer?.volume = Float(cfg.finishingVolume)
        
        // Add kill video layer to screen
        killVideoPlayerLayer = AVPlayerLayer(player: killVideoPlayer)
        killVideoPlayerLayer?.frame = view.bounds
        killVideoPlayerLayer?.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        videoContainerView.wantsLayer = true
        videoContainerView.layer?.addSublayer(killVideoPlayerLayer!)
        killVideoPlayerLayer?.isHidden = true

        
        // Start update loop
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / cfg.frameRate, repeats: true) { [weak self] _ in
            self?.update()
            self?.draw()
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard keyPath == "status", let item = object as? AVPlayerItem else { return }

        switch item.status {
        case .readyToPlay:
            let totalSeconds = videoPlayer?.currentItem?.duration.seconds
            self.totalFrames = round2(value: totalSeconds!)
            restartGame()
        case .failed:
            print("Video failed to load: \(String(describing: item.error))")
        default:
            break
        }
    }
    
    func isInSaveZone() -> Bool {
        return distance >= cfg.maxDistance - cfg.saveZone && distance < cfg.maxDistance
    }
    
    func isInKillZone() -> Bool {
        return distance < cfg.minDistance + cfg.deathZone
    }
    
    func update() {
        if state == .loading {
            return
        }
        
        let now = Date().timeIntervalSince1970
        
        // Update distance
        // FIXME: read from serial if not in simulation mode
        let newDistance = cfg.maxDistance - distanceSlider.doubleValue
        if distance != newDistance {
            calculateNormalizedDistance()
        }
        
        distance = newDistance
        
        // Update state
        if state == .waiting {
            // If user finds itself *in* the save zone, we start the game.
            if isInSaveZone() {
                startGame()
            }
            
        } else if state == .started {
            
            // Determine if user is now in the death zone
            if isInKillZone() {
                killGame()

            // If save zone is active and user finds itself in it, then declare the game saved and finish it.
           } else if saveActivatedAt != nil && distance > cfg.maxDistance - cfg.saveZone && saveActivatedAt! + cfg.saveActivateSeconds < now {
               saveGame()

           // If user has moved out of save zone, and game is not finished yet, activate save zone
           } else if saveActivatedAt == nil && distance < cfg.maxDistance - cfg.saveZone {
               saveActivatedAt = now

           // If we have no new input for N seconds, consider the game as saved, as it seems that the user has left the building
           } else if lastUserInputAt != nil && lastUserInputAt! < now - cfg.autoSaveSeconds {
               saveGame()
           }
            
        } else if state == .statsKilled || state == .statsSaved {
            if finishedAt != nil && finishedAt! < now - cfg.restartIntervalSeconds {
                restartGame()
            }
            
        } else if state == .saved {
            let destinationFrame = frameForDistance()
            let currentFrame = calculateCurrentFrame()
            if destinationFrame == currentFrame {
                showStats()
            }
            
        } else if state == .killed {
            if !isVideoPlaying(player: killVideoPlayer) {
                showStats()
            }
            
        }
        
        // Update media
        updateVideo()
        updateAudio()
    }
    
    func showStats() {
        // FIXME: disable serial

        if state == .killed {
            state = .statsKilled
        } else if state == .saved {
            state = .statsSaved
        }
        
        finishedAt = Date().timeIntervalSince1970
        log.info("Showing stats")
    }
    
    func startGame() {
        state = .started
        log.info("Game started")
    }
    
    func killGame() {
        state = .killed
        totalKills += 1
        log.info("Game finished with kill")
    }
    
    func saveGame() {
        state = .saved
        totalSaves += 1
        log.info("Game finished with save")
    }
    
    func restartGame() {
        // FIXME: reset serial
        videoPlayer?.seek(to: .zero)
        distanceSlider.doubleValue = 0
        distance = 0
        normalizedDistance = 0
        state = .waiting
        log.info("Game restarted")
    }
    
    func draw() {
        if state == .loading {
            return
        }
        
        let now = Date().timeIntervalSince1970

        var restartCountdownSeconds: Double = 0
        if (state == .statsSaved || state == .statsKilled) && finishedAt != nil {
            let beenDeadSeconds = now - finishedAt!
            restartCountdownSeconds = cfg.restartIntervalSeconds - beenDeadSeconds
        }

        var autosaveCountdownSeconds: Double = 0
        if state == .started && lastUserInputAt != nil {
            let inactiveSeconds = now - lastUserInputAt!
            autosaveCountdownSeconds = cfg.autoSaveSeconds - inactiveSeconds
        }

        var saveAllowedCountdownSeconds: Double = 0
        if state == .started && saveActivatedAt != nil {
            let saveActivedSeconds = now - saveActivatedAt!
            saveAllowedCountdownSeconds = cfg.saveActivateSeconds - saveActivedSeconds;
        }

        // Update HUD

        let isPlaying = isVideoPlaying(player: videoPlayer)
        let currentFrame = calculateCurrentFrame()
        let destinationFrame = frameForDistance()
        let inKillZone = isInKillZone()
        let inSaveZone = isInSaveZone()
        let isKillVideoPlaying = isVideoPlaying(player: killVideoPlayer)
        
        if cfg.debugOverlay {
            debugLabel?.stringValue = """
            state=\(state)
            distance=\(distance)
            in save zone=\(inSaveZone)
            in kill zone=\(inKillZone)
            current frame=\(currentFrame)/\(self.totalFrames)
            dest.f=\(destinationFrame)
            audio volume=\(audioVolume)
            is video playing=\(isPlaying)
            is kill video playing=\(isKillVideoPlaying)
            restart countdown=\(restartCountdownSeconds) s
            save countdown=\(saveAllowedCountdownSeconds) s
            autosave countdown=\(autosaveCountdownSeconds) s
            """
        }

        // FIXME: no reason to draw these things each time, check first, if needed (except for numeric values, maybe)
        
        if state == .statsSaved {
            setBackgroundToBlack()
            videoContainerView.isHidden = true
            numberLabel?.stringValue = String(totalSaves)
            hintLabel?.stringValue = "Säästetud / Saved"

        } else if state == .statsKilled {
            setBackgroundToWhite()
            videoContainerView.isHidden = true
            numberLabel.stringValue = String(totalKills)
            hintLabel.stringValue = "Hukkamisi / Kills"

        } else if state == .waiting {
            setBackgroundToWhite()
            videoContainerView.isHidden = true
            introImageView?.isHidden = false

        } else if state == .started || state == .saved {
            setBackgroundToWhite()
            introImageView?.isHidden = true
            videoContainerView.isHidden = false
            killVideoPlayerLayer?.isHidden = true
            videoPlayerLayer?.isHidden = false

        } else if state == .killed {
            setBackgroundToWhite()
            videoContainerView.isHidden = false
            killVideoPlayerLayer?.isHidden = false
        }
    }
        
    func isVideoPlaying(player: AVPlayer?) -> Bool {
        return player?.rate != 0 && player?.error == nil
    }
    
    func updateVideo() {
        // stop video if it should not be playing
        if state == .waiting || state == .killed || state == .statsKilled || state == .statsSaved {
            if isVideoPlaying(player: videoPlayer) {
                log.info("Pausing video")
                videoPlayer?.pause()
            }
            
            if state == .killed {
                if !isVideoPlaying(player:killVideoPlayer) {
                    log.info("Playing kill video")
                    killVideoPlayer?.play();
                }
            }
            
            return
        }

        // Play the video in the needed direction
        if state == .started || state == .saved {
            let currentFrame = calculateCurrentFrame()
            
            let destinationFrame = frameForDistance()
            if isVideoPlaying(player: videoPlayer) {
                if videoPlayer?.rate == 1 {
                    if currentFrame >= destinationFrame {
                        videoPlayer?.pause()
                    }
                } else if videoPlayer?.rate == -1 {
                    if currentFrame <= destinationFrame {
                        videoPlayer?.pause()
                    }
                }
            } else {
                if currentFrame > destinationFrame {
                    videoPlayer?.playImmediately(atRate: -1)
                } else if currentFrame < destinationFrame {
                    videoPlayer?.playImmediately(atRate: 1)
                }
            }
        }
    }
    
    func calculateCurrentFrame() -> Double {
        let seconds = videoPlayer?.currentTime().seconds
        return round2(value: seconds!)
    }
    
    func round2(value: Double) -> Double {
        return Double(round(100 * value) / 100)
    }
    
    // Frame for current distance
    // Note that this is not the actual frame that will be animated.
    // Instead will start to animate towards this frame.
    func frameForDistance() -> Double {
        var d: Double = 0
        // Override dest. frame on certain conditions, like kill, save, waiting etc
        if state == .killed || state == .statsKilled {
            d = cfg.minDistance
        } else if state == .saved || state == .statsSaved {
            d = cfg.maxDistance
        } else if state == .waiting || state == .started {
            d = distance;
        }
        
        let mapped = mapValue(value: d, inputMin: cfg.maxDistance, inputMax: cfg.minDistance, outputMin: 0, outputMax: totalFrames)
        return round2(value: mapped)
    }
    
    func calculateNormalizedDistance() {
        normalizedDistance = mapValue(value: distance, inputMin: cfg.minDistance, inputMax: cfg.maxDistance, outputMin: 0, outputMax: 1)
    }
    
    func updateAudio() {
        // Adjust rate
        let newAuditoRate = mapValue(value: distance, inputMin: cfg.minDistance, inputMax: cfg.maxDistance, outputMin: cfg.finishingHeartBeatSpeed, outputMax: cfg.startingHeartBeatSpeed)
        if audioRate != newAuditoRate {
            heartbeatSound.setRate(newAuditoRate)
            audioRate = newAuditoRate
        }
        
        // Adjust volume
        var newAudioVolume = mapValue(value: distance, inputMin: cfg.minDistance, inputMax: cfg.maxDistance, outputMin: cfg.finishingVolume, outputMax: cfg.startingVolume)
        if state == .waiting {
            newAudioVolume = cfg.waitingVolume
        }
        
        if audioVolume != newAudioVolume {
            heartbeatSound.setVolume(newAudioVolume)
            audioVolume = newAudioVolume
        }

        if state == .statsSaved || state == .statsKilled || state == .killed || state == .waiting {
            if heartbeatSound.isPlaying() {
                log.info( "Stopping heartbeat sound")
                heartbeatSound.stop()
            }
            
            return
        }
        
        if !heartbeatSound.isPlaying() {
            log.info("Starting heartbeat sound")
            heartbeatSound.start()
        }
    }
    
    func mapValue(value: Double, inputMin: Double, inputMax: Double, outputMin: Double, outputMax: Double) -> Double {
        if inputMin == inputMax { return outputMin }
        let normalized = (value - inputMin) / (inputMax - inputMin)
        return outputMin + normalized * (outputMax - outputMin)
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        updateTimer?.invalidate()
    }
    
    func setBackgroundToBlack() {
        view.layer?.backgroundColor = NSColor.black.cgColor
    }
    
    func setBackgroundToWhite() {
        view.layer?.backgroundColor = NSColor.white.cgColor
    }
}
