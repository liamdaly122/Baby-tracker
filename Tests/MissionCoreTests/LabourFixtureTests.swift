import Foundation
import Testing

@testable import MissionCore

/// A scripted labour from Tests/MissionCoreTests/Fixtures. Times are seconds from the first start.
///
/// A fixture either checks one moment (`evaluateAtSec` and `expect`) or plays out a timeline
/// (`checks`): each check sees only the contractions started by then, with any still going treated
/// as open, and gets the previous check's snapshot, so hysteresis plays out as it would live.
struct LabourFixture: Decodable {
    struct Pattern: Decodable {
        var firstStartSec: Double
        var count: Int
        /// Even gaps. Use `cycleSec` instead for gaps that repeat in a cycle, such as 3 then 5 minutes.
        var everySec: Double?
        var cycleSec: [Double]?
        var durationSec: Double
        var openLast: Bool?
        /// Positions (0-based) of contractions that happened but were never tapped.
        var skip: [Int]?
    }

    struct Entry: Decodable {
        var startSec: Double
        /// Missing means the contraction was never stopped.
        var durationSec: Double?
    }

    struct Expectation: Decodable {
        var state: LabourState
        var reasons: [ReasonCode]
        var needsEditCount: Int
    }

    struct Check: Decodable {
        var atSec: Double
        var state: LabourState
        var reasons: [ReasonCode]
    }

    var name: String
    var region: ContentRegion
    var profile: Profile
    var thresholdOverrides: [String: Double]
    var redFlags: [RedFlag]
    var patterns: [Pattern]
    var contractions: [Entry]
    var evaluateAtSec: Double?
    var expect: Expectation?
    var checks: [Check]?
    /// When he said the contractions stopped.
    var easedAtSec: Double?

    struct Profile: Decodable {
        var parity: Int
        var previousFastLabour: Bool
        var gestationalAgeDays: Int?
        var termAnswer: TermAnswer?
        var travelMinutes: Int?
    }

    static let origin = Date(timeIntervalSince1970: 1_800_000_000)

    static func names() -> [String] {
        guard let folder = Bundle.module.resourceURL?.appendingPathComponent("Fixtures"),
            let files = try? FileManager.default.contentsOfDirectory(atPath: folder.path)
        else { return [] }
        return files.filter { $0.hasSuffix(".json") }.map { String($0.dropLast(5)) }.sorted()
    }

    static func load(_ name: String) throws -> LabourFixture {
        let url = try #require(Bundle.module.resourceURL).appendingPathComponent("Fixtures/\(name).json")
        return try JSONDecoder().decode(LabourFixture.self, from: Data(contentsOf: url))
    }

    func builtContractions() -> [Contraction] {
        var result: [Contraction] = []
        for pattern in patterns {
            var start = pattern.firstStartSec
            for index in 0..<pattern.count {
                let isOpen = pattern.openLast == true && index == pattern.count - 1
                if !(pattern.skip ?? []).contains(index) {
                    result.append(contraction(startSec: start, durationSec: isOpen ? nil : pattern.durationSec))
                }
                if let cycle = pattern.cycleSec, !cycle.isEmpty {
                    start += cycle[index % cycle.count]
                } else {
                    start += pattern.everySec ?? 0
                }
            }
        }
        for entry in contractions {
            result.append(contraction(startSec: entry.startSec, durationSec: entry.durationSec))
        }
        return result
    }

    /// The log as it stood at `atSec`: only contractions started by then, still open if they hadn't ended.
    func contractions(asOf atSec: Double) -> [Contraction] {
        let now = Self.origin.addingTimeInterval(atSec)
        return builtContractions().filter { $0.start <= now }.map { contraction in
            var seen = contraction
            if let end = contraction.end, end > now { seen.end = nil }
            return seen
        }
    }

    func input(atSec: Double? = nil) throws -> EngineInput {
        var overrides: [ThresholdField: Double] = [:]
        for (key, value) in thresholdOverrides {
            overrides[try #require(ThresholdField(rawValue: key))] = value
        }
        return EngineInput(
            contractions: builtContractions(),
            redFlags: Set(redFlags),
            profile: LabourProfile(
                region: region,
                parity: profile.parity,
                previousFastLabour: profile.previousFastLabour,
                gestationalAgeDays: profile.gestationalAgeDays,
                termAnswer: profile.termAnswer,
                travelMinutes: profile.travelMinutes
            ),
            thresholds: ThresholdTable.builtIn(for: region).profile(applying: overrides),
            easedAt: easedAtSec.flatMap { eased in
                eased <= (atSec ?? .infinity) ? Self.origin.addingTimeInterval(eased) : nil
            },
            now: Self.origin.addingTimeInterval(atSec ?? evaluateAtSec ?? 0)
        )
    }

    private func contraction(startSec: Double, durationSec: Double?) -> Contraction {
        let start = Self.origin.addingTimeInterval(startSec)
        return Contraction(start: start, end: durationSec.map { start.addingTimeInterval($0) })
    }
}

@Suite("Scripted labours")
struct LabourFixtureTests {
    @Test("Fixtures are bundled")
    func fixturesExist() {
        #expect(LabourFixture.names().count >= 40)
    }

    @Test("Scripted labour gives the expected advice", arguments: LabourFixture.names())
    func scriptedLabour(name: String) throws {
        let fixture = try LabourFixture.load(name)
        #expect(fixture.expect != nil || fixture.checks != nil, "\(fixture.name) checks nothing")
        if let expect = fixture.expect {
            let output = GoNoGoEngine.evaluate(try fixture.input())
            #expect(output.state == expect.state, "\(fixture.name)")
            #expect(output.reasons == expect.reasons, "\(fixture.name)")
            #expect(output.metrics.needsEdit.count == expect.needsEditCount, "\(fixture.name)")
        }
        var previous: EngineStateSnapshot?
        for check in fixture.checks ?? [] {
            var input = try fixture.input(atSec: check.atSec)
            input.contractions = fixture.contractions(asOf: check.atSec)
            input.previous = previous
            let output = GoNoGoEngine.evaluate(input)
            #expect(output.state == check.state, "\(fixture.name) at \(check.atSec)")
            #expect(output.reasons == check.reasons, "\(fixture.name) at \(check.atSec)")
            previous = output.snapshot
        }
    }
}
