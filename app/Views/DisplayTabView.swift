import SwiftUI

struct DisplayTabView: View {
    @StateObject private var config = SpoofConfig.shared
    @StateObject private var presetManager = PresetManager.shared
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Thông tin màn hình"), footer: Text("Spoof dựa trên device preset đã chọn.")) {
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
                }
                
                Section {
                    NavigationLink(destination:
                        ScreenSizeOverrideView()
                    ) { Text("Screen Size Override") }
                }
                
                Section {
                    NavigationLink(destination:
                        BrightnessSpoofView()
                    ) { Text("Brightness Spoofing") }
                }
                
                Section {
                    NavigationLink(destination:
                        DisplayScaleView()
                    ) { Text("Display Scale") }
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
            Section(header: Text("Override kích thước màn hình")) {
                TextField("Width", text: $width)
                    .keyboardType(.numberPad)
                TextField("Height", text: $height)
                    .keyboardType(.numberPad)
                TextField("Scale", text: $scale)
                    .keyboardType(.numberPad)
            }
            
            Section {
                Button("Apply Override") {
                    // Apply override
                }
                .foregroundColor(.scAccent)
            }
        }
        .navigationTitle("Screen Size")
    }
}

struct BrightnessSpoofView: View {
    @State private var brightness: Double = 0.5
    
    var body: some View {
        List {
            Section(header: Text("Brightness level")) {
                Slider(value: $brightness, in: 0...1)
                Text("\(Int(brightness * 100))%")
                    .foregroundColor(.secondary)
            }
            
            Section {
                Button("Apply") {
                    // Apply
                }
                .foregroundColor(.scAccent)
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
                .foregroundColor(.scAccent)
            }
        }
        .navigationTitle("Display Scale")
    }
}
