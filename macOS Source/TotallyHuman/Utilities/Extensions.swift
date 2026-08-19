import Foundation
import AVFoundation
import Accelerate

extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}

extension Double {
    func aufHundertGerundet() -> Double {
        (self * 100).rounded() / 100
    }
}
