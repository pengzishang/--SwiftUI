import Foundation

enum ContentSource: Equatable {
    case network
    case cache(Date?)
}

extension ContentSource {
    var isCache: Bool {
        if case .cache = self { return true }
        return false
    }
}
