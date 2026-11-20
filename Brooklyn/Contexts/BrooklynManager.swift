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
        self.availableAnimations = Animation.allCases
        self.selectedAnimations = Database.standard.selectedAnimations
        self.numberOfLoops = Database.standard.numberOfLoops
        self.hasRandomOrder = Database.standard.hasRandomOrder
        self.playbackRate = BrooklynManager.normalized(playbackRate: Database.standard.playbackRate)
        
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
    }
}

// MARK: - Preferences
extension BrooklynManager {
    
    func setNumberOfLoops(to numberOfLoops: Int) {
        self.numberOfLoops = numberOfLoops
        Database.standard.set(numberOfLoops: numberOfLoops)
    }
    
    func toogleHasRandomOrder() {
        hasRandomOrder.toggle()
        Database.standard.set(hasRandomOrder: hasRandomOrder)
    }
    
    func setPlaybackRate(to playbackRate: Double) {
        let normalizedRate = BrooklynManager.normalized(playbackRate: playbackRate)
        // The slider reports continuously, only a new step is stored and applied
        guard normalizedRate != self.playbackRate else { return }
        self.playbackRate = normalizedRate
        Database.standard.set(playbackRate: normalizedRate)
        player.playbackRate = Float(normalizedRate)
    }
    
    // Steps of 0.1 inside the supported range, a missing or broken value means normal speed
    static func normalized(playbackRate: Double) -> Double {
        guard playbackRate.isFinite, playbackRate > 0 else { return 1.0 }
        let steppedRate = (playbackRate * 10).rounded() / 10
        return min(max(steppedRate, playbackRateRange.lowerBound), playbackRateRange.upperBound)
    }
}
