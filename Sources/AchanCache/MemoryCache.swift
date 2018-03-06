//
//  MemoryCache.swift
//  AchanCache
//
//  Created by Jacob Mao on 2/17/18.
//
//  The MIT License (MIT)
//
//  Copyright (c) 2018 Jacob Mao.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of
//  this software and associated documentation files (the "Software"), to deal in
//  the Software without restriction, including without limitation the rights to
//  use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
//  the Software, and to permit persons to whom the Software is furnished to do so,
//  subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
//  FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
//  COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
//  IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
//  The name and characters used in the demo of this software are property of their
//  respective owners.

import Foundation

#if os(iOS) || os(watchOS) || os(tvOS)
    import UIKit
#endif

private let GlobalReleaseQueue = DispatchQueue.global(qos: .utility)

private protocol ReleaseProtocol {
    func releaseObjects(shouldReleaseOnMainQueue: Bool, shouldAsynchronouslyRelease: Bool, releaseBlock: @escaping () -> Void)
}

extension ReleaseProtocol {
    func releaseObjects(shouldReleaseOnMainQueue: Bool, shouldAsynchronouslyRelease: Bool, releaseBlock: @escaping () -> Void) {
        if shouldAsynchronouslyRelease {
            (shouldReleaseOnMainQueue ? DispatchQueue.main : GlobalReleaseQueue).async {
                releaseBlock()
            }
        } else {
            if shouldReleaseOnMainQueue && !Thread.isMainThread {
                DispatchQueue.main.async {
                    releaseBlock()
                }
            } else {
                releaseBlock()
            }
        }
    }
}

private class ListNode<K: Hashable, V> {
    var prev: ListNode<K, V>?
    var next: ListNode<K, V>?
    var cost: UInt = 0
    var time: TimeInterval = 0
    
    let key: K
    var value: V

    var memoryAddress: UnsafeMutableRawPointer {
        return Unmanaged<AnyObject>.passUnretained(self as AnyObject).toOpaque()
    }

    init(key: K, value: V) {
        self.key = key
        self.value = value
    }

    static func ==(lhs: ListNode<K, V>?, rhs: ListNode<K, V>) -> Bool {
        guard let leftNode = lhs else {
            return false
        }

        return leftNode === rhs
    }

    static func !=(lhs: ListNode<K, V>?, rhs: ListNode<K, V>) -> Bool {
        return !(lhs == rhs)
    }
}

private class LruHandler<K: Hashable, V> {
    typealias NodeType = ListNode<K, V>
    typealias DicType = [K: NodeType]
    
    var dic = DicType()

    var totalCost: UInt = 0

    var headNode: NodeType?
    var tailNode: NodeType?

    var shouldReleaseOnMainQueue = false
    var shouldAsynchronouslyRelease = true
}

private extension LruHandler {
    func insertNode(_ node: NodeType) {
        dic[node.key] = node
        totalCost += node.cost

        if let head = headNode {
            head.prev = node
            node.next = head
            headNode = node
        } else {
            headNode = node
            tailNode = node
        }
    }
    
    func bringNode(toHead node: NodeType) {
        guard headNode != node else {
            return
        }

        if tailNode == node {
            tailNode = node.prev
            tailNode?.next = nil
        } else {
            node.prev?.next = node.next
            node.next?.prev = node.prev
        }

        node.prev = nil
        node.next = headNode

        headNode?.prev = node
        headNode = node
    }
    
    func removeNode(_ node: NodeType) {
        dic[node.key] = nil
        totalCost -= node.cost

        if let nextNode = node.next {
            nextNode.prev = node.prev
        }

        if let prevNode = node.prev {
            prevNode.next = node.next
        }

        if headNode == node {
            headNode = node.next
        }

        if tailNode == node {
            tailNode = node.prev
        }
    }
    
    func removeTail() -> NodeType? {
        guard let tail = tailNode else {
            return nil
        }

        dic[tail.key] = nil
        totalCost -= tail.cost

        if headNode == tail {
            headNode = nil
            tailNode = nil
        } else {
            tailNode = tail.prev
            tailNode?.next = nil
        }

        return tail
    }
    
    func removeAll() {
        guard !dic.isEmpty else {
            return
        }

        totalCost = 0
        headNode = nil
        tailNode = nil

        let tempHolder = dic
        dic = DicType()
        releaseObjects(shouldReleaseOnMainQueue: shouldReleaseOnMainQueue,
                       shouldAsynchronouslyRelease: shouldAsynchronouslyRelease) {
                        let _ = tempHolder.count
        }
    }
}

extension LruHandler: ReleaseProtocol {}

public class MemoryCache<K: Hashable, V> {
    // MARK: - Public Properties
    var shouldRemoveAllObjectsOnMemoryWarning = true
    var shouldRemoveAllObjectsWhenEnteringBackground = true

    var maxCount = UInt.max
    var maxCost = UInt.max
    var maxLifeTime = TimeInterval.infinity
    var autoTrimInterval: TimeInterval = 5.0

    var shouldReleaseOnMainQueue: Bool {
        set {
            _threadSafetyCall{ _lruHandler.shouldReleaseOnMainQueue = newValue }
        }

        get {
            return _threadSafetyCall{ _lruHandler.shouldReleaseOnMainQueue }
        }
    }

    var shouldAsynchronouslyRelease: Bool {
        set {
            _threadSafetyCall{ _lruHandler.shouldAsynchronouslyRelease = newValue }
        }

        get {
            return _threadSafetyCall{ _lruHandler.shouldAsynchronouslyRelease }
        }
    }

    var count: Int {
        return _threadSafetyCall{ _lruHandler.dic.count }
    }

    var totalCost: UInt {
        return _threadSafetyCall{ _lruHandler.totalCost }
    }

    // MARK: - Private Properties
    private let _lruHandler = LruHandler<K, V>()
    private let _locker = DispatchSemaphore(value: 1)
    private let _trimQueue = DispatchQueue(label: "com.achanCache.trim.memory")

    // MARK: - Life Cycle
    init() {
        _setupNotificationHandlers()
        _trimRecursively()
    }

    deinit {
        _removeNotificationHandlers()
        _lruHandler.removeAll()
    }

#if os(iOS) || os(watchOS) || os(tvOS)
    // MARK: - Handle Notifications
    @objc func handleMemoryWarningNotification(_ notification: Notification) {
        if shouldRemoveAllObjectsOnMemoryWarning {
            removeAllObjects()
        }
    }

    @objc func handleEnterBackgroundNotification(_ notification: Notification) {
        if shouldRemoveAllObjectsWhenEnteringBackground {
            removeAllObjects()
        }
    }
#endif
}

// MARK: - MemoryCache's Public Methods
public extension MemoryCache {
    func contains(forKey key: K) -> Bool {
        return _threadSafetyCall{ return _lruHandler.dic.index(forKey: key) != nil }
    }

    func object(forKey key: K) -> V? {
        return _threadSafetyCall({ () -> V? in
            return _lruHandler.dic[key].map({ (node) -> V in
                node.time = CACurrentMediaTime()
                _lruHandler.bringNode(toHead: node)

                return node.value
            }) ?? nil
        })
    }

    func setObject(_ object: V, forKey key: K, withCost cost: UInt = 0) {
        _threadSafetyCall {
            let now = CACurrentMediaTime()

            if let node = _lruHandler.dic[key] {
                if node.cost != cost {
                    _lruHandler.totalCost -= node.cost
                    _lruHandler.totalCost += cost

                    node.cost = cost
                }

                node.time = now
                node.value = object

                _lruHandler.bringNode(toHead: node)
            } else {
                let newNode = ListNode(key: key, value: object)
                newNode.cost = cost
                newNode.time = now

                _lruHandler.insertNode(newNode)
            }

            // TODO: maybe need to trim immediately
        }
    }

    func removeObject(forKey key: K) {
        _threadSafetyCall {
            guard let node = _lruHandler.dic[key] else {
                return
            }

            _lruHandler.removeNode(node)

            releaseObjects(shouldReleaseOnMainQueue: _lruHandler.shouldReleaseOnMainQueue,
                           shouldAsynchronouslyRelease: _lruHandler.shouldAsynchronouslyRelease,
                           releaseBlock: {
                            let _ = node.cost
            })
        }
    }

    func removeAllObjects() {
        _threadSafetyCall{ _lruHandler.removeAll() }
    }

    func trimToCount(_ countLimit: UInt) {
        _trimWith(removeAllCondition: countLimit == 0, finishedCondition: _lruHandler.dic.count <= countLimit)
    }
    
    func trimToCost(_ costLimit: UInt) {
        _trimWith(removeAllCondition: costLimit == 0, finishedCondition: _lruHandler.totalCost <= costLimit)
    }
    
    func trimToLifeCycle(_ lifeCycle: TimeInterval) {
        let now = CACurrentMediaTime()
        let finishedBlock : () -> Bool = {
            guard let tailNode = self._lruHandler.tailNode else {
                return true
            }
            
            return now - tailNode.time <= lifeCycle
        }
        
        _trimWith(removeAllCondition: lifeCycle <= 0, finishedCondition: finishedBlock())
    }
}

// MARK: - MemoryCache's Private Methods
private extension MemoryCache {
    func _setupNotificationHandlers() {
        #if os(iOS) || os(watchOS) || os(tvOS)
            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(handleMemoryWarningNotification),
                                                   name: NSNotification.Name.UIApplicationDidReceiveMemoryWarning,
                                                   object: nil)

            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(handleEnterBackgroundNotification),
                                                   name: NSNotification.Name.UIApplicationDidEnterBackground,
                                                   object: nil)
        #endif
    }

    func _removeNotificationHandlers() {
        #if os(iOS) || os(watchOS) || os(tvOS)
            NotificationCenter.default.removeObserver(self)
        #endif
    }

    func _threadSafetyCall<T>(_ block: () -> T ) -> T {
        _locker.wait()
        let ret = block()
        _locker.signal()

        return ret
    }

    func _trimWith(removeAllCondition: @autoclosure () -> Bool, finishedCondition: @autoclosure () -> Bool) {
        var finished = _threadSafetyCall { () -> Bool in
            if removeAllCondition() {
                _lruHandler.removeAll()
                return true
            } else if finishedCondition() {
                return true
            }

            return false
        }

        if finished {
            return
        }

        let holder = _threadSafetyCall{ () -> [ListNode<K, V>] in
            var holder = [ListNode<K, V>]()
            while !finished {
                if finishedCondition() {
                    finished = true
                } else {
                    if let tailNode = _lruHandler.removeTail() {
                        holder.append(tailNode)
                    }
                }
            }

            return holder
        }

        guard !holder.isEmpty else {
            return
        }

        let releasingQueue = shouldReleaseOnMainQueue ? DispatchQueue.main : GlobalReleaseQueue
        releasingQueue.async {
            let _ = holder.count
        }
    }

    func _trimRecursively() {
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + autoTrimInterval) { [weak self] in
            guard let strongSelf = self else {
                return
            }

            strongSelf._trimInBackground()
            strongSelf._trimRecursively()
        }
    }

    func _trimInBackground() {
        _trimQueue.async {
            self.trimToCost(self.maxCost)
            self.trimToCount(self.maxCount)
            self.trimToLifeCycle(self.maxLifeTime)
        }
    }
}

extension MemoryCache: ReleaseProtocol {}
