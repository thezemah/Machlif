import Carbon.HIToolbox

enum HebrewLayoutDetector {

    struct Maps {
        let hebrewToEnglish: [Character: Character]
        let englishToHebrew: [Character: Character]
    }

    /// Returns conversion maps built from the installed Hebrew keyboard layout(s).
    /// If multiple Hebrew layouts are installed the one that covers the most characters
    /// in `text` is chosen. Returns nil when no Hebrew layout is installed (caller
    /// should fall back to the static SI-1452 map).
    static func bestMaps(for text: String) -> Maps? {
        guard let usData = layoutData(for: "com.apple.keylayout.US") else { return nil }

        let hebrewIDs = installedHebrewSourceIDs()
        guard !hebrewIDs.isEmpty else { return nil }

        let candidates = hebrewIDs.compactMap { id -> Maps? in
            guard let data = layoutData(for: id) else { return nil }
            return buildMaps(hebrewData: data, usData: usData)
        }
        guard !candidates.isEmpty else { return nil }
        guard candidates.count > 1 else { return candidates[0] }

        // Pick the map that covers the most characters in the input
        let hebrewChars = text.filter(isHebrew)
        if !hebrewChars.isEmpty {
            return candidates.max { score($0.hebrewToEnglish, hebrewChars) < score($1.hebrewToEnglish, hebrewChars) }
        }
        let latinChars = text.filter { $0.isLetter && $0.isASCII }
        if !latinChars.isEmpty {
            return candidates.max { score($0.englishToHebrew, latinChars) < score($1.englishToHebrew, latinChars) }
        }
        return candidates.first
    }

    // MARK: - Private helpers

    private static func score(_ map: [Character: Character], _ chars: String) -> Int {
        chars.filter { map[$0] != nil }.count
    }

    private static func isHebrew(_ ch: Character) -> Bool {
        ch.unicodeScalars.first.map { (0x0590...0x05FF).contains($0.value) } ?? false
    }

    private static func installedHebrewSourceIDs() -> [String] {
        let props = [kTISPropertyInputSourceType: kTISTypeKeyboardLayout] as CFDictionary
        guard let cfList = TISCreateInputSourceList(props, false)?.takeRetainedValue() else { return [] }
        let count = CFArrayGetCount(cfList)
        var ids: [String] = []

        for i in 0..<count {
            guard let rawSrc = CFArrayGetValueAtIndex(cfList, i) else { continue }
            let source = Unmanaged<TISInputSource>.fromOpaque(rawSrc).takeUnretainedValue()

            guard let langRaw = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages) else { continue }
            let langs = Unmanaged<CFArray>.fromOpaque(langRaw).takeUnretainedValue() as NSArray
            guard (langs as? [String])?.contains(where: { $0.hasPrefix("he") }) == true else { continue }

            guard let idRaw = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { continue }
            ids.append(Unmanaged<CFString>.fromOpaque(idRaw).takeUnretainedValue() as String)
        }
        return ids
    }

    private static func layoutData(for sourceID: String) -> Data? {
        let props = [kTISPropertyInputSourceID: sourceID as CFString] as CFDictionary
        guard let cfList = TISCreateInputSourceList(props, true)?.takeRetainedValue(),
              CFArrayGetCount(cfList) > 0,
              let rawSrc = CFArrayGetValueAtIndex(cfList, 0) else { return nil }

        let source = Unmanaged<TISInputSource>.fromOpaque(rawSrc).takeUnretainedValue()
        guard let dataRaw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        return Unmanaged<CFData>.fromOpaque(dataRaw).takeUnretainedValue() as Data
    }

    private static func buildMaps(hebrewData: Data, usData: Data) -> Maps {
        let kbdType = UInt32(LMGetKbdType())
        var h2e: [Character: Character] = [:]
        var e2h: [Character: Character] = [:]

        for keyCode in UInt16(0)..<UInt16(52) {
            guard let hStr = translate(keyCode: keyCode, data: hebrewData, kbdType: kbdType),
                  let eStr = translate(keyCode: keyCode, data: usData, kbdType: kbdType),
                  hStr.count == 1, eStr.count == 1 else { continue }

            let h = Character(hStr), e = Character(eStr)

            let hOk = isHebrew(h) || "';/,.".contains(h)
            let eOk = e.isLetter || "';/,.".contains(e)
            guard hOk && eOk else { continue }

            h2e[h] = e
            e2h[e] = h
            if e.isLowercase {
                e2h[Character(e.uppercased())] = h
            }
        }
        return Maps(hebrewToEnglish: h2e, englishToHebrew: e2h)
    }

    private static func translate(keyCode: UInt16, data: Data, kbdType: UInt32) -> String? {
        var deadKey: UInt32 = 0
        var length: Int = 0
        var chars = [UniChar](repeating: 0, count: 8)

        let status = data.withUnsafeBytes { raw -> OSStatus in
            guard let base = raw.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return -1 }
            return UCKeyTranslate(base, keyCode, UInt16(kUCKeyActionDown), 0, kbdType,
                                  OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKey,
                                  chars.count, &length, &chars)
        }

        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: Array(chars.prefix(length)), count: length)
    }
}
