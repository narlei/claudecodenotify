import AppKit
import Carbon.HIToolbox

/// Global hotkeys for profile switching, via Carbon RegisterEventHotKey —
/// works from a menu bar app and needs no Accessibility permission.
@MainActor
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    /// Fired with the profile id whose hotkey was pressed.
    var onHotKey: ((UUID) -> Void)?

    private static let signature: OSType = 0x43_43_4E_50 // 'CCNP'
    private var eventHandler: EventHandlerRef?
    private var registered: [UInt32: (ref: EventHotKeyRef, profileID: UUID)] = [:]
    private var nextID: UInt32 = 1

    /// Replaces all registrations with the given profiles' hotkeys.
    /// Returns the profile ids whose registration failed (combination taken).
    @discardableResult
    func register(profiles: [Profile]) -> Set<UUID> {
        installHandlerIfNeeded()
        unregisterAll()

        var failed: Set<UUID> = []
        for profile in profiles {
            guard let hotkey = profile.hotkey else { continue }
            let id = nextID
            nextID += 1
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(hotkey.keyCode, hotkey.modifiers,
                                             EventHotKeyID(signature: Self.signature, id: id),
                                             GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref {
                registered[id] = (ref, profile.id)
            } else {
                failed.insert(profile.id)
            }
        }
        return failed
    }

    func unregisterAll() {
        for (_, entry) in registered { UnregisterEventHotKey(entry.ref) }
        registered.removeAll()
    }

    // MARK: - Carbon plumbing

    private func installHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return noErr }
            var hkID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            let center = Unmanaged<HotKeyCenter>.fromOpaque(userData).takeUnretainedValue()
            Task { @MainActor in center.handlePress(id: hkID.id) }
            return noErr
        }, 1, &spec, selfPtr, &eventHandler)
    }

    private func handlePress(id: UInt32) {
        guard let entry = registered[id] else { return }
        onHotKey?(entry.profileID)
    }
}

extension Profile.Hotkey {
    /// Converts AppKit modifier flags (from the recorder's NSEvent) to Carbon's mask.
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var mods: UInt32 = 0
        if flags.contains(.command) { mods |= UInt32(cmdKey) }
        if flags.contains(.option)  { mods |= UInt32(optionKey) }
        if flags.contains(.control) { mods |= UInt32(controlKey) }
        if flags.contains(.shift)   { mods |= UInt32(shiftKey) }
        return mods
    }

    /// Human-readable form for menus/preferences, e.g. "⌃⌥⌘P".
    var display: String {
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey) != 0  { s += "⌥" }
        if modifiers & UInt32(shiftKey) != 0   { s += "⇧" }
        if modifiers & UInt32(cmdKey) != 0     { s += "⌘" }
        return s + Self.keyName(forCode: keyCode)
    }

    /// Letter/symbol for a Carbon key code using the current keyboard layout.
    static func keyName(forCode keyCode: UInt32) -> String {
        let special: [Int: String] = [
            kVK_Return: "↩", kVK_Tab: "⇥", kVK_Space: "Space", kVK_Escape: "⎋",
            kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
            kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
            kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5",
            kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10",
            kVK_F11: "F11", kVK_F12: "F12"
        ]
        if let name = special[Int(keyCode)] { return name }
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return "key\(keyCode)"
        }
        let data = Unmanaged<CFData>.fromOpaque(layoutData).takeUnretainedValue() as Data
        return data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> String in
            guard let layout = ptr.bindMemory(to: UCKeyboardLayout.self).baseAddress else {
                return "key\(keyCode)"
            }
            var deadKeyState: UInt32 = 0
            var chars = [UniChar](repeating: 0, count: 4)
            var length = 0
            let err = UCKeyTranslate(layout, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0,
                                     UInt32(LMGetKbdType()), UInt32(kUCKeyTranslateNoDeadKeysBit),
                                     &deadKeyState, chars.count, &length, &chars)
            guard err == noErr, length > 0 else { return "key\(keyCode)" }
            return String(utf16CodeUnits: chars, count: length).uppercased()
        }
    }
}
