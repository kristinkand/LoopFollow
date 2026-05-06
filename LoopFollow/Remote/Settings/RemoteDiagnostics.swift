// LoopFollow
// RemoteDiagnostics.swift

import Foundation

struct RemoteDiagnostics {
    enum Status: Equatable {
        case unknown
        case running
        case ok
        case failed(String)
    }

    var status: Status = .unknown
    var bundleMismatch: BundleMismatch?
    var bouncingTokens: BouncingTokens?
    var futureStartDate: FutureStartDate?

    var hasAnyWarning: Bool {
        bundleMismatch != nil || bouncingTokens != nil || futureStartDate != nil
    }

    struct BundleMismatch: Equatable {
        let expectedDevice: String
        let observedBundleId: String
    }

    struct BouncingTokens: Equatable {
        let distinctCount: Int
        let recordsScanned: Int
    }

    struct FutureStartDate: Equatable {
        let startDate: Date
    }
}
