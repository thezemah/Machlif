import Carbon

struct LayoutInfo: Identifiable, Hashable {
    let id: String
    let displayName: String
    let language: String
}

struct LayoutMaps {
    let toEnglish: [Character: Character]
    let fromEnglish: [Character: Character]
}

enum KeyboardLayoutDetector {

    nonisolated(unsafe) private static var _layouts: [LayoutInfo]? = nil
    nonisolated(unsafe) private static var _maps: [String: LayoutMaps] = [:]

    static func availableLayouts() -> [LayoutInfo] {
        if let cached = _layouts { return cached }

        guard let usData = qwertyData() else { return [] }
        guard let cfList = TISCreateInputSourceList(nil, false)?.takeRetainedValue() else { return [] }

        var results: [LayoutInfo] = []

        for i in 0..<CFArrayGetCount(cfList) {
            guard let rawSrc = CFArrayGetValueAtIndex(cfList, i) else { continue }
            let src = Unmanaged<TISInputSource>.fromOpaque(rawSrc).takeUnretainedValue()

            guard let dataRaw = TISGetInputSourceProperty(src, kTISPropertyUnicodeKeyLayoutData) else { continue }
            let layoutData = Unmanaged<CFData>.fromOpaque(dataRaw).takeUnretainedValue() as Data

            guard isNonLatin(layoutData) else { continue }

            guard let idRaw = TISGetInputSourceProperty(src, kTISPropertyInputSourceID) else { continue }
            let id = Unmanaged<CFString>.fromOpaque(idRaw).takeUnretainedValue() as String
            guard id != "com.apple.keylayout.US" else { continue }

            guard let langRaw = TISGetInputSourceProperty(src, kTISPropertyInputSourceLanguages),
                  let language = (Unmanaged<CFArray>.fromOpaque(langRaw).takeUnretainedValue() as NSArray).firstObject as? String
            else { continue }

            let displayName: String
            if let nameRaw = TISGetInputSourceProperty(src, kTISPropertyLocalizedName) {
                displayName = Unmanaged<CFString>.fromOpaque(nameRaw).takeUnretainedValue() as String
            } else {
                displayName = id
            }

            results.append(LayoutInfo(id: id, displayName: displayName, language: language))
            _maps[id] = buildMaps(nonLatinData: layoutData, usData: usData)
        }

        _layouts = results
        return results
    }

    static func bestMaps(for text: String, enabledLayoutIDs: Set<String>? = nil) -> LayoutMaps? {
        let layouts = availableLayouts()
        let candidates = enabledLayoutIDs.map { ids in layouts.filter { ids.contains($0.id) } } ?? layouts

        var best: LayoutMaps? = nil
        var bestScore = 0

        for layout in candidates {
            guard let maps = _maps[layout.id] else { continue }
            let score = text.reduce(0) { $0 + (maps.toEnglish[$1] != nil ? 1 : 0) }
            if score > bestScore { bestScore = score; best = maps }
        }

        return bestScore > 0 ? best : nil
    }

    // MARK: - Private

    private static func isNonLatin(_ data: Data) -> Bool {
        let kbdType = UInt32(LMGetKbdType())
        return data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> Bool in
            guard let base = ptr.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return false }
            for keyCode in UInt16(4)..<UInt16(52) {
                var deadKey: UInt32 = 0, length: Int = 0
                var chars = [UniChar](repeating: 0, count: 8)
                guard UCKeyTranslate(base, keyCode, UInt16(kUCKeyActionDown), 0, kbdType,
                                     OptionBits(kUCKeyTranslateNoDeadKeysBit),
                                     &deadKey, 8, &length, &chars) == noErr,
                      length > 0,
                      let scalar = Unicode.Scalar(chars[0]),
                      scalar.value > 0x024F else { continue }
                return true
            }
            return false
        }
    }

    private static func qwertyData() -> Data? {
        // Try both the canonical US id and the ABC alias (used on newer Macs)
        sourceData(id: "com.apple.keylayout.US") ?? sourceData(id: "com.apple.keylayout.ABC")
    }

    private static func sourceData(id: String) -> Data? {
        let props = [kTISPropertyInputSourceID as String: id] as CFDictionary
        // Use includeAllInstalled=true so we can load any layout regardless of whether
        // the user has it enabled in System Settings.
        guard let list = TISCreateInputSourceList(props, true)?.takeRetainedValue(),
              CFArrayGetCount(list) > 0,
              let raw = CFArrayGetValueAtIndex(list, 0),
              let dataRaw = TISGetInputSourceProperty(
                Unmanaged<TISInputSource>.fromOpaque(raw).takeUnretainedValue(),
                kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        return Unmanaged<CFData>.fromOpaque(dataRaw).takeUnretainedValue() as Data
    }

    private static func buildMaps(nonLatinData: Data, usData: Data) -> LayoutMaps {
        let kbdType = UInt32(LMGetKbdType())
        var toEnglish: [Character: Character] = [:]
        var fromEnglish: [Character: Character] = [:]

        nonLatinData.withUnsafeBytes { nlPtr in
            usData.withUnsafeBytes { usPtr in
                guard let nlBase = nlPtr.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self),
                      let usBase = usPtr.baseAddress?.assumingMemoryBound(to: UCKeyboardLayout.self) else { return }

                for keyCode in UInt16(0)..<UInt16(52) {
                    var nlDead: UInt32 = 0, nlLen: Int = 0, usDead: UInt32 = 0, usLen: Int = 0
                    var nlChars = [UniChar](repeating: 0, count: 8)
                    var usChars = [UniChar](repeating: 0, count: 8)

                    guard UCKeyTranslate(nlBase, keyCode, UInt16(kUCKeyActionDown), 0, kbdType,
                                        OptionBits(kUCKeyTranslateNoDeadKeysBit),
                                        &nlDead, 8, &nlLen, &nlChars) == noErr, nlLen > 0,
                          UCKeyTranslate(usBase, keyCode, UInt16(kUCKeyActionDown), 0, kbdType,
                                        OptionBits(kUCKeyTranslateNoDeadKeysBit),
                                        &usDead, 8, &usLen, &usChars) == noErr, usLen > 0
                    else { continue }

                    guard let nlScalar = Unicode.Scalar(nlChars[0]), nlScalar.value > 0x024F,
                          let usScalar = Unicode.Scalar(usChars[0]) else { continue }

                    let nlChar = Character(nlScalar)
                    let usChar = Character(usScalar)

                    toEnglish[nlChar] = usChar
                    fromEnglish[usChar] = nlChar
                    let upper = Character(usChar.uppercased())
                    if upper != usChar { fromEnglish[upper] = nlChar }
                }
            }
        }

        return LayoutMaps(toEnglish: toEnglish, fromEnglish: fromEnglish)
    }
}
