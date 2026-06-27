import Foundation
import Combine

final class PresetManager: ObservableObject {
    static let shared = PresetManager()

    @Published var selectedProductType: String = ""
    @Published var selectedPreset: DevicePreset?

    private init() {
        loadSelectedPreset()
    }

    func loadSelectedPreset() {
        guard let dict = NSDictionary(contentsOfFile: prefsPath) as? [String: Any],
              let pt = dict["productType"] as? String else {
            selectedProductType = ""
            selectedPreset = nil
            return
        }
        selectedProductType = pt
        if pt == "random" {
            selectedPreset = DevicePresets.random()
        } else {
            selectedPreset = DevicePresets.preset(for: pt)
        }
    }

    private var prefsPath: String {
        let fm = FileManager.default
        if fm.fileExists(atPath: "/var/jb/var/mobile/Library/Preferences") {
            return "/var/jb/var/mobile/Library/Preferences/com.iosspoof.tweak.plist"
        }
        return "/var/mobile/Library/Preferences/com.iosspoof.tweak.plist"
    }
}
