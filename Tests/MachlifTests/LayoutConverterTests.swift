import Testing
import MachlifCore

@Suite struct LayoutConverterTests {

    // MARK: - Hebrew → English

    @Test func hebrewWordToEnglishGibberish() {
        #expect(LayoutConverter.convert("שלום") == "akuo")
    }

    @Test func hebrewSentenceToEnglish() {
        // "יקךךם 'םרךג" is "hello world" typed with Hebrew layout active
        // ל(lamed)→k, ך(final-kaf)→l per SI-1452 physical key positions
        #expect(LayoutConverter.convert("יקךךם 'םרךג") == "hello world")
    }

    @Test func hebrewFinalLetters() {
        // ך→l  ם→o  ן→i  ף→;  ץ→.
        #expect(LayoutConverter.convert("ךםןףץ") == "loi;.")
    }

    // MARK: - English → Hebrew

    @Test func englishGibberishToHebrewWord() {
        #expect(LayoutConverter.convert("akuo") == "שלום")
    }

    @Test func englishCaseIsFolded() {
        // Hebrew has no case; uppercase Latin maps to the same Hebrew letter.
        #expect(LayoutConverter.convert("Akuo") == "שלום")
        #expect(LayoutConverter.convert("AKUO") == "שלום")
    }

    // MARK: - Pass-through

    @Test func digitsAndUnmappedPunctuationPassThrough() {
        #expect(LayoutConverter.convert("123 456") == "123 456")
    }

    @Test func emptyStringIsUnchanged() {
        #expect(LayoutConverter.convert("") == "")
    }

    // MARK: - Direction detection

    @Test func detectionPrefersHebrewWhenMixed() {
        // 4 Hebrew letters vs 3 Latin — Hebrew majority → hebrewToEnglish
        #expect(LayoutConverter.detectDirection("שלום wor") == .hebrewToEnglish)
    }

    @Test func detectionPrefersEnglishWhenMostlyLatin() {
        #expect(LayoutConverter.detectDirection("hello ש") == .englishToHebrew)
    }

    @Test func detectionNoneForDigitsOnly() {
        #expect(LayoutConverter.detectDirection("12345") == .none)
    }

    // MARK: - Round-trip

    @Test func hebrewRoundTrip() {
        let original = "שלום"
        let once = LayoutConverter.convert(original)
        let twice = LayoutConverter.convert(once)
        #expect(twice == original)
    }

    @Test func englishLowercaseRoundTrip() {
        let original = "akuo"
        let once = LayoutConverter.convert(original)
        let twice = LayoutConverter.convert(once)
        #expect(twice == original)
    }
}
