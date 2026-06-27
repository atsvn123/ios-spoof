import SwiftUI

struct NetworkTabView: View {
    @StateObject private var config = SpoofConfig.shared
    @State private var showDaemonStatus = false
    @State private var daemonStatus: [String: Any]?
    @State private var hasCheckedDaemon = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Transparent Proxy"), footer: Text("Proxy trong suốt qua PF divert. App không phát hiện được proxy.")) {
                    Toggle("Bật Proxy", isOn: $config.proxyEnabled)
                        .accentColor(.cyan)
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
                                .disableAutocorrection(true)
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
                                .disableAutocorrection(true)
                        }
                        
                        HStack {
                            Text("Password")
                            Spacer()
                            SecureField("pass", text: $config.proxyPass)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    
                    Section(footer: Text("Cần proxy hỗ trợ UDP associate cho DNS, QUIC, gaming...")) {
                        Toggle("Hỗ trợ UDP (SOCKS5)", isOn: $config.proxyUDP)
                            .accentColor(.cyan)
                    }
                }
                
                // Anti-detect
                Section(header: Text("Anti-Detect"), footer: Text("Hook các API để ẩn dấu vết proxy/VPN/jailbreak.")) {
                    Toggle("Ẩn Proxy Settings", isOn: $config.hideProxy)
                        .accentColor(.cyan)
                    Toggle("Ẩn VPN Interface", isOn: $config.hideVPN)
                        .accentColor(.cyan)
                    Toggle("Ẩn Jailbreak", isOn: $config.hideJailbreak)
                        .accentColor(.cyan)
                }

                // ID Spoofing
                Section(header: Text("ID Spoofing")) {
                    Toggle("Spoof IDFA", isOn: $config.spoofIDFA)
                        .accentColor(.cyan)
                    Toggle("Spoof IDFV", isOn: $config.spoofIDFV)
                        .accentColor(.cyan)
                    Toggle("Spoof Battery", isOn: $config.spoofBattery)
                        .accentColor(.cyan)
                }
                
                // Daemon Status
                Section(header: Text("Daemon"), footer: Group {
                    if let status = daemonStatus {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Running: \((status["running"] as? Bool) ?? false ? "✓" : "✗")")
                            Text("Type: \(status["proxyType"] as? String ?? "-")")
                            Text("Host: \(status["host"] as? String ?? "-"):\(status["port"] as? Int ?? 0)")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    } else if hasCheckedDaemon {
                        Text("Daemon không phản hồi. Đảm bảo scproxyd đang chạy.")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }) {
                    Button {
                        checkDaemonStatus()
                    } label: {
                        HStack {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                            Text("Kiểm tra scproxyd")
                        }
                    }
                    .foregroundColor(.cyan)
                }
            }
            .navigationTitle("Network")
        }
    }

    private func checkDaemonStatus() {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = DaemonClient.shared.sendCommand(["cmd": "status"])
            DispatchQueue.main.async {
                daemonStatus = result
                hasCheckedDaemon = true
            }
        }
    }
}
