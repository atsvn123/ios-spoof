import SwiftUI

struct DisplayTabView: View {
    @StateObject private var config = SpoofConfig.shared
    @StateObject private var presetManager = PresetManager.shared
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let preset = presetManager.selectedPreset {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Thiết bị: ")
                                    .foregroundColor(.secondary)
                                Text(preset.marketingName)
                                    .fontWeight(.medium)
                            }
                            HStack {
                                Text("Screen: ")
                                    .foregroundColor(.secondary)
                                Text("\(preset.screenWidth)×\(preset.screenHeight) @\(preset.screenScale)x")
                            }
                            HStack {
                                Text("Size: ")
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.1f\"", preset.screenInches))
                            }
                            HStack {
                                Text("PPI: ")
                                    .foregroundColor(.secondary)
                                Text("\(preset.ppi)")
                            }
                        }
                        .font(.caption)
                    }
                } header: {
                    Text("Thông tin màn hình")
                } footer: {
                    Text("Spoof dựa trên device preset đã chọn.")
                }
                
                Section {
                    NavigationLink("Screen Size Override") {
                        ScreenSizeOverrideView()
                    }
                }
                
                Section {
                    NavigationLink("Brightness Spoofing") {
                        BrightnessSpoofView()
                    }
                }
                
                Section {
                    NavigationLink("Display Scale") {
                        DisplayScaleView()
                    }
                }
            }
            .navigationTitle("Display")
        }
    }
}

struct ScreenSizeOverrideView: View {
    @State private var width: String = ""
    @State private var height: String = ""
    @State private var scale: String = ""
    
    var body: some View {
        List {
            Section {
                TextField("Width", text: $width)
                    .keyboardType(.numberPad)
                TextField("Height", text: $height)
                    .keyboardType(.numberPad)
                TextField("Scale", text: $scale)
                    .keyboardType(.numberPad)
            } header: {
                Text("Override kích thước màn hình")
            }
            
            Section {
                Button("Apply Override") {
                    // Apply override
                }
                .foregroundColor(.cyan)
            }
        }
        .navigationTitle("Screen Size")
    }
}

struct BrightnessSpoofView: View {
    @State private var brightness: Double = 0.5
    
    var body: some View {
        List {
            Section {
                Slider(value: $brightness, in: 0...1)
                Text("\(Int(brightness * 100))%")
                    .foregroundColor(.secondary)
            } header: {
                Text("Brightness level")
            }
            
            Section {
                Button("Apply") {
                    // Apply
                }
                .foregroundColor(.cyan)
            }
        }
        .navigationTitle("Brightness")
    }
}

struct DisplayScaleView: View {
    @State private var scale: Double = 3.0
    
    var body: some View {
        List {
            Section {
                Picker("Scale", selection: $scale) {
                    Text("1x").tag(1.0)
                    Text("2x").tag(2.0)
                    Text("3x").tag(3.0)
                }
                .pickerStyle(.segmented)
            }
            
            Section {
                Button("Apply") {
                    // Apply
                }
                .foregroundColor(.cyan)
            }
        }
        .navigationTitle("Display Scale")
    }
}
