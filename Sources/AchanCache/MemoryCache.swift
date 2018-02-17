//
//  MemoryCache.swift
//  AchanCache
//
//  Created by Jacob Mao on 2/17/18.
//
//  The MIT License (MIT)
//
//  Copyright (c) 2017 Jacob Mao.
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

private class ListNode<K: Hashable, V> {
    var prev: ListNode<K, V>?
    var next: ListNode<K, V>?
    var cost: UInt = 0
    var time: TimeInterval = 0
    
    private let _key: K
    private let _value: V
    
    init(key: K, value: V) {
        _key = key
        _value = value
    }
}

private class LruHandler<K: Hashable, V> {
    typealias NodeType = ListNode<K, V>
    
    var dic = [K: V]()
    var totalCost: UInt = 0
    var headNode: NodeType?
    var tailNode: NodeType?
    var shouldReleaseOnMainQueue = false
    var shouldAsynchronouslyRelease = true
}

private extension LruHandler {
    func insertHeadNode(_ node: NodeType) {
        
    }
    
    func bringNode(toHead node: NodeType) {
        
    }
    
    func removeNode(_ node: NodeType) {
        
    }
    
    func removeTail() -> NodeType? {
        return nil
    }
    
    func removeAll() {
        
    }
}
