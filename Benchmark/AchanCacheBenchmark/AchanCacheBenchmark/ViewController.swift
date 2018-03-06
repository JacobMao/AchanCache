//
//  ViewController.swift
//  AchanCacheBenchmark
//
//  Created by ST21073 on 2018/03/06.
//  Copyright © 2018 JacobMao. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.benchmark()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

private extension ViewController {
    func benchmark() {
        memoryCacheBenchmark()
    }

    func memoryCacheBenchmark() {
        var begin: TimeInterval = 0
        var end: TimeInterval = 0
        var time: TimeInterval = 0

        let count = 200_000;

        var dic = Dictionary<NSNumber, Data>()
        let nsDic = NSMutableDictionary()
        let yyMemoryCache = YYMemoryCache()
        let memoryCache = MemoryCache<NSNumber, Data>()


        var keys = [NSNumber]()
        var values = [Data]();

        for var i in 0..<count {
            keys.append(NSNumber(value: i))
            values.append(Data(bytes: &i, count: i.bitWidth / Int8.bitWidth))
        }

        begin = CACurrentMediaTime()
        for i in 0..<count {
            dic[keys[i]] = values[i]
        }
        end = CACurrentMediaTime()
        time = end - begin
        NSLog("Dictionary: %8.2f\n", time * 1000)

        begin = CACurrentMediaTime()
        for i in 0..<count {
            nsDic.setObject(values[i], forKey: keys[i])
        }
        end = CACurrentMediaTime()
        time = end - begin
        NSLog("NSDictionary: %8.2f\n", time * 1000)

        begin = CACurrentMediaTime()
        for i in 0..<count {
            yyMemoryCache.setObject(values[i], forKey: keys[i])
        }
        end = CACurrentMediaTime()
        time = end - begin
        NSLog("YYMemberCache: %8.2f\n", time * 1000)

        begin = CACurrentMediaTime()
        for i in 0..<count {
            memoryCache.setObject(values[i], forKey: keys[i])
        }
        end = CACurrentMediaTime()
        time = end - begin
        NSLog("Achan Memory cache: %8.2f\n", time * 1000)
    }
}
