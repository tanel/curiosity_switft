//
//  MovingAverageFilter.swift
//  Curiosity
//
//  Created by Tanel Lebedev on 05.08.2025.
//

struct MovingAverageFilter {
    private var values: [Int] = []
    private let size: Int

    init(size: Int) {
        self.size = size
    }

    mutating func add(_ value: Int) -> Int {
        values.append(value)
        if values.count > size {
            values.removeFirst()
        }
        return average
    }

    var average: Int {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / values.count
    }
}
