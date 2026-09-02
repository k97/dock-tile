//
//  AboutLinksTests.swift
//  DockTileTests
//
//  Guards the About pane's "Send Feedback…" destination. `AboutLinks.feedback` reads the address
//  from Info.plist `DTFeedbackEmail` and silently falls back to the website when the key is absent
//  or the URL cannot be built — a fallback that looks identical to the Website row in the UI while
//  the copy still promises the message reaches the developer. These pin the key's presence in the
//  shipped bundle (the test host IS the dev app) and the exact mailto the button opens.
//

import Foundation
import Testing
@testable import Dock_Tile

@Suite("About pane links")
struct AboutLinksTests {

    /// The key must actually ship: an absent or empty `DTFeedbackEmail` degrades feedback to the
    /// website with no visible signal.
    @Test("Info.plist carries the feedback address")
    func feedbackAddressIsBundled() throws {
        let email = try #require(
            Bundle.main.object(forInfoDictionaryKey: "DTFeedbackEmail") as? String
        )
        #expect(email == "hello@happymachines.company")
    }

    /// Exact URL, not just "is a mailto": the subject is percent-encoded by URLComponents, and a
    /// malformed address would have collapsed to `website` instead.
    @Test("Send Feedback opens a prefilled mailto")
    func feedbackBuildsMailto() {
        #expect(
            AboutLinks.feedback.absoluteString
                == "mailto:hello@happymachines.company?subject=Dock%20Tile%20feedback"
        )
        #expect(AboutLinks.feedback != AboutLinks.website)
    }
}
