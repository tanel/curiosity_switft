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
    var videoPlayer: AVPlayer?
    var killVideoPlayer: AVPlayer?
    var heartbeatSound = AudioLoop()
    var cfg = ConfigurationManager.shared
    var updateTimer: Timer?
    var introImageView: NSImageView?
    var state = GameState.waiting
    var log = Logger(subsystem: "com.example.Curiosity", category: "App")
    var distance: Double = 0
    var normalizedDistance: Double = 0
    var audioRate: Double = 0
    var audioVolume: Double = 0
    var saveActivatedAt: TimeInterval?
    
    @IBOutlet weak var distanceSlider: NSSlider!
    
    @IBOutlet weak var debugLabel: NSTextField!
    
    @IBOutlet weak var videoContainerView: NSView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Assume max distance before we start
        distance = cfg.maxDistance
        calculateNormalizedDistance()

        // Set background to black
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        
        // Load intro image
        /*
        let image = NSImage(named: "intro.jpg")!
        let imageView = NSImageView(image: image)
        imageView.frame = view.bounds
        imageView.imageScaling = .scaleAxesIndependently
        imageView.autoresizingMask = [.width, .height]
        view.addSubview(imageView, positioned: .below, relativeTo: nil)
        introImageView = imageView
         */
            

        
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
        videoPlayer = AVPlayer(url: videoURL)
        videoPlayer?.actionAtItemEnd = .pause

        // Initialize kill video player
        let killVideoURL = Bundle.main.url(forResource: "video_forward", withExtension: "mp4")!
        killVideoPlayer = AVPlayer(url: killVideoURL)
        killVideoPlayer?.actionAtItemEnd = .pause

        // Add video layer to screen
        let layer = AVPlayerLayer(player: videoPlayer)
        layer.frame = view.bounds
        layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        videoContainerView.wantsLayer = true
        videoContainerView.layer?.addSublayer(layer)
        playerLayer = layer
        
        // Start update loop
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / cfg.frameRate, repeats: true) { [weak self] _ in
            self?.update()
            self?.draw()
        }
    }
    
    func update() {
        updateDistance()
        updateState()
        updateVideo()
        updateAudio()
    }
    
    func draw() {
        // long now = ofGetElapsedTimeMillis();

        let restartCountdownSeconds: Double = 0
        if state == .statsSaved || state == .statsKilled {
            /*
            int beenDeadSeconds = (now - state.finishedAt) / 1000;
            restartCountdownSeconds = configuration.RestartIntervalSeconds - beenDeadSeconds;
             */
        }

        let autosaveCountdownSeconds: Double = 0
        if state == .started {
            /*
            int inactiveSeconds = (now - serialReader.LastUserInputAt()) / 1000;
            autosaveCountdownSeconds = configuration.AutoSaveSeconds - inactiveSeconds;
             */
        }

        var saveAllowedCountdownSeconds: Double = 0
        if state == .started && saveActivatedAt != nil {
            let now = Date().timeIntervalSince1970
            let saveActivedSeconds = now - saveActivatedAt!
            saveAllowedCountdownSeconds = cfg.saveActivateSeconds - saveActivedSeconds;
        }

        // Update HUD

        //ofSetColor(255);
        
        let isPlaying = isVideoPlaying(player: videoPlayer)
        let currentFrame = videoPlayer?.currentTime().seconds
        let destinationFrame = frameForDistance()
        let totalFrames = calculateTotalFrames(player: videoPlayer)
        
        if cfg.debugOverlay {
            debugLabel?.stringValue = """
            distance=\(distance)
            frame=\(currentFrame!)/\(totalFrames!)
            dest.f=\(destinationFrame)
            max distance=\(cfg.maxDistance)
            video=\(isPlaying)
            restart=\(restartCountdownSeconds)
            save zone=\(cfg.saveZone)
            death zone=\(cfg.deathZone)
            may save in=\(saveAllowedCountdownSeconds)
            autosave=\(autosaveCountdownSeconds)
            """
        }

        /*
            if (configuration.DebugOverlay) {
                int y = 20;
                bool isPlaying = videoPlayer.isPlaying() && !videoPlayer.isPaused();
                hudFont.drawString("distance=" + ofToString(distance), 10, y);
                hudFont.drawString("frame=" + ofToString(videoPlayer.getCurrentFrame()) + "/" + ofToString(totalNumOfFrames), 200, y);
                hudFont.drawString("dest.f=" + ofToString(frameForDistance(distance)), 400, y);
                hudFont.drawString("max distance=" + ofToString(configuration.MaxDistance), 600, y);
                hudFont.drawString("video=" + ofToString(isPlaying ? "yes" : "no"), 800, y);

                y = 40;
                hudFont.drawString("restart=" + ofToString(restartCountdownSeconds), 10, y);
                hudFont.drawString("save zone=" + ofToString(configuration.SaveZone), 200, y);
                hudFont.drawString("death zone=" + ofToString(configuration.DeathZone), 400, y);
                hudFont.drawString("may save in=" + ofToString(saveAllowedCountdownSeconds), 600, y);
                hudFont.drawString("autosave=" + ofToString(autosaveCountdownSeconds), 800, y);
            }
         */

        /*
            int margin(0);
            if (configuration.DebugOverlay) {
                margin = 50;
            }

            if (kStateStatsSaved == state.name) {
                ofSetHexColor(kColorWhite);
                ofRect(0, margin, ofGetWindowWidth(), ofGetWindowHeight() - margin);
                ofFill();
                ofSetHexColor(kColorBlack);
                numberFont.drawString(ofToString(gameStats.TotalSaves()),
                                      50,
                                      300);
                hintFont.drawString("Säästetud / Saved",
                                    50,
                                    ofGetWindowHeight() - 100);

            } else if (kStateStatsKilled == state.name) {
                ofSetHexColor(kColorWhite);
                ofRect(0, margin, ofGetWindowWidth(), ofGetWindowHeight() - margin);
                ofFill();
                ofSetHexColor(kColorBlack);
                numberFont.drawString(ofToString(gameStats.TotalKills()),
                                      50,
                                      300);
                hintFont.drawString("Hukkamisi / Kills",
                                    50,
                                    ofGetWindowHeight() - 100);

            } else if (kStateWaiting == state.name) {
                ofSetHexColor(kColorWhite);
                ofFill();
                intro.draw(0, margin, ofGetWindowWidth(), ofGetWindowHeight() - margin);

            } else if (kStateStarted == state.name || kStateSaved == state.name) {
                ofSetHexColor(kColorWhite);
                ofFill();
                videoPlayer.draw(0, margin, ofGetWindowWidth(), ofGetWindowHeight() - margin);

                // Draw overlay, for debugging
                if (configuration.DebugOverlay) {
                    ofSetHexColor(kColorBlack);
                    numberFont.drawString(ofToString(distance),
                                          100,
                                          ofGetWindowHeight() / 2);
                }

            } else if (kStateKilled == state.name) {
                ofSetHexColor(kColorWhite);
                ofFill();
                killVideoPlayer.draw(0, margin, ofGetWindowWidth(), ofGetWindowHeight() - margin);

                // Draw overlay, for debugging
                if (configuration.DebugOverlay) {
                    ofSetHexColor(kColorBlack);
                    numberFont.drawString(ofToString(distance),
                                          100,
                                          ofGetWindowHeight() / 2);
                }
                
            } else {
                throw("invalid state");
            }
            
            if (configuration.DebugOverlay) {
                ofSetHexColor(kColorBlack);
                stateFont.drawString(state.name,
                                     100,
                                     ofGetWindowHeight() / 2 + 200);
            }
        }
         */
    }
    
    func updateDistance() {
        // FIXME: read from serial if not in simulation mode
        let newDistance = cfg.maxDistance - distanceSlider.doubleValue
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
    
    /*
    let duration = player.currentItem?.duration ?? .zero
    let targetTime = CMTimeMultiplyByFloat64(duration, multiplier: Float64(normalized))
    videoPlayer.seek(to: targetTime, toleranceBefore: .zero, toleranceAfter: .zero)
     */
    
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
            let currentFrame = videoPlayer?.currentTime().seconds
            
            let destinationFrame = frameForDistance()
            if isVideoPlaying(player: videoPlayer) {
                /*
                if (videoPlayer.getSpeed() == kForward) {
                    if (currentFrame >= destinationFrame) {
                        log.info("Pausing video")
                        videoPlayer?.pause()
                    }
                } else if (videoPlayer.getSpeed() == kBack) {
                    if (currentFrame <= destinationFrame) {
                        log.info("Pausing video")
                        videoPlayer?.pause()
                    }
                }
                 */
            } else {
                /*
                if currentFrame > destinationFrame {
                    videoPlayer.setSpeed(kBack);
                    videoPlayer?.play()
                } else if (currentFrame < destinationFrame) {
                    videoPlayer.setSpeed(kForward);
                    videoPlayer?.play()
                }
                 */
                
                log.info("Playing video")
                videoPlayer?.play()
            }
        }
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
        
        let total = calculateTotalFrames(player: videoPlayer)!
        
        return mapValue(value: d, inputMin: cfg.maxDistance, inputMax: cfg.minDistance, outputMin: 0, outputMax: total)
    }
    
    // FIXME: can be precalculated, after loading video
    func calculateTotalFrames(player: AVPlayer?) -> Double? {
        return player?.currentItem?.duration.seconds
    }
    
    func calculateNormalizedDistance() {
        normalizedDistance = mapValue(value: distance, inputMin: cfg.minDistance, inputMax: cfg.maxDistance, outputMin: 0, outputMax: 1)
    }
    
    func updateAudio() {
        if state == .statsSaved || state == .statsKilled || state == .killed {
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
        
        // Adjust rate
        let newAuditoRate = mapValue(value: distance, inputMin: cfg.minDistance, inputMax: cfg.maxDistance, outputMin: cfg.finishingHeartBeatSpeed, outputMax: cfg.startingHeartBeatSpeed)
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
    
    func mapValue(value: Double, inputMin: Double, inputMax: Double, outputMin: Double, outputMax: Double) -> Double {
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
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        updateTimer?.invalidate()
    }
}
