import Foundation
import Testing

@testable import MissionCore

extension CallRuleTests {
    @Test("Once every gap is 5 minutes or less, the advice is always to call, never \"Keep timing\" (hazard HZ-01)")
    func neverKeepTimingAtTheCallPoint() {
        var random = SeededGenerator(seed: 2026)
        for _ in 0..<500 {
            let count = Int.random(in: EngineConstants.minimumContractions...16, using: &random)
            let gaps = (1..<count).map { _ in Double.random(in: 60...300, using: &random).rounded() }
            let duration = Double.random(in: 30...90, using: &random).rounded()
            let now = gaps.reduce(0, +) + duration + 30
            let output = GoNoGoEngine.evaluate(ukInput(withGaps(gaps, duration: duration), now: now))
            #expect(output.state >= .callTriage, "Gaps \(gaps), each \(duration) s")
            #expect(StateCopy.headline(for: output.state, region: .uk) != "Keep timing")
        }
    }
}
