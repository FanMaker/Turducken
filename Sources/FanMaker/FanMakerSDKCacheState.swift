import Foundation
import SwiftUI
import WebKit

@available(iOS 13.0, *)

public final class FanMakerSDKCacheState {
    public var cacheFilePath: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent("cachedResponses")
    }

    public var inMemoryCache: [String: CachedURLResponse] {
        didSet {
            if let cachedResponsesData = try? NSKeyedArchiver.archivedData(withRootObject: inMemoryCache, requiringSecureCoding: false) {
                try? cachedResponsesData.write(to: cacheFilePath)
            }
        }
    }

    public init() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let cPath = documentsDirectory.appendingPathComponent("cachedResponses")
        // Try to read the archived data from the file system
        if let data = try? Data(contentsOf: cPath),
           let unarchivedCache = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [String: CachedURLResponse] {
            self.inMemoryCache = unarchivedCache
        } else {
            self.inMemoryCache = [:]
        }
    }
}
