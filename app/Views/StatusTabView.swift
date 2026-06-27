import SwiftUI

struct StatusTabView: View {
    @StateObject private var config = SpoofConfig.shared
    @State private var showRandomizeConfirm = false
    @State private var showRespringConfirm = false
    @State private var hasIDCache = false

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Master Status
                Section {
                    HStack {
                        Image(systemName: config.enabled ? "checkmark.shield.fill" : "xmark.shield.fill")
                            .foregroundColor(config.enabled ? .green : .red)
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(config.enabled ? "Đang hoạt động" : "Đã tắt")
                                .font(.headline)
                            Text("\(config.targetBundles.count) app được chọn")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: $config.enabled)
                            .labelsHidden()
                            .tint(.cyan)
                    }
                } header: {
                    Text("Trạng thái")
                } footer: {
                    Text("Bật/tắt spoofing toàn bộ. Chỉ ảnh hưởng đến app đã chọn trong tab Apps.")
                }

                // MARK: - Randomize All
                Section {
                    Button {
                        showRandomizeConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "shuffle.circle.fill")
                                .foregroundColor(.purple)
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Randomize All")
                                    .fontWeight(.semibold)
                                Text("Sinh ngẫu nhiên toàn bộ thông số")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)

                    Button {
                        showRespringConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .foregroundColor(.orange)
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Respring")
                                    .fontWeight(.semibold)
                                Text("Áp dụng thay đổi")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                }

                // MARK: - Spoofed Device Info
                if let preset = config.resolvedPreset {
                    Section(header: Text("Thiết bị đang spoof")) {
                        InfoRow(label: "Marketing", value: preset.marketingName)
                        InfoRow(label: "Product Type", value: preset.productType)
                        InfoRow(label: "Hardware Model", value: preset.hardwareModel)
                        InfoRow(label: "Model Number", value: preset.modelNumber)
                        InfoRow(label: "Device Class", value: preset.deviceClass)
                        InfoRow(label: "Board ID", value: preset.boardId)
                        InfoRow(label: "Chip ID", value: preset.chipId)
                        InfoRow(label: "CPU", value: preset.cpuArchitecture)
                        InfoRow(label: "Internal Name", value: preset.internalName)
                        InfoRow(label: "Regulatory", value: preset.regulatoryModelNumber)
                        InfoRow(label: "Region", value: preset.regionCode)
                        InfoRow(label: "Color", value: preset.colorCode)
                        InfoRow(label: "Storage", value: "\(preset.capacityGB)GB")
                    }

                    // Screen
                    Section(header: Text("Màn hình")) {
                        InfoRow(label: "Resolution", value: "\(preset.screenWidth) × \(preset.screenHeight)")
                        InfoRow(label: "Scale", value: "\(preset.screenScale)x")
                        InfoRow(label: "Size", value: String(format: "%.1f\"", preset.screenInches))
                        InfoRow(label: "PPI", value: "\(preset.ppi)")
                    }

                    // Battery
                    Section(header: Text("Pin")) {
                        InfoRow(label: "Level", value: "\(Int(preset.batteryLevel * 100))%")
                        InfoRow(label: "State", value: preset.batteryState)
                    }
                }

                // MARK: - Spoofed IDs
                Section(header: Text("Identifiers (đã sinh)")) {
                    if config.randomizeOnLaunch {
                        Label("Random mỗi lần mở app", systemImage: "shuffle")
                            .font(.caption)
                            .foregroundColor(.purple)
                    }

                    if let firstBundle = config.targetBundles.first,
                       let ids = config.cachedIDs(for: firstBundle) {
                        InfoRow(label: "Bundle", value: firstBundle)
                            .font(.caption)
                        InfoRow(label: "UDID", value: ids["udid"] ?? "—")
                            .textSelection(.enabled)
                        InfoRow(label: "Serial", value: ids["serial"] ?? "—")
                            .textSelection(.enabled)
                        InfoRow(label: "ECID", value: ids["ecid"] ?? "—")
                            .textSelection(.enabled)
                        InfoRow(label: "IMEI", value: ids["imei"] ?? "—")
                            .textSelection(.enabled)
                        InfoRow(label: "MAC", value: ids["mac"] ?? "—")
                            .textSelection(.enabled)
                        InfoRow(label: "IDFA", value: ids["idfa"] ?? "—")
                            .textSelection(.enabled)
                    } else {
                        if config.targetBundles.isEmpty {
                            Text("Chưa chọn app mục tiêu")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else if config.randomizeOnLaunch {
                            Text("IDs sẽ sinh mới mỗi lần mở app")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("IDs chưa được sinh. Mở app mục tiêu để sinh.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if config.targetBundles.count > 1 {
                        NavigationLink {
                            AllIDsView()
                        } label: {
                            HStack {
                                Image(systemName: "list.bullet")
                                Text("Xem tất cả (\(config.targetBundles.count) app)")
                                    .font(.caption)
                            }
                        }
                    }
                }

                // MARK: - Carrier
                Section(header: Text("Carrier")) {
                    if config.carrierName.isEmpty {
                        InfoRow(label: "Carrier", value: config.resolvedPreset?.carrierName ?? "—")
                        InfoRow(label: "MCC/MNC", value: "\(config.resolvedPreset?.carrierMCC ?? "—")/\(config.resolvedPreset?.carrierMNC ?? "—")")
                        InfoRow(label: "ISO", value: config.resolvedPreset?.carrierISO ?? "—")
                        InfoRow(label: "Radio", value: radioTechName(config.resolvedPreset?.radioTech ?? ""))
                    } else {
                        InfoRow(label: "Carrier", value: config.carrierName)
                        InfoRow(label: "MCC/MNC", value: "\(config.carrierMCC)/\(config.carrierMNC)")
                        InfoRow(label: "ISO", value: config.carrierISO)
                        InfoRow(label: "Radio", value: radioTechName(config.radioTech))
                    }
                }

                // MARK: - GPS
                Section(header: Text("GPS")) {
                    HStack {
                        Image(systemName: config.geoEnabled ? "location.fill" : "location.slash")
                            .foregroundColor(config.geoEnabled ? .green : .gray)
                        Text(config.geoEnabled ? "Đang spoof" : "Đã tắt")
                            .foregroundColor(config.geoEnabled ? .primary : .secondary)
                    }
                    if config.geoEnabled {
                        InfoRow(label: "Latitude", value: String(format: "%.6f", config.latitude))
                        InfoRow(label: "Longitude", value: String(format: "%.6f", config.longitude))
                        InfoRow(label: "Altitude", value: String(format: "%.1f m", config.altitude))
                        InfoRow(label: "Accuracy", value: String(format: "%.1f m", config.horizontalAccuracy))
                        InfoRow(label: "Heading", value: String(format: "%.0f°", config.heading))
                    }
                }

                // MARK: - Proxy
                Section(header: Text("Proxy")) {
                    HStack {
                        Image(systemName: config.proxyEnabled ? "network" : "network.slash")
                            .foregroundColor(config.proxyEnabled ? .green : .gray)
                        Text(config.proxyEnabled ? "Đang bật" : "Đã tắt")
                            .foregroundColor(config.proxyEnabled ? .primary : .secondary)
                    }
                    if config.proxyEnabled {
                        InfoRow(label: "Type", value: config.proxyType.uppercased())
                        InfoRow(label: "Host", value: config.proxyHost.isEmpty ? "—" : config.proxyHost)
                        InfoRow(label: "Port", value: "\(config.proxyPort)")
                        if !config.proxyUser.isEmpty {
                            InfoRow(label: "User", value: config.proxyUser)
                        }
                        InfoRow(label: "UDP", value: config.proxyUDP ? "Yes" : "No")
                    }
                }

                // MARK: - Anti-Detect
                Section(header: Text("Anti-Detect")) {
                    StatusRow(label: "Ẩn Proxy", enabled: config.hideProxy)
                    StatusRow(label: "Ẩn VPN", enabled: config.hideVPN)
                    StatusRow(label: "Ẩn Jailbreak", enabled: config.hideJailbreak)
                    StatusRow(label: "Spoof IDFA", enabled: config.spoofIDFA)
                    StatusRow(label: "Spoof IDFV", enabled: config.spoofIDFV)
                    StatusRow(label: "Spoof Battery", enabled: config.spoofBattery)
                }
            }
            .navigationTitle("Status")
            .onAppear {
                hasIDCache = FileManager.default.fileExists(atPath: idCachePath)
            }
            .confirmationDialog("Randomize tất cả thông số?", isPresented: $showRandomizeConfirm) {
                Button("Randomize All", role: .destructive) {
                    config.randomizeAll()
                }
                Button("Hủy", role: .cancel) {}
            } message: {
                Text("Sẽ sinh ngẫu nhiên device model, carrier, GPS, IDs. IDs cũ sẽ bị xóa. Cần Respring để áp dụng.")
            }
            .confirmationDialog("Respring để áp dụng?", isPresented: $showRespringConfirm) {
                Button("Respring", role: .destructive) {
                    config.respring()
                }
                Button("Hủy", role: .cancel) {}
            } message: {
                Text("SpringBoard sẽ khởi động lại. Mọi thay đổi sẽ có hiệu lực.")
            }
        }
    }

    private var idCachePath: String {
        let fm = FileManager.default
        if fm.fileExists(atPath: "/var/jb/var/mobile/Library/Preferences") {
            return "/var/jb/var/mobile/Library/Preferences/com.iosspoof.tweak.ids.plist"
        }
        return "/var/mobile/Library/Preferences/com.iosspoof.tweak.ids.plist"
    }

    private func radioTechName(_ raw: String) -> String {
        switch raw {
        case "CTRadioAccessTechnologyNRNSA": return "5G NR (NSA)"
        case "CTRadioAccessTechnologyNR": return "5G NR (SA)"
        case "CTRadioAccessTechnologyLTE": return "4G LTE"
        case "CTRadioAccessTechnologyHSDPA": return "3G HSDPA"
        case "CTRadioAccessTechnologyHSUPA": return "3G HSUPA"
        case "CTRadioAccessTechnologyEdge": return "2G EDGE"
        case "CTRadioAccessTechnologyGPRS": return "2G GPRS"
        default: return raw.isEmpty ? "—" : raw
        }
    }
}

// MARK: - Sub Views

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

struct StatusRow: View {
    let label: String
    let enabled: Bool

    var body: some View {
        HStack {
            Image(systemName: enabled ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor(enabled ? .green : .gray)
            Text(label)
            Spacer()
            Text(enabled ? "Bật" : "Tắt")
                .foregroundColor(enabled ? .green : .gray)
                .font(.caption)
        }
    }
}

// MARK: - All IDs View

struct AllIDsView: View {
    @StateObject private var config = SpoofConfig.shared

    var body: some View {
        List {
            ForEach(config.targetBundles, id: \.self) { bundle in
                if let ids = config.cachedIDs(for: bundle) {
                    Section(header: Text(bundle)) {
                        InfoRow(label: "UDID", value: ids["udid"] ?? "—")
                            .textSelection(.enabled)
                        InfoRow(label: "Serial", value: ids["serial"] ?? "—")
                            .textSelection(.enabled)
                        InfoRow(label: "ECID", value: ids["ecid"] ?? "—")
                            .textSelection(.enabled)
                        InfoRow(label: "IMEI", value: ids["imei"] ?? "—")
                            .textSelection(.enabled)
                        InfoRow(label: "MAC", value: ids["mac"] ?? "—")
                            .textSelection(.enabled)
                        InfoRow(label: "IDFA", value: ids["idfa"] ?? "—")
                            .textSelection(.enabled)
                    }
                } else {
                    Section(header: Text(bundle)) {
                        Text("Chưa sinh IDs")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("All IDs")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    StatusTabView()
}
