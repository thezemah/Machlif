import Foundation

public enum ConversionDirection {
    case hebrewToEnglish
    case englishToHebrew
    case none
}

public enum LayoutConverter {

    // Israeli SI-1452 Hebrew layout aligned to US QWERTY by physical key.
    // Top row:    ק→e  ר→r  א→t  ט→y  ו→u  ן→i  ם→o  פ→p
    // Home row:   ש→a  ד→s  ג→d  כ→f  ע→g  י→h  ח→j  ל→k  ך→l  ף→;
    // Bottom row: ז→z  ס→x  ב→c  ה→v  נ→b  מ→n  צ→m  ת→,  ץ→.
    private static let hebrewToEnglishMap: [Character: Character] = [
        "ק": "e", "ר": "r", "א": "t", "ט": "y", "ו": "u",
        "ן": "i", "ם": "o", "פ": "p",
        "ש": "a", "ד": "s", "ג": "d", "כ": "f", "ע": "g",
        "י": "h", "ח": "j", "ל": "k", "ך": "l", "ף": ";",
        "ז": "z", "ס": "x", "ב": "c", "ה": "v", "נ": "b",
        "מ": "n", "צ": "m", "ת": ",", "ץ": ".",
        "/": "q", "'": "w",
    ]

    private static let englishToHebrewMap: [Character: Character] = {
        var map: [Character: Character] = [:]
        for (heb, eng) in hebrewToEnglishMap {
            map[eng] = heb
            // Hebrew has no case, so map uppercase Latin to the same Hebrew letter.
            let upper = Character(eng.uppercased())
            if upper != eng {
                map[upper] = heb
            }
        }
        return map
    }()

    public static func detectDirection(_ s: String) -> ConversionDirection {
        var hebrewCount = 0
        var latinCount = 0
        for ch in s {
            if let scalar = ch.unicodeScalars.first {
                if (0x0590...0x05FF).contains(scalar.value) {
                    hebrewCount += 1
                } else if ch.isLetter && ch.isASCII {
                    latinCount += 1
                }
            }
        }
        if hebrewCount == 0 && latinCount == 0 { return .none }
        return hebrewCount >= latinCount ? .hebrewToEnglish : .englishToHebrew
    }

    public static func convert(_ s: String) -> String {
        convert(s, hebrewToEnglish: hebrewToEnglishMap, englishToHebrew: englishToHebrewMap)
    }

    public static func convert(
        _ s: String,
        hebrewToEnglish h2e: [Character: Character],
        englishToHebrew e2h: [Character: Character]
    ) -> String {
        switch detectDirection(s) {
        case .hebrewToEnglish: return apply(map: h2e, to: s)
        case .englishToHebrew: return apply(map: e2h, to: s)
        case .none: return s
        }
    }

    private static func apply(map: [Character: Character], to s: String) -> String {
        var out = String()
        out.reserveCapacity(s.count)
        for ch in s {
            out.append(map[ch] ?? ch)
        }
        return out
    }
}
