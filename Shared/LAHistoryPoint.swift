// LoopFollow
// LAHistoryPoint.swift

import Foundation

struct LAHistoryPoint: Codable, Equatable, Hashable {
    /// Reading timestamp, Unix epoch seconds.
    let d: Double
    /// Glucose value in mg/dL.
    let v: Int
}
