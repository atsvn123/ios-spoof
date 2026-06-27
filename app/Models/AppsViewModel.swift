import Foundation
import UIKit

struct AppInfo: Identifiable, Hashable {
    let id: String  // bundleID
    let bundleID: String
    let name: String
    let icon: UIImage?
    let isSystemApp: Bool
}

final class AppsViewModel: ObservableObject {
    static let shared = AppsViewModel()

    @Published var apps: [AppInfo] = []
    @Published var selectedApps: Set<String> = []
    @Published var isLoading = false

    private init() {
        loadSelected()
        loadApps()
    }

    func loadApps() {
        guard !isLoading else { return }
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let apps = self.fetchInstalledApps()
            DispatchQueue.main.async {
                self.apps = apps
                self.isLoading = false
            }
        }
    }

    func loadSelected() {
        let path = prefsPath
        guard let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
              let bundles = dict["targetBundles"] as? [String] else {
            selectedApps = []
            return
        }
        selectedApps = Set(bundles)
    }

    func isSelected(_ app: AppInfo) -> Bool {
        selectedApps.contains(app.bundleID)
    }

    func toggle(_ app: AppInfo) {
        if selectedApps.contains(app.bundleID) {
            selectedApps.remove(app.bundleID)
        } else {
            selectedApps.insert(app.bundleID)
        }
        saveSelected()
    }

    func selectAll() {
        selectedApps = Set(apps.map { $0.bundleID })
        saveSelected()
    }

    func select(_ apps: [AppInfo]) {
        selectedApps.formUnion(apps.map { $0.bundleID })
        saveSelected()
    }

    func deselectAll() {
        selectedApps.removeAll()
        saveSelected()
    }

    private func saveSelected() {
        let path = prefsPath
        var dict = (NSDictionary(contentsOfFile: path) as? [String: Any]) ?? [:]
        dict["targetBundles"] = Array(selectedApps).sorted()
        (dict as NSDictionary).write(toFile: path, atomically: true)

        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName("com.iosspoof.tweak.prefs.changed" as CFString),
            nil, nil, true
        )
    }

    private var prefsPath: String {
        let fm = FileManager.default
        if fm.fileExists(atPath: "/var/jb/var/mobile/Library/Preferences") {
            return "/var/jb/var/mobile/Library/Preferences/com.iosspoof.tweak.plist"
        }
        return "/var/mobile/Library/Preferences/com.iosspoof.tweak.plist"
    }

    // MARK: - LSApplicationWorkspace (private API)

    private func fetchInstalledApps() -> [AppInfo] {
        let selector = NSSelectorFromString("defaultWorkspace")
        guard let wsClass = NSClassFromString("LSApplicationWorkspace") as? NSObject.Type,
              wsClass.responds(to: selector),
              let workspace = wsClass.perform(selector)?.takeUnretainedValue() else {
            return []
        }

        let allAppsSelector = NSSelectorFromString("allInstalledApplications")
        guard workspace.responds(to: allAppsSelector),
              let nsApps = workspace.perform(allAppsSelector)?.takeUnretainedValue() as? [NSObject] else {
            return []
        }

        var result: [AppInfo] = []
        for app in nsApps {
            guard let bundleID = app.value(forKey: "applicationIdentifier") as? String,
                  bundleID != "com.iosspoof.app" else { continue }

            let name: String
            if let cn = app.value(forKey: "localizedName") as? String {
                name = cn
            } else {
                name = bundleID
            }

            let isSystem: Bool
            if let appType = app.value(forKey: "applicationType") as? String {
                isSystem = appType == "System"
            } else {
                isSystem = false
            }

            var icon: UIImage? = nil
            if let iconData = app.value(forKey: "iconData") as? Data {
                icon = UIImage(data: iconData)
            } else if let iconPath = app.value(forKey: "privateDocumentIconPath") as? String {
                icon = UIImage(contentsOfFile: iconPath)
            }

            result.append(AppInfo(
                id: bundleID, bundleID: bundleID, name: name,
                icon: icon, isSystemApp: isSystem
            ))
        }

        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
