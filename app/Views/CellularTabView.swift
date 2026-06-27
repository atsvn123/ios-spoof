import SwiftUI

struct CellularTabView: View {
    @StateObject private var config = SpoofConfig.shared
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("Carrier Name")
                        Spacer()
                        TextField("Viettel", text: $config.carrierName)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("Nhà mạng")
                } footer: {
                    Text("Hook CTTelephonyNetworkInfo để spoof carrier info.")
                }
                
                Section("MCC/MNC") {
                    HStack {
                        Text("MCC (Mobile Country)")
                        Spacer()
                        TextField("452", text: $config.carrierMCC)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                    }
                    
                    HStack {
                        Text("MNC (Mobile Network)")
                        Spacer()
                        TextField("04", text: $config.carrierMNC)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                    }
                    
                    HStack {
                        Text("ISO Country")
                        Spacer()
                        TextField("vn", text: $config.carrierISO)
                            .multilineTextAlignment(.trailing)
                            .autocapitalization(.allCharacters)
                    }
                }
                
                Section("Loại mạng") {
                    Picker("Radio Access Technology", selection: $config.radioTech) {
                        Text("5G NR (NSA)").tag("CTRadioAccessTechnologyNRNSA")
                        Text("5G NR (SA)").tag("CTRadioAccessTechnologyNR")
                        Text("4G LTE").tag("CTRadioAccessTechnologyLTE")
                        Text("3G HSDPA").tag("CTRadioAccessTechnologyHSDPA")
                        Text("3G HSUPA").tag("CTRadioAccessTechnologyHSUPA")
                        Text("2G EDGE").tag("CTRadioAccessTechnologyEdge")
                        Text("2G GPRS").tag("CTRadioAccessTechnologyGPRS")
                    }
                } footer: {
                    Text("Spoof loại mạng di động. App sẽ thấy 4G/5G thay vì WiFi.")
                }
                
                // Quick carriers
                Section("Nhà mạng nhanh") {
                    QuickCarrierRow(name: "Viettel", mcc: "452", mnc: "04", iso: "vn")
                    QuickCarrierRow(name: "Mobifone", mcc: "452", mnc: "01", iso: "vn")
                    QuickCarrierRow(name: "Vinaphone", mcc: "452", mnc: "02", iso: "vn")
                    QuickCarrierRow(name: "Vietnamobile", mcc: "452", mnc: "05", iso: "vn")
                    QuickCarrierRow(name: "Gmobile", mcc: "452", mnc: "07", iso: "vn")
                    QuickCarrierRow(name: "AT&T (US)", mcc: "310", mnc: "410", iso: "us")
                    QuickCarrierRow(name: "Verizon (US)", mcc: "310", mnc: "004", iso: "us")
                    QuickCarrierRow(name: "T-Mobile (US)", mcc: "310", mnc: "260", iso: "us")
                    QuickCarrierRow(name: "NTT Docomo (JP)", mcc: "440", mnc: "10", iso: "jp")
                    QuickCarrierRow(name: "SoftBank (JP)", mcc: "440", mnc: "20", iso: "jp")
                }
                
                Section {
                    NavigationLink("WiFi → 4G Spoofing") {
                        WiFiTo4GView()
                    }
                } footer: {
                    Text("Làm cho app tin rằng bạn đang dùng 4G thay vì WiFi.")
                }
            }
            .navigationTitle("Cellular")
        }
    }
}

struct QuickCarrierRow: View {
    let name: String
    let mcc: String
    let mnc: String
    let iso: String
    
    @StateObject private var config = SpoofConfig.shared
    
    var body: some View {
        Button {
            config.carrierName = name
            config.carrierMCC = mcc
            config.carrierMNC = mnc
            config.carrierISO = iso
        } label: {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundColor(.cyan)
                Text(name)
                    .foregroundColor(.primary)
                Spacer()
                Text("\(mcc)/\(mnc)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct WiFiTo4GView: View {
    var body: some View {
        List {
            Section {
                Text("Khi bật, app sẽ thấy network type là 4G/5G thay vì WiFi.")
                    .foregroundColor(.secondary)
            }
            
            Section("Cách hoạt động") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("1. Hook reachability để trả về WWAN")
                    Text("2. Hook getifaddrs để ẩn WiFi interface")
                    Text("3. Hook CTTelephonyNetworkInfo để spoof radio tech")
                }
                .font(.caption)
            }
        }
        .navigationTitle("WiFi → 4G Spoofing")
    }
}
