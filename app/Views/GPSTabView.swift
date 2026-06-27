import SwiftUI

struct GPSTabView: View {
    @StateObject private var config = SpoofConfig.shared
    @State private var showMapPicker = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Bật Geo Spoofing", isOn: $config.geoEnabled)
                        .tint(.cyan)
                } header: {
                    Text("Vị trí GPS")
                } footer: {
                    Text("Hook CoreLocation để spoof vị trí GPS cho các app.")
                }
                
                if config.geoEnabled {
                    Section("Tọa độ") {
                        HStack {
                            Text("Vĩ độ (Latitude)")
                            Spacer()
                            TextField("21.0285", value: $config.latitude, format: .number)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                        }
                        
                        HStack {
                            Text("Kinh độ (Longitude)")
                            Spacer()
                            TextField("105.8542", value: $config.longitude, format: .number)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                        }
                        
                        HStack {
                            Text("Độ cao (Altitude)")
                            Spacer()
                            TextField("20.0", value: $config.altitude, format: .number)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                        }
                    }
                    
                    Section("Độ chính xác") {
                        HStack {
                            Text("Horizontal Accuracy")
                            Spacer()
                            TextField("5.0", value: $config.horizontalAccuracy, format: .number)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                        }
                        
                        HStack {
                            Text("Heading (°)")
                            Spacer()
                            TextField("0.0", value: $config.heading, format: .number)
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.decimalPad)
                        }
                    }
                    
                    Section {
                        Button {
                            // Open map picker
                            showMapPicker = true
                        } label: {
                            HStack {
                                Image(systemName: "map")
                                Text("Chọn vị trí trên bản đồ")
                            }
                        }
                        .foregroundColor(.cyan)
                    }
                    
                    // Quick locations
                    Section("Vị trí nhanh") {
                        QuickLocationRow(name: "Hà Nội", lat: 21.0285, lon: 105.8542)
                        QuickLocationRow(name: "TP. Hồ Chí Minh", lat: 10.8231, lon: 106.6297)
                        QuickLocationRow(name: "Đà Nẵng", lat: 16.0471, lon: 108.2068)
                        QuickLocationRow(name: "Hải Phòng", lat: 20.8449, lon: 106.6881)
                        QuickLocationRow(name: "Cần Thơ", lat: 10.0452, lon: 105.7469)
                        QuickLocationRow(name: "New York", lat: 40.7128, lon: -74.0060)
                        QuickLocationRow(name: "London", lat: 51.5074, lon: -0.1278)
                        QuickLocationRow(name: "Tokyo", lat: 35.6762, lon: 139.6503)
                        QuickLocationRow(name: "Singapore", lat: 1.3521, lon: 103.8198)
                    }
                }
            }
            .navigationTitle("GPS")
            .sheet(isPresented: $showMapPicker) {
                MapPickerView(latitude: $config.latitude, longitude: $config.longitude)
            }
        }
    }
}

struct QuickLocationRow: View {
    let name: String
    let lat: Double
    let lon: Double
    
    @StateObject private var config = SpoofConfig.shared
    
    var body: some View {
        Button {
            config.latitude = lat
            config.longitude = lon
        } label: {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.cyan)
                Text(name)
                    .foregroundColor(.primary)
                Spacer()
                Text("\(String(format: "%.4f", lat)), \(String(format: "%.4f", lon))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct MapPickerView: View {
    @Binding var latitude: Double
    @Binding var longitude: Double
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Map Picker")
                    .font(.title)
                Text("(Cần implement MapKit)")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .navigationTitle("Chọn vị trí")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Xong") { dismiss() }
                }
            }
        }
    }
}
