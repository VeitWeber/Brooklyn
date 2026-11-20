//
//  BrooklynManager.swift
//  Brooklyn
//
//  Created by Pedro Carrasco on 21/02/2019.
//  Copyright © 2019 Pedro Carrasco. All rights reserved.
//

import Foundation
import ScreenSaver
import AVKit
import os.log

// MARK: BrooklynManager
final class BrooklynManager {
    
    private enum Constant {
        static let versionKey = "CFBundleShortVersionString"
    }
    
    // MARK: Properties
    static let playbackRateRange: ClosedRange<Double> = 0.1...2.0
    let availableAnimations: [Animation]
    let player: LoopPlayer
    
    // MARK: Private Set Properties
    private(set) var selectedAnimations: [Animation]
    private(set) var numberOfLoops: Int
    private(set) var hasRandomOrder: Bool
    private(set) var playbackRate: Double
    
    // MARK: Init
    init(mode: DisplayMode) {
        let stored = Settings.stored
        self.availableAnimations = Animation.allCases
        self.selectedAnimations = stored.selectedAnimations
        self.numberOfLoops = stored.numberOfLoops
        self.hasRandomOrder = stored.hasRandomOrder
        self.playbackRate = stored.playbackRate
        
        switch mode {
        case .screensaver:
            self.player = LoopPlayer(items: selectedAnimations,
                                     numberOfLoops: numberOfLoops,
                                     shouldRandomize: hasRandomOrder)
        case .preferences:
            self.player = LoopPlayer(items: [selectedAnimations.first ?? .original],
                                     numberOfLoops: 0,
                                     shouldRandomize: false)
        }
        player.playbackRate = Float(playbackRate)
        Log.trace("manager for \(mode): \(stored)")
    }
    
    lazy var currentVersion: String = {
        // The bundle this class was loaded from: Brooklyn.saver, or Canvas when running from there
        let bundle = Bundle(for: BrooklynManager.self)
        return bundle.infoDictionary?[Constant.versionKey] as? String ?? ""
    }()
}

// MARK: - Animations
extension BrooklynManager {
    
    func toogle(_ animation: Animation) {
        var animations = selectedAnimations
        if animations.contains(animation) {
            animations.removeAll { $0 == animation }
        } else {
            animations.append(animation)
        }
        
        selectedAnimations = animations
        Database.standard.set(animations: selectedAnimations)
        Log.trace("stored \(settings)")
    }
}

// MARK: - Preferences
extension BrooklynManager {
    
    func setNumberOfLoops(to numberOfLoops: Int) {
        self.numberOfLoops = numberOfLoops
        Database.standard.set(numberOfLoops: numberOfLoops)
        Log.trace("stored \(settings)")
    }
    
    func toogleHasRandomOrder() {
        hasRandomOrder.toggle()
        Database.standard.set(hasRandomOrder: hasRandomOrder)
        Log.trace("stored \(settings)")
    }
    
    func setPlaybackRate(to playbackRate: Double) {
        let normalizedRate = BrooklynManager.normalized(playbackRate: playbackRate)
        // The slider reports continuously, only a new step is stored and applied
        guard normalizedRate != self.playbackRate else { return }
        self.playbackRate = normalizedRate
        Database.standard.set(playbackRate: normalizedRate)
        player.playbackRate = Float(normalizedRate)
        Log.trace("stored \(settings)")
    }
    
    // Steps of 0.1 inside the supported range, a missing or broken value means normal speed
    static func normalized(playbackRate: Double) -> Double {
        guard playbackRate.isFinite, playbackRate > 0 else { return 1.0 }
        let steppedRate = (playbackRate * 10).rounded() / 10
        return min(max(steppedRate, playbackRateRange.lowerBound), playbackRateRange.upperBound)
    }
}

// MARK: - Settings
extension BrooklynManager {
    
    // Everything the user can change in the Options sheet
    struct Settings: Equatable, CustomStringConvertible {
        let selectedAnimations: [Animation]
        let numberOfLoops: Int
        let hasRandomOrder: Bool
        let playbackRate: Double
        
        // What is stored right now
        static var stored: Settings {
            let database = Database.standard
            return Settings(selectedAnimations: database.selectedAnimations,
                            numberOfLoops: database.numberOfLoops,
                            hasRandomOrder: database.hasRandomOrder,
                            playbackRate: BrooklynManager.normalized(playbackRate: database.playbackRate))
        }
        
        // True when a running player can keep its queue and only has to change its speed
        func differsOnlyInPlaybackRate(from other: Settings) -> Bool {
            return selectedAnimations == other.selectedAnimations
                && numberOfLoops == other.numberOfLoops
                && hasRandomOrder == other.hasRandomOrder
                && playbackRate != other.playbackRate
        }
        
        var description: String {
            let names = selectedAnimations.map { $0.rawValue }.joined(separator: ",")
            return "animations=[\(names)] loops=\(numberOfLoops) random=\(hasRandomOrder) rate=\(playbackRate)"
        }
    }
    
    var settings: Settings {
        return Settings(selectedAnimations: selectedAnimations,
                        numberOfLoops: numberOfLoops,
                        hasRandomOrder: hasRandomOrder,
                        playbackRate: playbackRate)
    }
    
    // Takes over a speed that another instance stored, without writing it again
    func adopt(playbackRate: Double) {
        self.playbackRate = playbackRate
        player.playbackRate = Float(playbackRate)
    }
}

// MARK: - Log
// A few lines per run in the unified log that show which settings each process works with:
// log show --last 10m --predicate 'subsystem CONTAINS "brooklyn"'
enum Log {
    
    private static let log = OSLog(subsystem: Bundle(for: BrooklynManager.self).bundleIdentifier ?? "Brooklyn",
                                   category: "settings")
    
    static func trace(_ message: String) {
        os_log("%{public}@", log: log, type: .default, message)
    }
}
