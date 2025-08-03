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
    var heartbeatSound = AudioLoop()
    var updateTimer: Timer?
    var introImageView: NSImageView?
    
    // Pre-calculated values, based on video length
    var totalFrames: Double = 0
    var killFrame: Double = 0
    var killVideoStartsAt: CMTime?
    
    // Active audio rate and volume
    var audioRate: Double = 0
    var audioVolume: Double = 0
    
    // Game state
    var state = GameState.loading
    
    // Active distance reading
    var distance: Double = 0
    
    // Active distance reading mapped to 0-1 scale
    var normalizedDistance: Double = 0
    
    // Timestamps related to game state
    var saveZoneActivatedAt: TimeInterval?
    var lastUserInputAt: TimeInterval?
    var finishedAt: TimeInterval?
    
    // Stats
    var totalSaves: Int = 0
    var totalKills: Int = 0
    
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
        
        // Configure distance slider
        if cfg.showSimulationSlider {
            // Make the simulation slider more visible
            distanceSlider.wantsLayer = true
            distanceSlider.layer?.backgroundColor = NSColor.darkGray.cgColor
            distanceSlider.layer?.cornerRadius = 4
            
            // Reset slider value just in case we changed it in XCode by accident
            distanceSlider.floatValue = 0
            
            // Show simulation slider, if needed
            distanceSlider.isHidden = false
            view.addSubview(distanceSlider, positioned: .above, relativeTo: nil)
        } else {
            distanceSlider.isHidden = true
        }
        
        // Show debug label, if needed
        if cfg.debugOverlay {
            debugLabel.isHidden = false
            view.addSubview(debugLabel, positioned: .above, relativeTo: nil)
        } else {
            debugLabel.isHidden = true
        }

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
        videoContainerView.autoresizingMask = [.width, .height]
        videoContainerView.layer?.addSublayer(videoPlayerLayer!)
        videoPlayerLayer?.isHidden = true
        
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
            
            self.killFrame = round2(value: mapValue(value: cfg.deathZone, inputMin: cfg.minDistance, inputMax: cfg.maxDistance, outputMin: totalSeconds!, outputMax: 0))
            self.killVideoStartsAt = CMTime(seconds: self.killFrame, preferredTimescale: 600)
            
            changeStateToWaiting()
        case .failed:
            print("Video failed to load: \(String(describing: item.error))")
        default:
            break
        }
    }
    
    func isInSaveZone() -> Bool {
        return distance > cfg.maxDistance - cfg.saveZone && distance < cfg.maxDistance
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
            // Walking into save zone will start the game.
            if isInSaveZone() {
                changeStateToStarted()
            }
            
        } else if state == .started {
            // Walking into kill zone will end the game with KILL.
            if isInKillZone() {
                changeStateToKilled()

            // Walking into save zone again, after if its been activated, will end the game with SAVE.
           } else if saveZoneActivatedAt != nil && isInSaveZone() && saveZoneActivatedAt! + cfg.saveActivateSeconds < now {
               changeStateToSaved()

           // If user has moved out of save zone, and game is not finished yet, activate save zone
           } else if saveZoneActivatedAt == nil && !isInSaveZone() {
               saveZoneActivatedAt = now

           // If we have no new input for N seconds, consider the game as saved, as it seems that the user has left the building
           } else if lastUserInputAt != nil && lastUserInputAt! < now - cfg.autoSaveSeconds {
               changeStateToSaved()
           }
            
        } else if state == .statsKilled || state == .statsSaved {
            if finishedAt != nil && finishedAt! < now - cfg.restartIntervalSeconds {
                changeStateToWaiting()
            }
            
        } else if state == .saved {
            let destinationFrame = frameForDistance()
            let currentFrame = calculateCurrentFrame()
            if destinationFrame == currentFrame {
                showStatsSaved()
            }
            
        } else if state == .killed {
            // if we're killed and video has finished, switch to showing stats
            if !isVideoPlaying(player: videoPlayer) {
                showStatsKilled()
            }
            
        }
        
        // Update media
        updateVideo()
        updateAudio()
    }
    
    func showStatsSaved() {
        // FIXME: disable serial

        state = .statsSaved
        
        setBackgroundToWhite()
        
        videoPlayer?.pause()
        videoPlayerLayer?.isHidden = true
        
        numberLabel.stringValue = String(totalSaves)
        hintLabel.stringValue = "Säästetud / Saved"

        numberLabel.isHidden = false
        hintLabel.isHidden = false

        finishedAt = Date().timeIntervalSince1970
        log.info("Showing stats")
    }
    
    func showStatsKilled() {
        // FIXME: disable serial

        state = .statsKilled
        
        videoPlayer?.pause()
        videoPlayerLayer?.isHidden = true

        setBackgroundToWhite()

        numberLabel.stringValue = String(totalKills)
        hintLabel.stringValue = "Hukkamisi / Kills"

        numberLabel.isHidden = false
        hintLabel.isHidden = false
        
        finishedAt = Date().timeIntervalSince1970
        log.info("Showing stats killed")
    }

    func changeStateToStarted() {
        startHeartBeat()
        
        setBackgroundToWhite()
        
        introImageView?.isHidden = true
        
        numberLabel.isHidden = true
        hintLabel.isHidden = true
        
        videoPlayerLayer?.isHidden = false
        
        state = .started
        log.info("Game started")
    }
    
    func changeStateToKilled() {
        stopHeartBeat()
        
        totalKills += 1
        
        videoPlayer?.seek(to: self.killVideoStartsAt!, toleranceBefore: .zero, toleranceAfter: .zero)
        
        state = .killed
        log.info("Game killed")
    }
    
    func changeStateToSaved() {
        totalSaves += 1

        state = .saved

        log.info("Game saved")
    }
    
    func changeStateToWaiting() {
        // FIXME: reset serial
        
        videoPlayerLayer?.isHidden = true
        videoPlayer?.pause()
        videoPlayer?.seek(to: .zero)

        stopHeartBeat()
        
        numberLabel.isHidden = true
        hintLabel.isHidden = true

        introImageView?.isHidden = false
        
        distanceSlider.doubleValue = 0
        distance = 0
        normalizedDistance = 0
        
        setBackgroundToWhite()
        
        saveZoneActivatedAt = nil
        finishedAt = nil
        
        state = .waiting
        log.info("Game waiting")
    }
    
    func startHeartBeat() {
        log.info("starting heartbeat sound")
        heartbeatSound.start()
    }
    
    func stopHeartBeat() {
        log.info("stopping heartbeat sound")
        heartbeatSound.stop()
    }
    
    func draw() {
        if !cfg.debugOverlay {
            return
        }

        let now = Date().timeIntervalSince1970
            
        var restartCountdownSeconds: Double = 0
        if (state == .statsSaved || state == .statsKilled) && finishedAt != nil {
            let beenDeadSeconds = now - finishedAt!
            restartCountdownSeconds = round2(value: cfg.restartIntervalSeconds - beenDeadSeconds)
        }

        var autosaveCountdownSeconds: Double = 0
        if state == .started && lastUserInputAt != nil {
            let inactiveSeconds = now - lastUserInputAt!
            autosaveCountdownSeconds = round2(value: cfg.autoSaveSeconds - inactiveSeconds)
        }

        var saveAllowedCountdownSeconds: Double = 0
        if state == .started && saveZoneActivatedAt != nil {
            let saveActivedSeconds = now - saveZoneActivatedAt!
            saveAllowedCountdownSeconds = round2(value: cfg.saveActivateSeconds - saveActivedSeconds)
        }

        let isPlaying = isVideoPlaying(player: videoPlayer)
        let currentFrame = calculateCurrentFrame()
        let destinationFrame = frameForDistance()
        let inKillZone = isInKillZone()
        let inSaveZone = isInSaveZone()
        
        var formattedSaveZoneActivatedAt: String = ""
        if let saveZoneActivatedAt = saveZoneActivatedAt {
            formattedSaveZoneActivatedAt = DateFormatter.localizedString(from: Date(timeIntervalSince1970: saveZoneActivatedAt), dateStyle: .none, timeStyle: .short)
        }
        
        var formattedFinishedAt: String = ""
        if let finishedAt = finishedAt {
            formattedFinishedAt = DateFormatter.localizedString(from: Date(timeIntervalSince1970: finishedAt), dateStyle: .none, timeStyle: .short)
        }
        
        let roundAudioVolume = round2(value: audioVolume)
        let roundDistance = round2(value: distance)
    
        debugLabel?.stringValue = """
        state=\(state)
        total kills=\(totalKills) saves=\(totalSaves)
        distance=\(roundDistance)
        save zone=\(cfg.maxDistance) - \(cfg.maxDistance - cfg.saveZone), \(inSaveZone)
        kill zone=\(cfg.minDistance + cfg.deathZone) - \(cfg.minDistance), \(inKillZone)
        current frame=\(currentFrame)
        destination frame=\(destinationFrame)
        total frames=\(self.totalFrames)
        kill frame=\(self.killFrame)
        audio volume=\(roundAudioVolume)
        is video playing=\(isPlaying)
        saveZoneActivatedAt=\(formattedSaveZoneActivatedAt) 
        finishedAt=\(formattedFinishedAt)
        restart in=\(restartCountdownSeconds)s
        save allowed in=\(saveAllowedCountdownSeconds)s
        autosave in=\(autosaveCountdownSeconds)s
        """
    }
        
    func isVideoPlaying(player: AVPlayer?) -> Bool {
        return player?.rate != 0 && player?.error == nil
    }
    
    func updateVideo() {
        if state != .started && state != .saved {
            return
        }

        let currentFrame = calculateCurrentFrame()
        let destinationFrame = frameForDistance()

        // Pause video if needed
        if isVideoPlaying(player: videoPlayer) {
            if videoPlayer?.rate == 1 { // is playing forward
                if currentFrame >= destinationFrame {
                    videoPlayer?.pause()
                }
            } else if videoPlayer?.rate == -1 { // is playing backward
                if currentFrame <= destinationFrame {
                    videoPlayer?.pause()
                }
            }
            
            return
        }
        
        // Start video if needed
        if currentFrame > destinationFrame {
            videoPlayer?.playImmediately(atRate: -1) // play backward
        } else if currentFrame < destinationFrame {
            videoPlayer?.playImmediately(atRate: 1) // play forward
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
        log.info("setting background to black")
        view.layer?.backgroundColor = NSColor.black.cgColor
    }
    
    func setBackgroundToWhite() {
        log.info( "setting background to white")
        view.layer?.backgroundColor = NSColor.white.cgColor
    }
}
