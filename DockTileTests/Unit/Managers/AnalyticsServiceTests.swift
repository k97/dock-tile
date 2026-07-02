import Testing
import Foundation
@testable import Dock_Tile

// MARK: - Analytics Service Tests
//
// Guards the two regression-prone, privacy-critical parts of the Firebase layer without importing
// Firebase, touching UserDefaults, or depending on the build environment:
//   1. Every AnalyticsEvent raw value stays Firebase-safe (snake_case, <=40 chars, no reserved
//      prefix, unique) — a bad name is silently dropped by Firebase in production.
//   2. Collection gating: opt-out consent resolution + the Release-only AND consent gate. A wrong
//      result here either leaks data from a Debug build or silently stops collection in Release.

@Suite("AnalyticsEvent naming")
struct AnalyticsEventNamingTests {

    /// Firebase event names: start with a letter, then letters/digits/underscores. Our house style
    /// is lowercase snake_case.
    private let validPattern = try! NSRegularExpression(pattern: "^[a-z][a-z0-9_]*$")

    private func matches(_ value: String) -> Bool {
        let range = NSRange(value.startIndex..., in: value)
        return validPattern.firstMatch(in: value, range: range) != nil
    }

    @Test("Every event name is lowercase snake_case, non-empty, and <= 40 characters")
    func namesAreFirebaseSafe() {
        for event in AnalyticsEvent.allCases {
            let name = event.rawValue
            #expect(!name.isEmpty, "\(event) has an empty raw value")
            #expect(name.count <= 40, "\(event) raw value '\(name)' exceeds 40 characters")
            #expect(matches(name), "\(event) raw value '\(name)' is not lowercase snake_case")
        }
    }

    @Test("No event uses a Firebase-reserved prefix")
    func noReservedPrefixes() {
        let reserved = ["firebase_", "google_", "ga_"]
        for event in AnalyticsEvent.allCases {
            for prefix in reserved {
                #expect(!event.rawValue.hasPrefix(prefix),
                        "\(event) raw value '\(event.rawValue)' uses reserved prefix '\(prefix)'")
            }
        }
    }

    @Test("Event raw values are unique")
    func rawValuesAreUnique() {
        let values = AnalyticsEvent.allCases.map(\.rawValue)
        #expect(Set(values).count == values.count, "duplicate AnalyticsEvent raw values: \(values)")
    }
}

@Suite("Analytics collection gating")
struct AnalyticsGatingTests {

    @Test("Consent is opt-out: absent resolves to granted")
    func consentDefaultsOn() {
        #expect(AnalyticsService.resolveConsent(storedValue: nil) == true)
    }

    @Test("Stored consent is honoured exactly")
    func consentHonoursStoredValue() {
        #expect(AnalyticsService.resolveConsent(storedValue: true) == true)
        #expect(AnalyticsService.resolveConsent(storedValue: false) == false)
    }

    @Test("Collection requires BOTH a Release build AND consent")
    func shouldCollectMatrix() {
        #expect(AnalyticsService.shouldCollect(isRelease: true, consentGranted: true) == true)
        // A Debug/Dev build never sends, regardless of consent.
        #expect(AnalyticsService.shouldCollect(isRelease: false, consentGranted: true) == false)
        // A Release build with the user opted out never sends.
        #expect(AnalyticsService.shouldCollect(isRelease: true, consentGranted: false) == false)
        #expect(AnalyticsService.shouldCollect(isRelease: false, consentGranted: false) == false)
    }

    @Test("Opting out after default-on flips collection off in a Release build")
    func optOutFlipsCollection() {
        // Compose the two seams the way applyCollectionState() does.
        let defaultConsent = AnalyticsService.resolveConsent(storedValue: nil)
        #expect(AnalyticsService.shouldCollect(isRelease: true, consentGranted: defaultConsent) == true)

        let optedOut = AnalyticsService.resolveConsent(storedValue: false)
        #expect(AnalyticsService.shouldCollect(isRelease: true, consentGranted: optedOut) == false)
    }
}
