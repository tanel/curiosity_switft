//
//  SerialReader.swift
//  Curiosity
//
//  Created by Tanel Lebedev on 04.08.2025.
//

import Foundation
import ORSSerial

class SerialReader: NSObject, ORSSerialPortDelegate {
    var serialPort: ORSSerialPort?
    var lastReceivedLine: String?
    var latestValue: Int = 0
    var state: String = "Stopped"
    
    // Keep track of how often do we actually read from the sensor
    private var receivedCount = 0
    private var lastCountResetTime = Date()
    private(set) var readingsPerSecond = 0

    
    private var useMovingAverageFilter: Bool = false
    private var movingAverage = MovingAverageFilter(size: 10)

    func start(path: String, useMovingAverage: Bool, baudRate: Int = 9600) {
        guard let port = ORSSerialPort(path: path) else {
            print("Invalid port path")
            return
        }
        port.baudRate = NSNumber(value: baudRate)
        port.delegate = self
        port.open()
        serialPort = port
        useMovingAverageFilter = useMovingAverage
    }

    func stop() {
        serialPort?.close()
    }
    
    var isConnected: Bool {
        return serialPort?.isOpen ?? false
    }

    // MARK: - ORSSerialPortDelegate

    func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
        receivedCount += 1
        let now = Date()
        if now.timeIntervalSince(lastCountResetTime) >= 1.0 {
            readingsPerSecond = receivedCount
            receivedCount = 0
            lastCountResetTime = now
        }

        if let line = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            let value = Int(line) {

            let finalValue = useMovingAverageFilter ? movingAverage.add(value) : value

            latestValue = finalValue
            lastReceivedLine = line
        }
    }

    func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) {
        print("Port was removed")
        state = "Removed"
        stop()
    }

    func serialPortWasClosed(_ serialPort: ORSSerialPort) {
        print("Port closed")
        state = "Closed"
    }

    func serialPortWasOpened(_ serialPort: ORSSerialPort) {
        print("Port opened")
        state = "Opened"
    }

    func serialPort(_ serialPort: ORSSerialPort, didEncounterError error: Error) {
        print("Serial port error: \(error)")
        state = error.localizedDescription
    }
}
