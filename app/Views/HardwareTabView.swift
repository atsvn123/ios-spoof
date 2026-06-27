import SwiftUI

struct HardwareTabView: View {
    @StateObject private var config = SpoofConfig.shared
    @StateObject private var presetManager = PresetManager.shared
    
    var body: some View {
        NavigationStack {
            List {
                // Storage & RAM
                Section {
                    if let preset = presetManager.selectedPreset {
                        HStack {
                            Text("Storage")
                            Spacer()
                            Text(preset.capacityGB)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Storage & RAM")
                }
                
                Section {
                    NavigationLink("Storage Override") {
                        StorageOverrideView()
                    }
                    NavigationLink("RAM Override") {
                        RAMOverrideView()
                    }
                }
                
                // Battery
                Section {
                    Toggle("Spoof Battery", isOn: $config.spoofBattery)
                        .tint(.cyan)
                    
                    if config.spoofBattery {
                        NavigationLink("Battery State") {
                            BatteryStateView()
                        }
                    }
                } header: {
                    Text("Battery")
                }
                
                // Camera
                Section {
                    NavigationLink("Camera Capabilities") {
                        CameraCapabilitiesView()
                    }
                } header: {
                    Text("Camera")
                } footer: {
                    Text("Spoof camera capabilities: ultra-wide, LiDAR, ProRAW...")
                }
                
                // Sensors
                Section {
                    NavigationLink("Sensors") {
                        SensorsView()
                    }
                } header: {
                    Text("Sensors")
                } footer: {
                    Text("LiDAR, Face ID, Touch ID, Barometer, Magnetometer...")
                }
                
                // CPU
                Section {
                    NavigationLink("CPU Info") {
                        CPUInfoView()
                    }
                } header: {
                    Text("CPU & Chip")
                }
            }
            .navigationTitle("Hardware")
        }
    }
}

struct StorageOverrideView: View {
    @State private var totalStorage: String = "256"
    @State private var freeStorage: String = "128"
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text("Total (GB)")
                    Spacer()
                    TextField("256", text: $totalStorage)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                }
                HStack {
                    Text("Free (GB)")
                    Spacer()
                    TextField("128", text: $freeStorage)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                }
            }
            
            Section {
                Button("Apply") {
                    // Apply
                }
                .foregroundColor(.cyan)
            }
        }
        .navigationTitle("Storage Override")
    }
}

struct RAMOverrideView: View {
    @State private var ram: String = "6"
    
    var body: some View {
        List {
            Section {
                HStack {
                    Text("RAM (GB)")
                    Spacer()
                    TextField("6", text: $ram)
                        .multilineTextAlignment(.trailing)
                        .keyboardType(.numberPad)
                }
            }
            
            Section {
                Button("Apply") {
                    // Apply
                }
                .foregroundColor(.cyan)
            }
        }
        .navigationTitle("RAM Override")
    }
}

struct BatteryStateView: View {
    @State private var level: Double = 0.8
    @State private var state: String = "uncharging"
    @State private var lowPowerMode = false
    
    var body: some View {
        List {
            Section {
                VStack {
                    Text("\(Int(level * 100))%")
                        .font(.title)
                        .fontWeight(.bold)
                    Slider(value: $level, in: 0...1)
                }
            }
            
            Section("Battery State") {
                Picker("", selection: $state) {
                    Text("Unplugged").tag("uncharging")
                    Text("Charging").tag("charging")
                    Text("Full").tag("full")
                }
                .pickerStyle(.segmented)
            }
            
            Section {
                Toggle("Low Power Mode", isOn: $lowPowerMode)
                    .tint(.orange)
            }
            
            Section {
                Button("Apply") {
                    // Apply
                }
                .foregroundColor(.cyan)
            }
        }
        .navigationTitle("Battery State")
    }
}

struct CameraCapabilitiesView: View {
    @State private var hasUltraWide = true
    @State private var hasTelephoto = false
    @State private var hasLiDAR = false
    @State private var hasProRAW = false
    @State private var hasCinematicMode = false
    
    var body: some View {
        List {
            Section {
                Toggle("Ultra-wide Camera", isOn: $hasUltraWide)
                    .tint(.cyan)
                Toggle("Telephoto Camera", isOn: $hasTelephoto)
                    .tint(.cyan)
                Toggle("LiDAR Sensor", isOn: $hasLiDAR)
                    .tint(.cyan)
            } header: {
                Text("Camera Hardware")
            }
            
            Section {
                Toggle("ProRAW Support", isOn: $hasProRAW)
                    .tint(.cyan)
                Toggle("Cinematic Mode", isOn: $hasCinematicMode)
                    .tint(.cyan)
            } header: {
                Text("Features")
            }
            
            Section {
                Button("Apply") {
                    // Apply
                }
                .foregroundColor(.cyan)
            }
        }
        .navigationTitle("Camera Capabilities")
    }
}

struct SensorsView: View {
    @State private var hasFaceID = true
    @State private var hasTouchID = false
    @State private var hasLiDAR = false
    @State private var hasBarometer = true
    @State private var hasMagnetometer = true
    
    var body: some View {
        List {
            Section {
                Toggle("Face ID", isOn: $hasFaceID)
                    .tint(.cyan)
                Toggle("Touch ID", isOn: $hasTouchID)
                    .tint(.cyan)
            } header: {
                Text("Biometrics")
            }
            
            Section {
                Toggle("LiDAR Scanner", isOn: $hasLiDAR)
                    .tint(.cyan)
                Toggle("Barometer", isOn: $hasBarometer)
                    .tint(.cyan)
                Toggle("Magnetometer", isOn: $hasMagnetometer)
                    .tint(.cyan)
            } header: {
                Text("Sensors")
            }
            
            Section {
                Button("Apply") {
                    // Apply
                }
                .foregroundColor(.cyan)
            }
        }
        .navigationTitle("Sensors")
    }
}

struct CPUInfoView: View {
    @StateObject private var presetManager = PresetManager.shared
    
    var body: some View {
        List {
            if let preset = presetManager.selectedPreset {
                Section {
                    HStack {
                        Text("Chip ID")
                        Spacer()
                        Text(preset.chipId)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("CPU Architecture")
                        Spacer()
                        Text(preset.cpuArchitecture)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Device Class")
                        Spacer()
                        Text(preset.deviceClass)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Board ID")
                        Spacer()
                        Text(preset.boardId)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("CPU & Chip Info")
                }
            }
            
            Section {
                Text("CPU info được spoof dựa trên device preset đã chọn.")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("CPU Info")
    }
}
