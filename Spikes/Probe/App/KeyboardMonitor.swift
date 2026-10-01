import AppKit
import Carbon
import IOKit
import IOKit.hid
import Observation

struct KeyboardDevice: Identifiable, Hashable {
    let id: String
    let product: String
    let manufacturer: String
    let transport: String
    let serial: String
    let builtIn: Bool
    let vendorID: Int
    let productID: Int
    let locationID: Int
}

struct InputSourceOption: Identifiable, Hashable {
    let id: String
    let name: String
}

struct KeystrokeRecord: Identifiable {
    let id = UUID()
    let device: String
    let firstAfterSwitch: Bool
    let expected: String?
    let produced: String

    var correct: Bool? {
        expected.map { $0 == produced }
    }
}

/// Spike S4. Device arrival and removal come from the IOKit registry, which
/// needs no permission. Knowing which keyboard is typing needs Input Monitoring:
/// the HID callback keeps only the device identity and discards the key itself.
@Observable
final class KeyboardMonitor {
    var devices: [KeyboardDevice] = []
    var log: [String] = []
    var activeDevice = "—"
    var currentSource = "—"
    var sources: [InputSourceOption] = []
    var mapping: [String: String] = [:]
    var autoSwitch = false
    var switchLatencies: [Double] = []
    var keystrokes: [KeystrokeRecord] = []
    var perContextInput = "?"
    var hidStatus = "non avviato"
    var keyEventsSeen = 0

    @ObservationIgnored private var notificationPort: IONotificationPortRef?
    @ObservationIgnored private var manager: IOHIDManager?
    @ObservationIgnored private var lastKeyDevice: String?
    @ObservationIgnored private var lastKeyTime: TimeInterval = 0
    @ObservationIgnored private var switchStartedAt: TimeInterval?
    @ObservationIgnored private var awaitingFirstKey: Set<String> = []
    @ObservationIgnored private var keyMonitor: Any?

    init() {
        loadSources()
        refreshCurrentSource()
        readPerContextSetting()
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String), object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            refreshCurrentSource()
            if let start = switchStartedAt {
                switchLatencies.append((ProcessInfo.processInfo.systemUptime - start) * 1_000)
                switchStartedAt = nil
            }
        }
        startDeviceWatch()
    }

    // MARK: Devices (no permission)

    private static func matching() -> CFMutableDictionary {
        let dictionary = IOServiceMatching(kIOHIDDeviceKey)!
        let mutable = dictionary as NSMutableDictionary
        mutable[kIOHIDPrimaryUsagePageKey] = kHIDPage_GenericDesktop
        mutable[kIOHIDPrimaryUsageKey] = kHIDUsage_GD_Keyboard
        return dictionary
    }

    private func startDeviceWatch() {
        guard let port = IONotificationPortCreate(kIOMainPortDefault) else {
            append("IONotificationPortCreate non disponibile")
            return
        }
        notificationPort = port
        CFRunLoopAddSource(CFRunLoopGetMain(), IONotificationPortGetRunLoopSource(port).takeUnretainedValue(), .defaultMode)
        let context = Unmanaged.passUnretained(self).toOpaque()

        var arrivals: io_iterator_t = 0
        IOServiceAddMatchingNotification(port, kIOFirstMatchNotification, Self.matching(), { context, iterator in
            Unmanaged<KeyboardMonitor>.fromOpaque(context!).takeUnretainedValue().drain(iterator, arrived: true)
        }, context, &arrivals)
        drain(arrivals, arrived: true)

        var removals: io_iterator_t = 0
        IOServiceAddMatchingNotification(port, kIOTerminatedNotification, Self.matching(), { context, iterator in
            Unmanaged<KeyboardMonitor>.fromOpaque(context!).takeUnretainedValue().drain(iterator, arrived: false)
        }, context, &removals)
        drain(removals, arrived: false)
    }

    private func drain(_ iterator: io_iterator_t, arrived: Bool) {
        while case let service = IOIteratorNext(iterator), service != 0 {
            let device = Self.device(from: service)
            IOObjectRelease(service)
            if arrived {
                if !devices.contains(where: { $0.id == device.id }) { devices.append(device) }
                append("collegata: \(device.product) (\(device.transport))")
            } else {
                devices.removeAll { $0.id == device.id }
                append("scollegata: \(device.product)")
            }
        }
    }

    private static func device(from service: io_service_t) -> KeyboardDevice {
        func value(_ key: String) -> Any? {
            IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
        }
        let vendor = value(kIOHIDVendorIDKey) as? Int ?? 0
        let product = value(kIOHIDProductIDKey) as? Int ?? 0
        let location = value(kIOHIDLocationIDKey) as? Int ?? 0
        return KeyboardDevice(
            id: "\(vendor):\(product):\(location)",
            product: value(kIOHIDProductKey) as? String ?? "sconosciuta",
            manufacturer: value(kIOHIDManufacturerKey) as? String ?? "",
            transport: value(kIOHIDTransportKey) as? String ?? "",
            serial: (value(kIOHIDSerialNumberKey) as? String).map { $0.isEmpty ? "assente" : "presente" } ?? "assente",
            builtIn: (value(kIOHIDBuiltInKey) as? Bool) ?? false,
            vendorID: vendor, productID: product, locationID: location
        )
    }

    // MARK: Activity (Input Monitoring)

    func startActivityMonitor() {
        guard manager == nil else { return }
        if IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) != kIOHIDAccessTypeGranted {
            _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        }
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, [kIOHIDPrimaryUsagePageKey: kHIDPage_GenericDesktop,
                                                kIOHIDPrimaryUsageKey: kHIDUsage_GD_Keyboard] as CFDictionary)
        IOHIDManagerRegisterInputValueCallback(manager, { context, _, _, value in
            Unmanaged<KeyboardMonitor>.fromOpaque(context!).takeUnretainedValue().handle(value)
        }, Unmanaged.passUnretained(self).toOpaque())
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        hidStatus = result == kIOReturnSuccess ? "attivo" : String(format: "errore 0x%08x", result)
        self.manager = manager
    }

    private func handle(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        guard IOHIDElementGetUsagePage(element) == UInt32(kHIDPage_KeyboardOrKeypad),
              IOHIDValueGetIntegerValue(value) == 1 else { return }
        let usage = IOHIDElementGetUsage(element)
        guard usage >= 4 && usage <= 231 else { return }
        // The key itself is not kept: only which device produced it.
        keyEventsSeen += 1
        let device = IOHIDElementGetDevice(element)
        func number(_ key: String) -> Int { IOHIDDeviceGetProperty(device, key as CFString) as? Int ?? 0 }
        let id = "\(number(kIOHIDVendorIDKey)):\(number(kIOHIDProductIDKey)):\(number(kIOHIDLocationIDKey))"
        let now = ProcessInfo.processInfo.systemUptime
        lastKeyTime = now
        guard id != lastKeyDevice else { return }
        lastKeyDevice = id
        activeDevice = devices.first { $0.id == id }?.product ?? id
        if autoSwitch, let target = mapping[id] {
            awaitingFirstKey.insert(id)
            select(target, startedAt: now)
        }
    }

    // MARK: Input sources

    private func loadSources() {
        let filter = [kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource as String,
                      kTISPropertyInputSourceIsSelectCapable as String: true] as CFDictionary
        let list = (TISCreateInputSourceList(filter, false).takeRetainedValue() as NSArray) as! [TISInputSource]
        sources = list.compactMap { source in
            guard Self.string(source, kTISPropertyInputSourceType) == (kTISTypeKeyboardLayout as String),
                  let id = Self.string(source, kTISPropertyInputSourceID),
                  let name = Self.string(source, kTISPropertyLocalizedName) else { return nil }
            return InputSourceOption(id: id, name: name)
        }
    }

    private static func string(_ source: TISInputSource, _ key: CFString) -> String? {
        guard let pointer = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
    }

    private func refreshCurrentSource() {
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        currentSource = Self.string(source, kTISPropertyLocalizedName) ?? "?"
    }

    private func select(_ sourceID: String, startedAt: TimeInterval) {
        let filter = [kTISPropertyInputSourceID as String: sourceID] as CFDictionary
        guard let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource],
              let source = list.first else { return }
        switchStartedAt = startedAt
        let status = TISSelectInputSource(source)
        if status != noErr { append("TISSelectInputSource: errore \(status)") }
    }

    private func readPerContextSetting() {
        let value = CFPreferencesCopyValue("AppleGlobalTextInputProperties" as CFString, "com.apple.HIToolbox" as CFString,
                                           kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? [String: Any]
        perContextInput = (value?["TextInputGlobalPropertyPerContextInput"] as? Bool) == true ? "attivo" : "disattivo"
    }

    // MARK: First-keystroke test

    /// Watches the key right of L (`;` on U.S. layouts, `ò` on Italian ones).
    func startKeystrokeTest() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.record(event)
            return event
        }
    }

    func resetKeystrokeTest() {
        keystrokes.removeAll()
        switchLatencies.removeAll()
        awaitingFirstKey.removeAll()
    }

    private func record(_ event: NSEvent) {
        guard event.keyCode == 41, let device = lastKeyDevice,
              ProcessInfo.processInfo.systemUptime - lastKeyTime < 0.3 else { return }
        let first = awaitingFirstKey.remove(device) != nil
        keystrokes.append(KeystrokeRecord(
            device: devices.first { $0.id == device }?.product ?? device,
            firstAfterSwitch: first,
            expected: Self.expectedCharacter(for: mapping[device]),
            produced: event.characters ?? ""
        ))
    }

    private static func expectedCharacter(for sourceID: String?) -> String? {
        guard let sourceID else { return nil }
        if sourceID.localizedCaseInsensitiveContains("italian") { return "ò" }
        if sourceID.hasSuffix(".US") || sourceID.hasSuffix(".USExtended") || sourceID.hasSuffix(".ABC") { return ";" }
        return nil
    }

    // MARK: Results

    private func append(_ line: String) {
        let time = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        log.append("\(time) \(line)")
    }

    var summary: [String: Any] {
        let judged = keystrokes.filter { $0.correct != nil }
        let firsts = judged.filter(\.firstAfterSwitch)
        let others = judged.filter { !$0.firstAfterSwitch }
        let sorted = switchLatencies.sorted()
        return [
            "devices": devices.map { ["product": $0.product, "manufacturer": $0.manufacturer, "transport": $0.transport,
                                      "built_in": $0.builtIn, "serial": $0.serial, "vendor_id": $0.vendorID, "product_id": $0.productID] },
            "arrival_removal_events": log.count,
            "input_monitoring": Permissions.inputMonitoring,
            "hid_manager": hidStatus,
            "key_events_seen": keyEventsSeen,
            "switches_measured": sorted.count,
            "switch_latency_median_ms": sorted.isEmpty ? -1 : sorted[sorted.count / 2],
            "switch_latency_max_ms": sorted.last ?? -1,
            "first_after_switch_wrong": "\(firsts.filter { $0.correct == false }.count)/\(firsts.count)",
            "other_keystrokes_wrong": "\(others.filter { $0.correct == false }.count)/\(others.count)",
            "per_context_input_source": perContextInput,
            "mapping": mapping.map { device, source in "\(devices.first { $0.id == device }?.product ?? device) → \(source)" },
        ]
    }
}
