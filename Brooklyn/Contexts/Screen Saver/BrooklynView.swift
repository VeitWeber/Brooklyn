//
//  BrooklynView.swift
//  Brooklyn
//
//  Created by Pedro Carrasco on 30/10/2018.
//  Copyright © 2018 Pedro Carrasco. All rights reserved.
//

import Foundation
import ScreenSaver
import AVKit

// MARK: - BrooklynView
final class BrooklynView: ScreenSaverView {

    // MARK: Local Typealias
    typealias Static = BrooklynView
    
    // MARK: Constant
    private enum Constant {
        static let backgroundColor = NSColor(red: 0.00, green: 0.01, blue: 0.00, alpha:1.0)
        // The preview in System Settings is a small thumbnail, a real screen is always larger
        static let previewMaxSize = NSSize(width: 400, height: 300)
    }
    
    // MARK: Outlets
    private let videoLayer = AVPlayerLayer()
    
    // MARK: Properties
    // Built in startAnimation() and released in stopAnimation(), so every run starts
    // with a full queue and with the settings that are saved at that moment
    private var manager: BrooklynManager?
    private lazy var preferences = PreferencesWindowController(windowNibName: PreferencesWindowController.identifier)

    // MARK: Initialization
    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        configure()
        setupNotifications()
    }
    
    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        configure()
        setupNotifications()
    }
    
    private func setupNotifications() {
        DistributedNotificationCenter.default.addObserver(
            self,
            selector: #selector(BrooklynView.willStop(_:)),
            name: Notification.Name("com.apple.screensaver.willstop"),
            object: nil
        )
    }
    
    @objc func willStop(_ aNotification: Notification) {
        // Since macOS 14 legacyScreenSaver neither stops nor releases its views, so every
        // run would leave another instance decoding video in the background. Ending the
        // host process is the established workaround, macOS starts a new host the next
        // time the screen saver runs. exit(0) cannot be vetoed or delayed, unlike terminate(_:).
        guard isFullSizeInstance else { return }
        exit(0)
    }
    
    // isPreview is not reliable under legacyScreenSaver (FB7486243: always true on some
    // releases, wrong in other ways since macOS 26), so every view larger than the
    // thumbnail in System Settings counts as the real screen saver as well.
    private var isFullSizeInstance: Bool {
        let isLargerThanPreview = bounds.width > Constant.previewMaxSize.width
            && bounds.height > Constant.previewMaxSize.height
        return !isPreview || isLargerThanPreview
    }
}

// MARK: - Lifecycle
extension BrooklynView {
    
    override func startAnimation() {
        // A duplicate call must not restart a player that is already running
        guard manager == nil else { return }
        super.startAnimation()
        let newManager = BrooklynManager(mode: .screensaver)
        manager = newManager
        videoLayer.player = newManager.player
        newManager.player.play()
    }
    
    override func stopAnimation() {
        guard let manager = manager else { return }
        manager.player.pause()
        manager.player.stop()
        videoLayer.player = nil
        self.manager = nil
        super.stopAnimation()
    }
}

// MARK: - Configuration
private extension BrooklynView {
    
    func configure() {
        defineLayer()
    }
    
    func defineLayer() {
        wantsLayer = true
        defineVideoLayer()
        layer = videoLayer
    }
}

// MARK: - Define Layers
private extension BrooklynView {

    func defineVideoLayer() {
        videoLayer.frame = bounds
        videoLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        videoLayer.needsDisplayOnBoundsChange = true
        videoLayer.contentsGravity = .resizeAspect
        videoLayer.backgroundColor = Constant.backgroundColor.cgColor
    }
}

// MARK: - Preferences
extension BrooklynView {

    override var hasConfigureSheet: Bool {
        return true
    }

    override var configureSheet: NSWindow? {
        let sheet = preferences.window
        preferences.resumePreview()
        return sheet
    }
}
