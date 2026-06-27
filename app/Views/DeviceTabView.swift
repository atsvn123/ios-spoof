import SwiftUI

// MARK: - Device Tab

struct DeviceTabView: View {
    @StateObject private var config = SpoofConfig.shared
    @State private var showModelPicker = false
    
    var body: some View {
        NavigationStack {
            List {
                // Master Toggle
                Section {
                    Toggle("Bật Spoof", isOn: $config.enabled)
                        .tint(.cyan)
                } footer: {
                    Text("Bật để kích hoạt spoofing cho các app đã chọn")
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
                        .tint(.cyan)
                }
                
                // Device Info Preview
                Section(header: Text("Thông tin thiết bị")) {
                    LabeledContent("Product Type", value: config.productType)
                    LabeledContent("Marketing Name", value: config.marketingName)
                    LabeledContent("Hardware Model", value: config.hardwareModel)
                    LabeledContent("CPU Architecture", value: config.cpuArchitecture)
                }
                
                // Screen
                Section(header: Text("Màn hình")) {
                    LabeledContent("Kích thước", value: "\(config.screenWidth) x \(config.screenHeight)")
                    LabeledContent("Scale", value: "\(config.screenScale)x")
                    LabeledContent("Inches", value: String(format: "%.1f\"", config.screenInches))
                    LabeledContent("PPI", value: "\(config.ppi)")
                }
                
                // Quick Actions
                Section {
                    Button(role: .destructive) {
                        config.resetAll()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Đặt lại mặc định")
                        }
                    }
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
    @Environment(\.dismiss) private var dismiss
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
        NavigationStack {
            List {
                Button {
                    config.productType = "random"
                    dismiss()
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
                        dismiss()
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
            .searchable(text: $searchText, prompt: "Tìm iPhone...")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
    }
}
