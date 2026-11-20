//
//  LoopPlayer.swift
//  Brooklyn
//
//  Created by Pedro Carrasco on 23/02/2019.
//  Copyright © 2019 Pedro Carrasco. All rights reserved.
//

import AVFoundation

// MARK: - LoopPlayer
final class LoopPlayer: AVQueuePlayer {
    
    // Tracks ObjectIdentifiers of items that belong to this player instance,
    // so we can filter out AVPlayerItemDidPlayToEndTime notifications from other
    // LoopPlayer instances (e.g. screensaver preview + main display, multi-monitor).
    private var managedItemIDs: Set<ObjectIdentifier> = []
    
    private enum Constant {
        // Per item, so a rate that an item cannot play does not end in a loop of corrections
        static let maxRateCorrections = 3
        // Only the first items of a player are logged
        static let loggedItems = 4
    }
    
    private var rateCorrections = 0
    private var loggedItems = 0
    private var currentItemObservation: NSKeyValueObservation?
    
    // Speed of everything this player plays. A running player switches at once,
    // a paused one uses it the next time play() is called.
    var playbackRate: Float = 1.0 {
        didSet {
            rateCorrections = 0
            defaultRate = playbackRate
            if rate != 0 {
                rate = playbackRate
            }
            Log.trace("player: wanted rate \(playbackRate), rate now \(rate)")
        }
    }

    // MARK: Lifecycle
    init(items: [Animation], numberOfLoops: Int, shouldRandomize: Bool) {
        let items = (shouldRandomize ? items.shuffled() : items)
            .reduce(into: [AVPlayerItem]()) {
                guard let item = AVPlayerItem(video: $1, extension: .mp4, for: LoopPlayer.self) else { return }
                $0.append(contentsOf: Array(copy: item, count: max(0, numberOfLoops)))
            }
            .prepareForQueue()
        
        super.init(items: items)
        items.forEach { managedItemIDs.insert(ObjectIdentifier($0)) }
        startObserving()
    }
    
    override init() {
        super.init()
    }
    
    deinit {
        stopObserving()
    }
    
    override func play() {
        rateCorrections = 0
        super.play()
        // play() starts at defaultRate, this covers the case that it does not
        if rate != playbackRate {
            rate = playbackRate
        }
    }
}

// MARK: - Actions
extension LoopPlayer {
    
    func stop() {
        managedItemIDs.removeAll()
        removeAllItems()
    }

    func play(_ animation: Animation) {
        guard let item = AVPlayerItem(video: animation, extension: .mp4, for: LoopPlayer.self) else { return }
        actionAtItemEnd = .none
        managedItemIDs.removeAll()
        removeAllItems()
        let prepared = [item].prepareForQueue()
        prepared.forEach {
            managedItemIDs.insert(ObjectIdentifier($0))
            insert($0, after: items().last)
        }
        actionAtItemEnd = .advance
    }
}

// MARK: - Observers
private extension LoopPlayer {
    
    func startObserving() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(playerItemDidFinish(_:)),
                                               name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(playerRateDidChange(_:)),
                                               name: AVPlayer.rateDidChangeNotification,
                                               object: self)
        currentItemObservation = observe(\.currentItem, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.currentItemDidChange()
            }
        }
    }
    
    func stopObserving() {
        NotificationCenter.default.removeObserver(self,
                                                  name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
                                                  object: nil)
        NotificationCenter.default.removeObserver(self,
                                                  name: AVPlayer.rateDidChangeNotification,
                                                  object: self)
        currentItemObservation?.invalidate()
        currentItemObservation = nil
    }
    
    @objc
    func playerItemDidFinish(_ notification: Notification) {
        guard let finishedItem = notification.object as? AVPlayerItem else { return }
        // AVFoundation may post this on another thread, the queue is only changed on the main thread
        if Thread.isMainThread {
            requeue(finishedItem)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.requeue(finishedItem)
            }
        }
    }
    
    func requeue(_ finishedItem: AVPlayerItem) {
        // Items of other LoopPlayer instances in the same host process are not ours to loop
        guard managedItemIDs.remove(ObjectIdentifier(finishedItem)) != nil else { return }
        // Append the item that finished. By now currentItem can already be the next one in the queue.
        guard let itemCopy = finishedItem.copy() as? AVPlayerItem else { return }
        managedItemIDs.insert(ObjectIdentifier(itemCopy))
        insert(itemCopy, after: nil)
        enforcePlaybackRate(because: "item finished")
    }
    
    @objc
    func playerRateDidChange(_ notification: Notification) {
        let reason = String(describing: notification.userInfo ?? [:])
        DispatchQueue.main.async { [weak self] in
            self?.enforcePlaybackRate(because: reason)
        }
    }
    
    func currentItemDidChange() {
        rateCorrections = 0
        if let item = currentItem, loggedItems < Constant.loggedItems {
            loggedItems += 1
            Log.trace("player: item started, rate \(rate), wanted \(playbackRate), "
                + "slowForward \(item.canPlaySlowForward), fastForward \(item.canPlayFastForward)")
        }
        enforcePlaybackRate(because: "item started")
    }
    
    // AVQueuePlayer and AVKit can change the rate on their own, for example when the next item starts
    func enforcePlaybackRate(because reason: String) {
        guard rate != 0, rate != playbackRate, rateCorrections <= Constant.maxRateCorrections else { return }
        rateCorrections += 1
        guard rateCorrections <= Constant.maxRateCorrections else {
            Log.trace("player: rate stays at \(rate) instead of \(playbackRate), \(reason)")
            return
        }
        Log.trace("player: rate was \(rate), set to \(playbackRate), \(reason)")
        rate = playbackRate
    }
}

// MARK: - AVPlayerItems' Utils
fileprivate extension Array where Element: AVPlayerItem {
    
    func prepareForQueue() -> [AVPlayerItem] {
        if count == 1, let itemCopy = first?.copy() as? AVPlayerItem {
            return self + [itemCopy]
        }
        
        return self
    }
    
    init(copy item: Element, count: Int) {
        let elements = [Int](0...count).compactMap { _ in return item.copy() as? Element }
        self.init(elements)
    }
}
