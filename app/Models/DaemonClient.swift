import Foundation

final class DaemonClient {
    static let shared = DaemonClient()

    private var socketPath: String {
        let fm = FileManager.default
        if fm.fileExists(atPath: "/var/jb") {
            return "/var/jb/var/run/scproxyd.sock"
        }
        return "/var/run/scproxyd.sock"
    }

    private init() {}

    struct DaemonStatus {
        let running: Bool
        let proxyType: String
        let host: String
        let port: Int
    }

    func sendCommand(_ command: [String: Any]) -> [String: Any]? {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }
        defer { close(fd) }

        var addr = sockaddr_un()
        addr.sun_family = sa_family_t(AF_UNIX)
        let path = socketPath
        withUnsafeMutablePointer(to: &addr.sun_path) {
            ptr in
            path.withCString { cPath in
                _ = strcpy(ptr.withMemoryRebound(to: CChar.self, capacity: 104) { $0 }, cPath)
            }
        }

        let result = withUnsafePointer(to: &addr) { addrPtr in
            addrPtr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                connect(fd, sockPtr, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard result == 0 else { return nil }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: command),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return nil
        }

        let msg = jsonString + "\n"
        msg.withCString { cStr in
            _ = send(fd, cStr, strlen(cStr), 0)
        }

        var buffer = [CChar](repeating: 0, count: 4096)
        let bytesReceived = recv(fd, &buffer, 4096, 0)
        guard bytesReceived > 0 else { return nil }

        let response = String(cString: buffer)
        guard let data = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        return json
    }

    func checkStatus() -> DaemonStatus {
        guard let resp = sendCommand(["cmd": "status"]) else {
            return DaemonStatus(running: false, proxyType: "", host: "", port: 0)
        }

        return DaemonStatus(
            running: (resp["running"] as? Bool) ?? false,
            proxyType: (resp["proxyType"] as? String) ?? "",
            host: (resp["host"] as? String) ?? "",
            port: (resp["port"] as? Int) ?? 0
        )
    }

    func startProxy() -> Bool {
        guard let resp = sendCommand(["cmd": "start"]) else { return false }
        return (resp["ok"] as? Bool) ?? false
    }

    func stopProxy() -> Bool {
        guard let resp = sendCommand(["cmd": "stop"]) else { return false }
        return (resp["ok"] as? Bool) ?? false
    }
}
