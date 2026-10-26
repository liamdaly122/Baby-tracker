import Foundation
import Testing

@testable import MissionCore

@Suite("Content schema")
struct ContentSchemaTests {
    @Test("Copy falls back full → mild → off")
    func copyFallback() {
        let offOnly = LocalizedCopy(off: "Plain")
        #expect(offOnly.text(for: .full) == "Plain")
        #expect(offOnly.text(for: .mild) == "Plain")

        let offAndMild = LocalizedCopy(off: "Plain", mild: "Mild")
        #expect(offAndMild.text(for: .full) == "Mild")
        #expect(offAndMild.text(for: .off) == "Plain")

        let all = LocalizedCopy(off: "Plain", mild: "Mild", full: "Full")
        #expect(all.text(for: .full) == "Full")
        #expect(all.text(for: .mild) == "Mild")
        #expect(all.text(for: .off) == "Plain")
    }

    @Test("Humour levels are ordered off < mild < full")
    func humourOrdering() {
        #expect(HumourLevel.off < .mild)
        #expect(HumourLevel.mild < .full)
    }

    @Test("Envelope rejects an unsupported schema version")
    func rejectsSchemaVersion() throws {
        let json = #"{"schemaVersion": 2, "contentVersion": "x", "region": "uk", "items": []}"#
        #expect(throws: ContentDecodingError.unsupportedSchemaVersion(2)) {
            _ = try ContentDecoding.envelope(ThresholdItem.self, from: Data(json.utf8))
        }
    }

    @Test("Envelope rejects a file in the wrong region folder")
    func rejectsRegionMismatch() throws {
        let json = #"{"schemaVersion": 1, "contentVersion": "x", "region": "us", "items": []}"#
        #expect(throws: ContentDecodingError.regionMismatch(expected: .uk, found: .us)) {
            _ = try ContentDecoding.envelope(ThresholdItem.self, from: Data(json.utf8), expectedRegion: .uk)
        }
    }

    @Test("Threshold items decode the JSON key \"default\"")
    func thresholdItemDecodes() throws {
        let json = #"""
            {"id": "adviceIntervalSec", "default": 300, "min": 180, "max": 420, "allowsDisabled": false,
             "unit": "seconds", "note": "n",
             "provenance": {"sourceURL": "https://www.nhs.uk/", "sourceTitle": "NHS", "accessed": "2026-10-26",
                            "reviewer": null, "reviewedOn": null, "clinical": true}}
            """#
        let item = try JSONDecoder().decode(ThresholdItem.self, from: Data(json.utf8))
        #expect(item.id == .adviceIntervalSec)
        #expect(item.defaultValue == 300)
        #expect(item.provenance.reviewer == nil)
    }
}
