import Foundation
import Testing

@testable import MissionCore

/// A scripted labour from Tests/MissionCoreTests/Fixtures. Times are seconds from the first start.
struct LabourFixture: Decodable {
    struct Pattern: Decodable {
        var firstStartSec: Double
        var count: Int
        var everySec: Double
        var durationSec: Double
        var openLast: Bool?
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

    var name: String
    var region: ContentRegion
    var profile: Profile
    var thresholdOverrides: [String: Double]
    var redFlags: [RedFlag]
    var patterns: [Pattern]
    var contractions: [Entry]
    var evaluateAtSec: Double
    var expect: Expectation

    struct Profile: Decodable {
        var parity: Int
        var previousFastLabour: Bool
        var gestationalAgeDays: Int?
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
            for index in 0..<pattern.count {
                let start = pattern.firstStartSec + Double(index) * pattern.everySec
                let isOpen = pattern.openLast == true && index == pattern.count - 1
                result.append(contraction(startSec: start, durationSec: isOpen ? nil : pattern.durationSec))
            }
        }
        for entry in contractions {
            result.append(contraction(startSec: entry.startSec, durationSec: entry.durationSec))
        }
        return result
    }

    func input() throws -> EngineInput {
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
                travelMinutes: profile.travelMinutes
            ),
            thresholds: ThresholdTable.builtIn(for: region).profile(applying: overrides),
            now: Self.origin.addingTimeInterval(evaluateAtSec)
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
        #expect(LabourFixture.names().count >= 26)
    }

    @Test("Scripted labour gives the expected advice", arguments: LabourFixture.names())
    func scriptedLabour(name: String) throws {
        let fixture = try LabourFixture.load(name)
        let output = GoNoGoEngine.evaluate(try fixture.input())
        #expect(output.state == fixture.expect.state, "\(fixture.name)")
        #expect(output.reasons == fixture.expect.reasons, "\(fixture.name)")
        #expect(output.metrics.needsEdit.count == fixture.expect.needsEditCount, "\(fixture.name)")
    }
}
