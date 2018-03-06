import XCTest
@testable import AchanCache

class AchanCacheTests: XCTestCase {
    func testMemoryCacheBenchmark() {
        var begin: TimeInterval = 0
        var end: TimeInterval = 0
        var time: TimeInterval = 0

        let memoryCache = MemoryCache<Int, NSData>()

        let count = 200_000;
        var keys = [Int]()
        var values = [NSData]();

        for var i in 0..<count {
            keys.append(i)
            values.append(NSData(bytes: &i, length: i.bitWidth / Int8.bitWidth))
        }

        begin = CACurrentMediaTime()
        for i in 0..<count {
            memoryCache.setObject(values[i], forKey: keys[i])
        }
        end = CACurrentMediaTime()
        time = end - begin
        NSLog("Memory cache: %8.2f\n", time * 1000)
    }


    static var allTests = [
        ("testMemoryCacheBenchmark", testMemoryCacheBenchmark),
    ]
}
