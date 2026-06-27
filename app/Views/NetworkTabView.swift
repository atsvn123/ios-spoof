import SwiftUI

struct NetworkTabView: View {
    @StateObject private var config = SpoofConfig.shared
    @State private var showDaemonStatus = false
    @State private var daemonStatus: [String: Any]?
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Bật Proxy", isOn: $config.proxyEnabled)
                        .tint(.cyan)
                } header: {
                    Text("Transparent Proxy")
                } footer: {
                    Text("Proxy trong suốt qua PF divert. App không phát hiện được proxy.")
                }
                
                if config.proxyEnabled {
                    Section(header: Text("Loại Proxy")) {
                        Picker("", selection: $config.proxyType) {
                            Text("SOCKS5").tag("socks5")
                            Text("HTTP CONNECT").tag("http")
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    Section(header: Text("Server")) {
                        HStack {
                            Text("Host")
                            Spacer()
                            TextField("127.0.0.1", text: $config.proxyHost)
                                .multilineTextAlignment(.trailing)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                        }
                        
                        HStack {
                            Text("Port")
                            Spacer()
                            TextField("1080", value: $config.proxyPort, formatter: NumberFormatter())
                                .multilineTextAlignment(.trailing)
                                .keyboardType(.numberPad)
                        }
                    }
                    
                    Section(header: Text("Xác thực (tùy chọn)")) {
                        HStack {
                            Text("Username")
                            Spacer()
                            TextField("user", text: $config.proxyUser)
                                .multilineTextAlignment(.trailing)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                        }
                        
                        HStack {
                            Text("Password")
                            Spacer()
                            SecureField("pass", text: $config.proxyPass)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    
                    Section {
                        Toggle("Hỗ trợ UDP (SOCKS5)", isOn: $config.proxyUDP)
                            .tint(.cyan)
                    } footer: {
                        Text("Cần proxy hỗ trợ UDP associate cho DNS, QUIC, gaming...")
                    }
                }
                
                // Anti-detect
                Section {
                    Toggle("Ẩn Proxy Settings", isOn: $config.hideProxy)
                        .tint(.cyan)
                    Toggle("Ẩn VPN Interface", isOn: $config.hideVPN)
                        .tint(.cyan)
                    Toggle("Ẩn Jailbreak", isOn: $config.hideJailbreak)
                        .tint(.cyan)
                } header: {
                    Text("Anti-Detect")
                } footer: {
                    Text("Hook các API để ẩn dấu vết proxy/VPN/jailbreak.")
                }

                // ID Spoofing
                Section {
                    Toggle("Spoof IDFA", isOn: $config.spoofIDFA)
                        .tint(.cyan)
                    Toggle("Spoof IDFV", isOn: $config.spoofIDFV)
                        .tint(.cyan)
                    Toggle("Spoof Battery", isOn: $config.spoofBattery)
                        .tint(.cyan)
                } header: {
                    Text("ID Spoofing")
                }
                
                // Daemon Status
                Section {
                    Button {
                        checkDaemonStatus()
                    } label: {
                        HStack {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                            Text("Kiểm tra scproxyd")
                        }
                    }
                    .foregroundColor(.cyan)
                } footer: {
                    if let status = daemonStatus {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Running: \((status["running"] as? Bool) ?? false ? "✓" : "✗")")
                            Text("Type: \(status["proxyType"] as? String ?? "-")")
                            Text("Host: \(status["host"] as? String ?? "-"):\(status["port"] as? Int ?? 0)")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Network")
        }
    }
    
    private func checkDaemonStatus() {
        daemonStatus = DaemonClient.shared.sendCommand(["cmd": "status"])
    }
}
