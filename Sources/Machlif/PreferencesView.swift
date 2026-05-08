import SwiftUI

struct PreferencesView: View {
    @State private var layouts: [LayoutInfo] = []
    @State private var enabledIDs: Set<String>? = LanguagePreferences.enabledLayoutIDs
    @State private var interval: Double = LanguagePreferences.doubleTapInterval
    @State private var trigger: TriggerConfig = LanguagePreferences.triggerConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            triggerSection
                .padding()
            Divider()
            layoutsSection
                .padding()
            Divider()
            intervalSection
                .padding()
        }
        .frame(width: 360)
        .onAppear { layouts = KeyboardLayoutDetector.availableLayouts() }
    }

    // MARK: - Trigger

    private var triggerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Trigger").font(.headline)

            Picker("", selection: $trigger.mode) {
                Text("Double-tap modifier").tag(TriggerConfig.Mode.doubleTap)
                Text("Keyboard shortcut").tag(TriggerConfig.Mode.hotkey)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if trigger.mode == .doubleTap {
                HStack {
                    Text("Modifier key")
                        .foregroundColor(.secondary)
                        .font(.callout)
                    Spacer()
                    Picker("", selection: $trigger.doubleTapModifier) {
                        ForEach(ModifierKey.allCases) { key in
                            Text(key.displayName).tag(key)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 150)
                }
            } else {
                ShortcutRecorderView(
                    keyCode: $trigger.hotkeyKeyCode,
                    modifierFlags: $trigger.hotkeyModifierFlags,
                    displayName: $trigger.hotkeyDisplayName
                )
                .frame(height: 28)
                Text("The shortcut also reaches other apps — pick a combination nothing else uses.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .onChange(of: trigger) { newValue in
            LanguagePreferences.triggerConfig = newValue
        }
    }

    // MARK: - Layouts

    private var layoutsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Keyboard Layouts").font(.headline)
            Text("Which non-Latin layouts should trigger conversion?")
                .font(.caption)
                .foregroundColor(.secondary)

            if layouts.isEmpty {
                Text("No non-Latin keyboard layouts found on this system.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Toggle(isOn: allEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("All layouts").fontWeight(.medium)
                        Text("Auto-pick the best match")
                            .font(.caption).foregroundColor(.secondary)
                    }
                }

                if enabledIDs != nil {
                    Divider()
                    ForEach(layouts) { layout in
                        Toggle(isOn: bindingFor(layout)) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(layout.displayName)
                                Text(layout.language)
                                    .font(.caption).foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Interval

    private var intervalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Double-tap Speed").font(.headline)
            HStack(spacing: 8) {
                Text("Fast").font(.caption).foregroundColor(.secondary)
                Slider(value: $interval, in: 0.15...0.7, step: 0.05)
                    .onChange(of: interval) { value in
                        LanguagePreferences.doubleTapInterval = value
                    }
                Text("Slow").font(.caption).foregroundColor(.secondary)
            }
            Text(String(format: "%.2f s between taps", interval))
                .font(.caption).foregroundColor(.secondary)
        }
    }

    // MARK: - Bindings

    private var allEnabled: Binding<Bool> {
        Binding(
            get: { enabledIDs == nil },
            set: { all in
                enabledIDs = all ? nil : Set(layouts.map(\.id))
                LanguagePreferences.enabledLayoutIDs = enabledIDs
            }
        )
    }

    private func bindingFor(_ layout: LayoutInfo) -> Binding<Bool> {
        Binding(
            get: { enabledIDs?.contains(layout.id) ?? true },
            set: { on in
                var ids = enabledIDs ?? Set(layouts.map(\.id))
                if on { ids.insert(layout.id) } else { ids.remove(layout.id) }
                enabledIDs = ids.count == layouts.count ? nil : ids
                LanguagePreferences.enabledLayoutIDs = enabledIDs
            }
        )
    }
}
