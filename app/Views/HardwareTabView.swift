import SwiftUI

struct HardwareTabView: View {
    @StateObject private var config = SpoofConfig.shared
    @StateObject private var presetManager = PresetManager.shared
    
    var body: some View {
        NavigationView {
            List {
                // Storage & RAM
                Section(header: Text("Storage & RAM")) {
                    if let preset = presetManager.selectedPreset {
                        HStack {
                            Text("Storage")
                            Spacer()
                            Text(preset.capacityGB)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section {
                    NavigationLink(destination:
                        StorageOverrideView()
                    ) { Text("Storage Override") }
                    NavigationLink(destination:
                        RAMOverrideView()
                    ) { Text("RAM Override") }
                }
                
                // Battery
                Section(header: Text("Battery")) {
                    Toggle("Spoof Battery", isOn: $config.spoofBattery)
                        .accentColor(.scAccent)
                    
                    if config.spoofBattery {
                        NavigationLink(destination:
                            BatteryStateView()
                        ) { Text("Battery State") }
                    }
                }
                
                // Camera
                Section(header: Text("Camera"), footer: Text("Spoof camera capabilities: ultra-wide, LiDAR, ProRAW...")) {
                    NavigationLink(destination:
                        CameraCapabilitiesView()
                    ) { Text("Camera Capabilities") }
                }
                
                // Sensors
                Section(header: Text("Sensors"), footer: Text("LiDAR, Face ID, Touch ID, Barometer, Magnetometer...")) {
                    NavigationLink(destination:
                        SensorsView()
                    ) { Text("Sensors") }
                }
                
                // CPU
                Section(header: Text("CPU & Chip")) {
                    NavigationLink(destination:
                        CPUInfoView()
                    ) { Text("CPU Info") }
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
                .foregroundColor(.scAccent)
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
                .foregroundColor(.scAccent)
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
            
            Section(header: Text("Battery State")) {
                Picker("", selection: $state) {
                    Text("Unplugged").tag("uncharging")
                    Text("Charging").tag("charging")
                    Text("Full").tag("full")
                }
                .pickerStyle(.segmented)
            }
            
            Section {
                Toggle("Low Power Mode", isOn: $lowPowerMode)
                    .accentColor(.orange)
            }
            
            Section {
                Button("Apply") {
                    // Apply
                }
                .foregroundColor(.scAccent)
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
            Section(header: Text("Camera Hardware")) {
                Toggle("Ultra-wide Camera", isOn: $hasUltraWide)
                    .accentColor(.scAccent)
                Toggle("Telephoto Camera", isOn: $hasTelephoto)
                    .accentColor(.scAccent)
                Toggle("LiDAR Sensor", isOn: $hasLiDAR)
                    .accentColor(.scAccent)
            }
            
            Section(header: Text("Features")) {
                Toggle("ProRAW Support", isOn: $hasProRAW)
                    .accentColor(.scAccent)
                Toggle("Cinematic Mode", isOn: $hasCinematicMode)
                    .accentColor(.scAccent)
            }
            
            Section {
                Button("Apply") {
                    // Apply
                }
                .foregroundColor(.scAccent)
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
            Section(header: Text("Biometrics")) {
                Toggle("Face ID", isOn: $hasFaceID)
                    .accentColor(.scAccent)
                Toggle("Touch ID", isOn: $hasTouchID)
                    .accentColor(.scAccent)
            }
            
            Section(header: Text("Sensors")) {
                Toggle("LiDAR Scanner", isOn: $hasLiDAR)
                    .accentColor(.scAccent)
                Toggle("Barometer", isOn: $hasBarometer)
                    .accentColor(.scAccent)
                Toggle("Magnetometer", isOn: $hasMagnetometer)
                    .accentColor(.scAccent)
            }
            
            Section {
                Button("Apply") {
                    // Apply
                }
                .foregroundColor(.scAccent)
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
                Section(header: Text("CPU & Chip Info")) {
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
