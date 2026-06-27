import Foundation
import Combine

final class SpoofConfig: ObservableObject {
    static let shared = SpoofConfig()

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Published Properties
    @Published var enabled = false
    @Published var productType = ""
    @Published var randomizeOnLaunch = false
    @Published var targetBundles: [String] = []

    // Carrier
    @Published var carrierName = ""
    @Published var carrierMCC = ""
    @Published var carrierMNC = ""
    @Published var carrierISO = ""
    @Published var radioTech = ""

    // Geo
    @Published var geoEnabled = false
    @Published var latitude = 21.0285
    @Published var longitude = 105.8542
    @Published var altitude = 20.0
    @Published var horizontalAccuracy = 5.0
    @Published var heading = 0.0

    // Proxy
    @Published var proxyEnabled = false
    @Published var proxyType = "socks5"
    @Published var proxyHost = ""
    @Published var proxyPort = 1080
    @Published var proxyUser = ""
    @Published var proxyPass = ""
    @Published var proxyUDP = false

    // Anti-detect
    @Published var hideProxy = true
    @Published var hideVPN = true
    @Published var hideJailbreak = true

    // ID Spoofing
    @Published var spoofIDFA = true
    @Published var spoofIDFV = true
    @Published var spoofBattery = true

    // MARK: - Prefs Path
    private var prefsPath: String {
        let fm = FileManager.default
        if fm.fileExists(atPath: "/var/jb/var/mobile/Library/Preferences") {
            return "/var/jb/var/mobile/Library/Preferences/com.iosspoof.tweak.plist"
        }
        return "/var/mobile/Library/Preferences/com.iosspoof.tweak.plist"
    }

    // MARK: - Init
    private init() {
        load()
        // Auto-save with debounce (0.5s after last change)
        objectWillChange
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.save()
            }
            .store(in: &cancellables)
    }

    // MARK: - Load
    func load() {
        guard let dict = NSDictionary(contentsOfFile: prefsPath) as? [String: Any] else { return }

        enabled = (dict["enabled"] as? Bool) ?? false
        productType = (dict["productType"] as? String) ?? ""
        randomizeOnLaunch = (dict["randomizeOnLaunch"] as? Bool) ?? false

        if let tb = dict["targetBundles"] as? [String] {
            targetBundles = tb
        } else if let tbStr = dict["targetBundles"] as? String {
            targetBundles = tbStr.components(separatedBy: ",")
        }

        carrierName = (dict["carrierName"] as? String) ?? ""
        carrierMCC = (dict["carrierMCC"] as? String) ?? ""
        carrierMNC = (dict["carrierMNC"] as? String) ?? ""
        carrierISO = (dict["carrierISO"] as? String) ?? ""
        radioTech = (dict["radioTech"] as? String) ?? ""

        geoEnabled = (dict["geoEnabled"] as? Bool) ?? false
        latitude = (dict["latitude"] as? Double) ?? 21.0285
        longitude = (dict["longitude"] as? Double) ?? 105.8542
        altitude = (dict["altitude"] as? Double) ?? 20.0
        horizontalAccuracy = (dict["horizontalAccuracy"] as? Double) ?? 5.0
        heading = (dict["heading"] as? Double) ?? 0.0

        proxyEnabled = (dict["proxyEnabled"] as? Bool) ?? false
        proxyType = (dict["proxyType"] as? String) ?? "socks5"
        proxyHost = (dict["proxyHost"] as? String) ?? ""
        proxyPort = (dict["proxyPort"] as? Int) ?? 1080
        proxyUser = (dict["proxyUser"] as? String) ?? ""
        proxyPass = (dict["proxyPass"] as? String) ?? ""
        proxyUDP = (dict["proxyUDP"] as? Bool) ?? false

        hideProxy = (dict["hideProxy"] as? Bool) ?? true
        hideVPN = (dict["hideVPN"] as? Bool) ?? true
        hideJailbreak = (dict["hideJailbreak"] as? Bool) ?? true

        spoofIDFA = (dict["spoofIDFA"] as? Bool) ?? true
        spoofIDFV = (dict["spoofIDFV"] as? Bool) ?? true
        spoofBattery = (dict["spoofBattery"] as? Bool) ?? true
    }

    // MARK: - Save
    func save() {
        var dict: [String: Any] = [:]
        dict["enabled"] = enabled
        dict["productType"] = productType
        dict["randomizeOnLaunch"] = randomizeOnLaunch
        dict["targetBundles"] = targetBundles

        dict["carrierName"] = carrierName
        dict["carrierMCC"] = carrierMCC
        dict["carrierMNC"] = carrierMNC
        dict["carrierISO"] = carrierISO
        dict["radioTech"] = radioTech

        dict["geoEnabled"] = geoEnabled
        dict["latitude"] = latitude
        dict["longitude"] = longitude
        dict["altitude"] = altitude
        dict["horizontalAccuracy"] = horizontalAccuracy
        dict["heading"] = heading

        dict["proxyEnabled"] = proxyEnabled
        dict["proxyType"] = proxyType
        dict["proxyHost"] = proxyHost
        dict["proxyPort"] = proxyPort
        dict["proxyUser"] = proxyUser
        dict["proxyPass"] = proxyPass
        dict["proxyUDP"] = proxyUDP

        dict["hideProxy"] = hideProxy
        dict["hideVPN"] = hideVPN
        dict["hideJailbreak"] = hideJailbreak

        dict["spoofIDFA"] = spoofIDFA
        dict["spoofIDFV"] = spoofIDFV
        dict["spoofBattery"] = spoofBattery

        let nsDict = dict as NSDictionary
        nsDict.write(toFile: prefsPath, atomically: true)

        // Notify tweak to reload
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName("com.iosspoof.tweak.prefs.changed" as CFString),
            nil, nil, true
        )
    }

    // MARK: - Reset
    func resetAll() {
        enabled = false
        productType = ""
        randomizeOnLaunch = false
        targetBundles = []
        carrierName = ""
        carrierMCC = ""
        carrierMNC = ""
        carrierISO = ""
        radioTech = ""
        geoEnabled = false
        latitude = 21.0285
        longitude = 105.8542
        altitude = 20.0
        horizontalAccuracy = 5.0
        heading = 0.0
        proxyEnabled = false
        proxyHost = ""
        proxyPort = 1080
        proxyUser = ""
        proxyPass = ""
        proxyUDP = false
        hideProxy = true
        hideVPN = true
        hideJailbreak = true
        spoofIDFA = true
        spoofIDFV = true
        spoofBattery = true
        save()
    }

    // MARK: - IDs Path
    private var idsPath: String {
        let fm = FileManager.default
        if fm.fileExists(atPath: "/var/jb/var/mobile/Library/Preferences") {
            return "/var/jb/var/mobile/Library/Preferences/com.iosspoof.tweak.ids.plist"
        }
        return "/var/mobile/Library/Preferences/com.iosspoof.tweak.ids.plist"
    }

    // MARK: - Cached IDs (per-bundle, stored by tweak)
    func cachedIDs(for bundleID: String) -> [String: String]? {
        guard let dict = NSDictionary(contentsOfFile: idsPath) as? [String: Any],
              let per = dict[bundleID] as? [String: Any] else { return nil }
        var result: [String: String] = [:]
        if let v = per["udid"] as? String { result["udid"] = v }
        if let v = per["serial"] as? String { result["serial"] = v }
        if let v = per["ecid"] as? String { result["ecid"] = v }
        if let v = per["imei"] as? String { result["imei"] = v }
        if let v = per["mac"] as? String { result["mac"] = v }
        if let v = per["idfa"] as? String { result["idfa"] = v }
        return result.isEmpty ? nil : result
    }

    func allCachedIDs() -> [String: [String: String]] {
        guard let dict = NSDictionary(contentsOfFile: idsPath) as? [String: Any] else { return [:] }
        var result: [String: [String: String]] = [:]
        for (bundleID, val) in dict {
            guard let per = val as? [String: Any] else { continue }
            var ids: [String: String] = [:]
            for key in ["udid", "serial", "ecid", "imei", "mac", "idfa"] {
                if let v = per[key] as? String { ids[key] = v }
            }
            if !ids.isEmpty { result[bundleID] = ids }
        }
        return result
    }

    func clearIDCache() {
        try? FileManager.default.removeItem(atPath: idsPath)
    }

    // MARK: - Randomize All
    func randomizeAll() {
        // Random device
        let preset = DevicePresets.random()
        productType = preset.productType

        // Enable randomize on launch (new IDs each time)
        randomizeOnLaunch = true

        // Clear cached IDs so tweak generates fresh ones
        clearIDCache()

        // Random carrier from preset
        carrierName = preset.carrierName
        carrierMCC = preset.carrierMCC
        carrierMNC = preset.carrierMNC
        carrierISO = preset.carrierISO
        radioTech = preset.radioTech

        // Random GPS — pick from preset's default or random city
        let cities: [(String, Double, Double)] = [
            ("Hà Nội", 21.0285, 105.8542),
            ("TP.HCM", 10.8231, 106.6297),
            ("Đà Nẵng", 16.0471, 108.2068),
            ("Hải Phòng", 20.8449, 106.6881),
            ("Cần Thơ", 10.0452, 105.7469),
            ("New York", 40.7128, -74.0060),
            ("London", 51.5074, -0.1278),
            ("Tokyo", 35.6762, 139.6503),
            ("Singapore", 1.3521, 103.8198),
            ("Paris", 48.8566, 2.3522),
            ("Sydney", -33.8688, 151.2093),
            ("Berlin", 52.5200, 13.4050),
        ]
        let city = cities.randomElement()!
        latitude = city.1
        longitude = city.2
        altitude = Double.random(in: 5...50)
        horizontalAccuracy = Double.random(in: 3...15)
        heading = Double.random(in: 0...359)

        // Enable everything
        enabled = true
        geoEnabled = true
        spoofIDFA = true
        spoofIDFV = true
        spoofBattery = true
        hideProxy = true
        hideVPN = true
        hideJailbreak = true

        save()
    }

    // MARK: - Respring
    func respring() {
        let killallPath = access("/var/jb/usr/bin/killall", 0) == 0 ? "/var/jb/usr/bin/killall" : "/usr/bin/killall"
        let pidptr = UnsafeMutablePointer<pid_t>.allocate(capacity: 1)
        defer { pidptr.deallocate() }
        var args: [UnsafeMutablePointer<CChar>?] = [
            strdup(killallPath),
            strdup("-9"),
            strdup("SpringBoard"),
            nil
        ]
        defer { for i in 0..<3 { free(args[i]) } }
        posix_spawn(pidptr, killallPath, nil, nil, args, environ)
    }

    // MARK: - Computed
    var resolvedPreset: DevicePreset? {
        if productType.isEmpty || productType == "random" {
            return DevicePresets.random()
        }
        return DevicePresets.preset(for: productType)
    }

    var selectedModelName: String {
        if productType.isEmpty || productType == "random" {
            return "Ngẫu nhiên"
        }
        if let preset = DevicePresets.preset(for: productType) {
            return preset.marketingName
        }
        return productType
    }

    var marketingName: String {
        DevicePresets.preset(for: productType)?.marketingName ?? productType
    }

    var hardwareModel: String {
        DevicePresets.preset(for: productType)?.hardwareModel ?? "—"
    }

    var cpuArchitecture: String {
        DevicePresets.preset(for: productType)?.cpuArchitecture ?? "arm64e"
    }

    var screenWidth: Int {
        DevicePresets.preset(for: productType)?.screenWidth ?? 0
    }

    var screenHeight: Int {
        DevicePresets.preset(for: productType)?.screenHeight ?? 0
    }

    var screenScale: Int {
        DevicePresets.preset(for: productType)?.screenScale ?? 3
    }

    var screenInches: Double {
        DevicePresets.preset(for: productType)?.screenInches ?? 0
    }

    var ppi: Int {
        DevicePresets.preset(for: productType)?.ppi ?? 0
    }
}
