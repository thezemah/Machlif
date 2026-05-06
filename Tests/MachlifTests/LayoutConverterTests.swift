import XCTest
import MachlifCore

final class LayoutConverterTests: XCTestCase {

    // MARK: - Hebrew → English

    func testHebrewWordToEnglishGibberish() {
        // "שלום" typed when English layout was meant produces "akuo"
        XCTAssertEqual(LayoutConverter.convert("שלום"), "akuo")
    }

    func testHebrewSentenceToEnglish() {
        // "יקללם 'םרלג" is "hello world" typed with Hebrew layout active
        XCTAssertEqual(LayoutConverter.convert("יקללם 'םרלג"), "hello world")
    }

    func testHebrewFinalLetters() {
        // ך→l  ם→o  ן→i  ף→;  ץ→.
        XCTAssertEqual(LayoutConverter.convert("ךםןףץ"), "loi;.")
    }

    // MARK: - English → Hebrew

    func testEnglishGibberishToHebrewWord() {
        XCTAssertEqual(LayoutConverter.convert("akuo"), "שלום")
    }

    func testEnglishCaseIsFolded() {
        // Hebrew has no case; uppercase Latin maps to the same Hebrew letter.
        XCTAssertEqual(LayoutConverter.convert("Akuo"), "שלום")
        XCTAssertEqual(LayoutConverter.convert("AKUO"), "שלום")
    }

    // MARK: - Pass-through

    func testDigitsAndUnmappedPunctuationPassThrough() {
        XCTAssertEqual(LayoutConverter.convert("123 456"), "123 456")
    }

    func testEmptyStringIsUnchanged() {
        XCTAssertEqual(LayoutConverter.convert(""), "")
    }

    // MARK: - Direction detection

    func testDetectionPrefersHebrewWhenMixed() {
        XCTAssertEqual(LayoutConverter.detectDirection("שלום world"), .hebrewToEnglish)
    }

    func testDetectionPrefersEnglishWhenMostlyLatin() {
        XCTAssertEqual(LayoutConverter.detectDirection("hello ש"), .englishToHebrew)
    }

    func testDetectionNoneForDigitsOnly() {
        XCTAssertEqual(LayoutConverter.detectDirection("12345"), .none)
    }

    // MARK: - Round-trip

    func testHebrewRoundTrip() {
        let original = "שלום"
        let once = LayoutConverter.convert(original)
        let twice = LayoutConverter.convert(once)
        XCTAssertEqual(twice, original)
    }

    func testEnglishLowercaseRoundTrip() {
        let original = "akuo"
        let once = LayoutConverter.convert(original)
        let twice = LayoutConverter.convert(once)
        XCTAssertEqual(twice, original)
    }
}
