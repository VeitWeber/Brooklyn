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
    
    // Speed of everything this player plays. A running player switches at once,
    // a paused one uses it the next time play() is called.
    var playbackRate: Float = 1.0 {
        didSet {
            defaultRate = playbackRate
            if rate != 0 {
                rate = playbackRate
            }
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
        observe()
    }
    
    override init() {
        super.init()
    }
    
    deinit {
        unobserve()
    }
    
    override func play() {
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
    
    func observe() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(playerItemDidFinish(_:)),
                                               name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
                                               object: nil)
    }
    
    func unobserve() {
        NotificationCenter.default.removeObserver(self,
                                                  name: NSNotification.Name.AVPlayerItemDidPlayToEndTime,
                                                  object: nil)
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
        // Keep the speed across the change to the next item
        if rate != 0 && rate != playbackRate {
            rate = playbackRate
        }
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
