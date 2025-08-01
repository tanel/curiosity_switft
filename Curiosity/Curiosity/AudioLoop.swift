//
//  AudioLoop.swift
//  Curiosity
//
//  Created by Tanel Lebedev on 28.07.2025.
//

import Foundation
import AVFoundation

class AudioLoop {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let timePitch = AVAudioUnitTimePitch()
    private var audioFile: AVAudioFile?
    
    init() {
        setupAudio()
    }

    private func setupAudio() {
        guard let url = Bundle.main.url(forResource: "loop", withExtension: "mp3") else {
            print("loop.mp3 not found")
            return
        }

        do {
            audioFile = try AVAudioFile(forReading: url)
        } catch {
            print("Failed to load loop.mp3: \(error)")
            return
        }

        engine.attach(player)
        engine.attach(timePitch)
        engine.connect(player, to: timePitch, format: nil)
        engine.connect(timePitch, to: engine.mainMixerNode, format: nil)

        try? engine.start()
    }

    func start() {
        guard let audioFile else { return }
        player.scheduleFile(audioFile, at: nil, completionHandler: loopAgain)
        player.play()
    }

    private func loopAgain() {
        DispatchQueue.main.async {
            self.start()
        }
    }

    func stop() {
        player.stop()
    }
    
    func isPlaying() -> Bool {
        return player.isPlaying
    }

    func setRate(_ rate: Double) {
        timePitch.rate = Float(rate)
    }

    func setVolume(_ volume: Double) {
        player.volume = Float(volume)
    }
}
