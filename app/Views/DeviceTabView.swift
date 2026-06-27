import SwiftUI

// MARK: - Device Tab

struct DeviceTabView: View {
    @StateObject private var config = SpoofConfig.shared
    @State private var showModelPicker = false
    
    var body: some View {
        NavigationView {
            List {
                // Master Toggle
                Section(footer: Text("Bật để kích hoạt spoofing cho các app đã chọn")) {
                    Toggle("Bật Spoof", isOn: $config.enabled)
                        .accentColor(.cyan)
                }
                
                // Device Model
                Section(header: Text("Thiết bị")) {
                    Button {
                        showModelPicker = true
                    } label: {
                        HStack {
                            Text("Model")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(config.selectedModelName)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Toggle("Ngẫu nhiên mỗi lần mở app", isOn: $config.randomizeOnLaunch)
                        .accentColor(.cyan)
                }
                
                // Device Info Preview
                Section(header: Text("Thông tin thiết bị")) {
                    InfoRow(label: "Product Type", value: config.productType)
                    InfoRow(label: "Marketing Name", value: config.marketingName)
                    InfoRow(label: "Hardware Model", value: config.hardwareModel)
                    InfoRow(label: "CPU Architecture", value: config.cpuArchitecture)
                }
                
                // Screen
                Section(header: Text("Màn hình")) {
                    InfoRow(label: "Kích thước", value: "\(config.screenWidth) x \(config.screenHeight)")
                    InfoRow(label: "Scale", value: "\(config.screenScale)x")
                    InfoRow(label: "Inches", value: String(format: "%.1f\"", config.screenInches))
                    InfoRow(label: "PPI", value: "\(config.ppi)")
                }
                
                // Quick Actions
                Section {
                    Button {
                        config.resetAll()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Đặt lại mặc định")
                        }
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Device")
            .sheet(isPresented: $showModelPicker) {
                ModelPickerView(config: config)
            }
        }
    }
}

// MARK: - Model Picker

struct ModelPickerView: View {
    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject var config: SpoofConfig
    @State private var searchText = ""

    var filteredPresets: [DevicePreset] {
        if searchText.isEmpty {
            return DevicePresets.all
        }
        return DevicePresets.all.filter {
            $0.marketingName.localizedCaseInsensitiveContains(searchText) ||
            $0.productType.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    TextField("Tìm iPhone...", text: $searchText)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }

                Button {
                    config.productType = "random"
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    HStack {
                        Label("Ngẫu nhiên", systemImage: "shuffle")
                            .foregroundColor(.primary)
                        Spacer()
                        if config.productType == "random" {
                            Image(systemName: "checkmark")
                                .foregroundColor(.cyan)
                        }
                    }
                }

                ForEach(filteredPresets) { preset in
                    Button {
                        config.productType = preset.productType
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(preset.marketingName)
                                    .foregroundColor(.primary)
                                Text(preset.productType)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if config.productType == preset.productType {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.cyan)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Chọn Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
    }
}
