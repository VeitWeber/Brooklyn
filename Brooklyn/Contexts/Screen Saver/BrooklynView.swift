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
import os.log

// MARK: - BrooklynView
final class BrooklynView: ScreenSaverView {

    // MARK: Local Typealias
    typealias Static = BrooklynView
    
    // MARK: Constant
    private enum Constant {
        static let backgroundColor = NSColor(red: 0.00, green: 0.01, blue: 0.00, alpha:1.0)
        // The preview in System Settings is a small thumbnail, a real screen is always larger
        static let previewMaxSize = NSSize(width: 400, height: 300)
        // How often animateOneFrame() re-checks the video layout
        static let layoutCheckInterval: TimeInterval = 0.5
        // How often a running view looks for changed options
        static let settingsCheckInterval: TimeInterval = 1.0
    }
    
    // MARK: Outlets
    private let videoLayer = AVPlayerLayer()
    
    // MARK: Properties
    // Built in startAnimation() and released in stopAnimation(), so every run starts
    // with a full queue and with the settings that are saved at that moment
    private var manager: BrooklynManager?
    private var settingsTimer: Timer?
    // What layoutVideoLayer() applied last, to skip unchanged layouts
    private var appliedVideoFrame = NSRect.null
    private var appliedContentsScale: CGFloat = 0
    private static let log = OSLog(subsystem: Bundle(for: BrooklynView.self).bundleIdentifier ?? "Brooklyn",
                                   category: "view")
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
        // A host that stays alive also keeps the code and the settings it started with, so
        // options changed in System Settings only reach the screen saver in a new host.
        guard Static.hostsPreview && Static.isSystemSettingsRunning else {
            trace("willStop: ending the host process")
            exit(0)
        }
        // This host shows the thumbnail in System Settings and owns the Options sheet. Ending it
        // can leave the Options button dead until System Settings is relaunched, so it only
        // stops playing on its full-size views.
        trace("willStop: this host shows the preview, keeping it")
        if isLargerThanPreview {
            stopAnimation()
        }
    }
    
    // Set once a view of this process is shown at thumbnail size. System Settings runs its
    // preview in a host of its own, the host of the real screen saver only has full-size views.
    private static var hostsPreview = false
    
    // The thumbnail in System Settings keeps playing, everything larger is a full screen.
    // This goes by size because isPreview is not reliable under legacyScreenSaver (FB7486243).
    private var isLargerThanPreview: Bool {
        let size = videoFrame.size
        return size.width > Constant.previewMaxSize.width && size.height > Constant.previewMaxSize.height
    }
    
    private static var isSystemSettingsRunning: Bool {
        let identifiers = ["com.apple.systempreferences", "com.apple.Preferences"]
        return NSWorkspace.shared.runningApplications.contains { application in
            guard let identifier = application.bundleIdentifier else { return false }
            return identifiers.contains(identifier)
        }
    }
}

// MARK: - Lifecycle
extension BrooklynView {
    
    override func startAnimation() {
        // A duplicate call must not restart a player that is already running
        guard manager == nil else {
            applyStoredSettings()
            return
        }
        super.startAnimation()
        trace("startAnimation")
        buildPlayer()
        startSettingsTimer()
    }
    
    override func stopAnimation() {
        guard let manager = manager else { return }
        trace("stopAnimation")
        settingsTimer?.invalidate()
        settingsTimer = nil
        manager.player.pause()
        manager.player.stop()
        videoLayer.player = nil
        self.manager = nil
        super.stopAnimation()
    }
}

// MARK: - Settings
private extension BrooklynView {
    
    func buildPlayer() {
        let newManager = BrooklynManager(mode: .screensaver)
        manager = newManager
        videoLayer.player = newManager.player
        layoutVideoLayer()
        newManager.player.play()
    }
    
    func startSettingsTimer() {
        settingsTimer?.invalidate()
        let timer = Timer(timeInterval: Constant.settingsCheckInterval, repeats: true) { [weak self] _ in
            self?.applyStoredSettings()
        }
        // Common modes, so it also fires while a sheet or a menu is tracking events
        RunLoop.main.add(timer, forMode: .common)
        settingsTimer = timer
    }
    
    // The Options sheet belongs to another view, usually in another process, and the host does not
    // restart running views when it closes. Checking the stored settings makes changes apply at once.
    func applyStoredSettings() {
        guard let manager = manager else { return }
        let stored = BrooklynManager.Settings.stored
        let current = manager.settings
        guard stored != current else { return }
        trace("settings changed: \(stored)")
        if stored.differsOnlyInPlaybackRate(from: current) {
            manager.adopt(playbackRate: stored.playbackRate)
        } else {
            manager.player.pause()
            manager.player.stop()
            buildPlayer()
        }
    }
}

// MARK: - Configuration
private extension BrooklynView {
    
    func configure() {
        defineLayer()
        // animateOneFrame() is only used to re-check the layout
        animationTimeInterval = Constant.layoutCheckInterval
    }
    
    func defineLayer() {
        // Layer-hosting view: AppKit keeps the root layer in sync with the view, the video is a
        // sublayer that layoutVideoLayer() places, independent of the frame the view was created with
        let rootLayer = CALayer()
        rootLayer.backgroundColor = Constant.backgroundColor.cgColor
        layer = rootLayer
        wantsLayer = true
        defineVideoLayer()
        rootLayer.addSublayer(videoLayer)
        layoutVideoLayer()
    }
}

// MARK: - Define Layers
private extension BrooklynView {

    func defineVideoLayer() {
        videoLayer.videoGravity = .resizeAspect
        videoLayer.backgroundColor = Constant.backgroundColor.cgColor
    }
}

// MARK: - Layout
extension BrooklynView {
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        layoutVideoLayer()
    }
    
    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        layoutVideoLayer()
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        layoutVideoLayer()
    }
    
    override func setFrameOrigin(_ newOrigin: NSPoint) {
        super.setFrameOrigin(newOrigin)
        layoutVideoLayer()
    }
    
    override func animateOneFrame() {
        // Catches changes that none of the callbacks above report, e.g. a resized window
        layoutVideoLayer()
    }
}

private extension BrooklynView {
    
    // legacyScreenSaver can create the view with a frame that does not belong to its display
    // and never corrects it. The window does match the display, so the video fills the window.
    var videoFrame: NSRect {
        guard let contentView = window?.contentView else { return bounds }
        let windowFrame = convert(contentView.bounds, from: contentView)
        // The preview thumbnail keeps its own bounds in case its window is larger than the thumbnail
        let isThumbnail = bounds.width <= Constant.previewMaxSize.width
            && bounds.height <= Constant.previewMaxSize.height
        if isPreview && isThumbnail && windowFrame.contains(bounds) {
            return bounds
        }
        return windowFrame
    }
    
    // In a window at thumbnail size, which is the preview in System Settings
    var showsPreviewThumbnail: Bool {
        guard window != nil else { return false }
        return [bounds.size, videoFrame.size].contains { size in
            size.width > 0 && size.height > 0
                && size.width <= Constant.previewMaxSize.width && size.height <= Constant.previewMaxSize.height
        }
    }
    
    func layoutVideoLayer() {
        if !Static.hostsPreview && showsPreviewThumbnail {
            Static.hostsPreview = true
            trace("this host shows the preview")
        }
        let targetFrame = videoFrame
        let scale = window?.backingScaleFactor ?? 1.0
        guard targetFrame != appliedVideoFrame || scale != appliedContentsScale else { return }
        appliedVideoFrame = targetFrame
        appliedContentsScale = scale
        
        // Without implicit animation, the video would visibly slide into place otherwise
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        videoLayer.frame = targetFrame
        videoLayer.contentsScale = scale
        layer?.contentsScale = scale
        CATransaction.commit()
        
        logLayout()
    }
    
    func logLayout() {
        var windowFrame = "none"
        var screenFrame = "none"
        if let window = window {
            windowFrame = NSStringFromRect(window.frame)
            if let screen = window.screen {
                screenFrame = NSStringFromRect(screen.frame)
            }
        }
        trace("layout: video=\(NSStringFromRect(appliedVideoFrame)) view=\(NSStringFromRect(frame)) "
            + "window=\(windowFrame) screen=\(screenFrame) scale=\(appliedContentsScale) preview=\(isPreview)")
    }
    
    // A few lines per run that show what the host does with the view:
    // log show --last 10m --predicate 'subsystem CONTAINS "brooklyn"'
    func trace(_ message: String) {
        os_log("%{public}@", log: Static.log, type: .default, message)
    }
}

// MARK: - Preferences
extension BrooklynView {

    override var hasConfigureSheet: Bool {
        return true
    }

    override var configureSheet: NSWindow? {
        trace("configureSheet requested")
        let sheet = preferences.window
        preferences.resumePreview()
        return sheet
    }
}
