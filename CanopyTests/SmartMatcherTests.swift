import XCTest
@testable import Canopy

final class SmartMatcherTests: XCTestCase {
    private let matcher = SmartMatcher()

    func test_exactMatch_returnsOne() {
        XCTAssertEqual(matcher.score("calendar", against: "calendar"), 1.0)
    }

    func test_prefixMatch_returnsHighScore() {
        let score = matcher.score("cal", against: "calendar")
        XCTAssertGreaterThanOrEqual(score, 0.90)
    }

    func test_substringMatch() {
        let score = matcher.score("end", against: "calendar")
        XCTAssertGreaterThanOrEqual(score, 0.80)
    }

    func test_acronymMatch_wifiToWiFi() {
        // "wf" should match "Wi-Fi" via acronym
        let score = matcher.score("wf", against: "Wi-Fi")
        XCTAssertGreaterThanOrEqual(score, 0.75)
    }

    func test_acronymMatch_calToCalendar() {
        // "cal" should match "Calendar" via prefix
        let score = matcher.score("cal", against: "Calendar")
        XCTAssertGreaterThanOrEqual(score, 0.90)
    }

    func test_noMatch_returnsZero() {
        let score = matcher.score("zzzzz", against: "Calendar")
        XCTAssertLessThan(score, SmartMatcher.threshold)
    }

    func test_emptyQuery_returnsZero() {
        XCTAssertEqual(matcher.score("", against: "Calendar"), 0)
    }

    func test_caseInsensitive() {
        let score1 = matcher.score("CAL", against: "calendar")
        let score2 = matcher.score("cal", against: "Calendar")
        XCTAssertEqual(score1, score2, accuracy: 0.01)
    }
}

final class DecayCalculatorTests: XCTestCase {
    private let calc = DecayCalculator(halfLifeDays: 14)

    func test_freshUse_addsOne() {
        let now = Date()
        let score = calc.updateScore(previousScore: 0, scoredAt: now, now: now)
        XCTAssertEqual(score, 1.0, accuracy: 0.001)
    }

    func test_halfLifeDecay() {
        let twoWeeksAgo = Date().addingTimeInterval(-14 * 86400)
        let score = calc.currentScore(storedScore: 1.0, scoredAt: twoWeeksAgo)
        XCTAssertEqual(score, 0.5, accuracy: 0.05)
    }

    func test_normalizedScore_converges() {
        // High raw scores should normalize below 1
        let normalized = calc.normalizedScore(100)
        XCTAssertLessThan(normalized, 1.0)
        XCTAssertGreaterThan(normalized, 0.9)
    }

    func test_zeroScore_returnsZero() {
        let score = calc.currentScore(storedScore: 0, scoredAt: Date())
        XCTAssertEqual(score, 0)
    }
}
