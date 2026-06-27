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
        $enabled
            .merge(with: $productType)
            .merge(with: $randomizeOnLaunch)
            .merge(with: $carrierName)
            .merge(with: $carrierMCC)
            .merge(with: $carrierMNC)
            .merge(with: $carrierISO)
            .merge(with: $radioTech)
            .merge(with: $geoEnabled)
            .merge(with: $latitude)
            .merge(with: $longitude)
            .merge(with: $altitude)
            .merge(with: $horizontalAccuracy)
            .merge(with: $heading)
            .merge(with: $proxyEnabled)
            .merge(with: $proxyType)
            .merge(with: $proxyHost)
            .merge(with: $proxyPort)
            .merge(with: $proxyUser)
            .merge(with: $proxyPass)
            .merge(with: $proxyUDP)
            .merge(with: $hideProxy)
            .merge(with: $hideVPN)
            .merge(with: $hideJailbreak)
            .merge(with: $spoofIDFA)
            .merge(with: $spoofIDFV)
            .merge(with: $spoofBattery)
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

    // MARK: - Computed
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
