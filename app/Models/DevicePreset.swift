import Foundation

struct DevicePreset: Identifiable, Hashable {
    let id: String  // productType
    let productType: String
    let marketingName: String
    let productName: String
    let hardwareModel: String
    let modelNumber: String
    let deviceClass: String
    let boardId: String
    let chipId: String
    let cpuArchitecture: String
    let internalName: String
    let regionCode: String
    let regulatoryModelNumber: String
    let screenWidth: Int
    let screenHeight: Int
    let screenScale: Int
    let screenInches: Double
    let ppi: Int
    let capacityGB: String
    let colorCode: String
    let carrierName: String
    let carrierMCC: String
    let carrierMNC: String
    let carrierISO: String
    let radioTech: String
    let batteryLevel: Double
    let batteryState: String
}

enum DevicePresets {
    static let all: [DevicePreset] = [
        DevicePreset(
            id: "iPhone10,1", productType: "iPhone10,1", marketingName: "iPhone 8",
            productName: "iPhone", hardwareModel: "D20AP", modelNumber: "MQ6G3LL/A",
            deviceClass: "D20", boardId: "0x0A", chipId: "t8015", cpuArchitecture: "arm64e",
            internalName: "D20AP", regionCode: "LL/A", regulatoryModelNumber: "A1863",
            screenWidth: 750, screenHeight: 1334, screenScale: 2, screenInches: 4.7, ppi: 326,
            capacityGB: "128", colorCode: "Space Gray",
            carrierName: "Viettel", carrierMCC: "452", carrierMNC: "04", carrierISO: "vn",
            radioTech: "CTRadioAccessTechnologyLTE", batteryLevel: 0.82, batteryState: "uncharging"
        ),
        DevicePreset(
            id: "iPhone10,3", productType: "iPhone10,3", marketingName: "iPhone X",
            productName: "iPhone", hardwareModel: "D22AP", modelNumber: "MQAQ2LL/A",
            deviceClass: "D22", boardId: "0x0C", chipId: "t8015", cpuArchitecture: "arm64e",
            internalName: "D22AP", regionCode: "LL/A", regulatoryModelNumber: "A1865",
            screenWidth: 1125, screenHeight: 2436, screenScale: 3, screenInches: 5.8, ppi: 458,
            capacityGB: "256", colorCode: "Space Gray",
            carrierName: "Viettel", carrierMCC: "452", carrierMNC: "04", carrierISO: "vn",
            radioTech: "CTRadioAccessTechnologyLTE", batteryLevel: 0.76, batteryState: "uncharging"
        ),
        DevicePreset(
            id: "iPhone12,1", productType: "iPhone12,1", marketingName: "iPhone 11",
            productName: "iPhone", hardwareModel: "N104AP", modelNumber: "MWLU2LL/A",
            deviceClass: "N104", boardId: "0x0A", chipId: "t8030", cpuArchitecture: "arm64e",
            internalName: "N104AP", regionCode: "LL/A", regulatoryModelNumber: "A2111",
            screenWidth: 828, screenHeight: 1792, screenScale: 2, screenInches: 6.1, ppi: 326,
            capacityGB: "128", colorCode: "Black",
            carrierName: "Viettel", carrierMCC: "452", carrierMNC: "04", carrierISO: "vn",
            radioTech: "CTRadioAccessTechnologyLTE", batteryLevel: 0.91, batteryState: "uncharging"
        ),
        DevicePreset(
            id: "iPhone13,2", productType: "iPhone13,2", marketingName: "iPhone 12",
            productName: "iPhone", hardwareModel: "D53gAP", modelNumber: "MGE93LL/A",
            deviceClass: "D53g", boardId: "0x0A", chipId: "t8101", cpuArchitecture: "arm64e",
            internalName: "D53gAP", regionCode: "LL/A", regulatoryModelNumber: "A2172",
            screenWidth: 1170, screenHeight: 2532, screenScale: 3, screenInches: 6.1, ppi: 460,
            capacityGB: "256", colorCode: "Black",
            carrierName: "Viettel", carrierMCC: "452", carrierMNC: "04", carrierISO: "vn",
            radioTech: "CTRadioAccessTechnologyNRNSA", batteryLevel: 0.68, batteryState: "uncharging"
        ),
        DevicePreset(
            id: "iPhone14,5", productType: "iPhone14,5", marketingName: "iPhone 13",
            productName: "iPhone", hardwareModel: "D63AP", modelNumber: "MLNG3LL/A",
            deviceClass: "D63", boardId: "0x08", chipId: "t8110", cpuArchitecture: "arm64e",
            internalName: "D63AP", regionCode: "LL/A", regulatoryModelNumber: "A2633",
            screenWidth: 1170, screenHeight: 2532, screenScale: 3, screenInches: 6.1, ppi: 460,
            capacityGB: "256", colorCode: "Sierra Blue",
            carrierName: "Viettel", carrierMCC: "452", carrierMNC: "04", carrierISO: "vn",
            radioTech: "CTRadioAccessTechnologyNRNSA", batteryLevel: 0.85, batteryState: "uncharging"
        ),
        DevicePreset(
            id: "iPhone14,2", productType: "iPhone14,2", marketingName: "iPhone 13 Pro",
            productName: "iPhone", hardwareModel: "D63pAP", modelNumber: "MLTT3LL/A",
            deviceClass: "D63p", boardId: "0x0A", chipId: "t8110", cpuArchitecture: "arm64e",
            internalName: "D63pAP", regionCode: "LL/A", regulatoryModelNumber: "A2482",
            screenWidth: 1170, screenHeight: 2532, screenScale: 3, screenInches: 6.1, ppi: 460,
            capacityGB: "256", colorCode: "Graphite",
            carrierName: "Viettel", carrierMCC: "452", carrierMNC: "04", carrierISO: "vn",
            radioTech: "CTRadioAccessTechnologyNRNSA", batteryLevel: 0.79, batteryState: "uncharging"
        ),
        DevicePreset(
            id: "iPhone14,7", productType: "iPhone14,7", marketingName: "iPhone 14",
            productName: "iPhone", hardwareModel: "D27AP", modelNumber: "MMX93LL/A",
            deviceClass: "D27", boardId: "0x08", chipId: "t8110", cpuArchitecture: "arm64e",
            internalName: "D27AP", regionCode: "LL/A", regulatoryModelNumber: "A2649",
            screenWidth: 1170, screenHeight: 2532, screenScale: 3, screenInches: 6.1, ppi: 460,
            capacityGB: "256", colorCode: "Midnight",
            carrierName: "Viettel", carrierMCC: "452", carrierMNC: "04", carrierISO: "vn",
            radioTech: "CTRadioAccessTechnologyNRNSA", batteryLevel: 0.88, batteryState: "uncharging"
        ),
        DevicePreset(
            id: "iPhone15,2", productType: "iPhone15,2", marketingName: "iPhone 14 Pro",
            productName: "iPhone", hardwareModel: "D14AP", modelNumber: "MTLV3LL/A",
            deviceClass: "D14", boardId: "0x08", chipId: "t8110", cpuArchitecture: "arm64e",
            internalName: "D14AP", regionCode: "LL/A", regulatoryModelNumber: "A2650",
            screenWidth: 1179, screenHeight: 2556, screenScale: 3, screenInches: 6.1, ppi: 460,
            capacityGB: "256", colorCode: "Deep Purple",
            carrierName: "Viettel", carrierMCC: "452", carrierMNC: "04", carrierISO: "vn",
            radioTech: "CTRadioAccessTechnologyNRNSA", batteryLevel: 0.74, batteryState: "uncharging"
        ),
        DevicePreset(
            id: "iPhone15,3", productType: "iPhone15,3", marketingName: "iPhone 14 Pro Max",
            productName: "iPhone", hardwareModel: "D16AP", modelNumber: "MU2K3LL/A",
            deviceClass: "D16", boardId: "0x0A", chipId: "t8110", cpuArchitecture: "arm64e",
            internalName: "D16AP", regionCode: "LL/A", regulatoryModelNumber: "A2651",
            screenWidth: 1290, screenHeight: 2796, screenScale: 3, screenInches: 6.7, ppi: 460,
            capacityGB: "512", colorCode: "Deep Purple",
            carrierName: "Viettel", carrierMCC: "452", carrierMNC: "04", carrierISO: "vn",
            radioTech: "CTRadioAccessTechnologyNRNSA", batteryLevel: 0.93, batteryState: "uncharging"
        ),
        DevicePreset(
            id: "iPhone15,4", productType: "iPhone15,4", marketingName: "iPhone 15",
            productName: "iPhone", hardwareModel: "D37AP", modelNumber: "MTX93LL/A",
            deviceClass: "D37", boardId: "0x08", chipId: "t8120", cpuArchitecture: "arm64e",
            internalName: "D37AP", regionCode: "LL/A", regulatoryModelNumber: "A2846",
            screenWidth: 1179, screenHeight: 2556, screenScale: 3, screenInches: 6.1, ppi: 460,
            capacityGB: "256", colorCode: "Pink",
            carrierName: "Viettel", carrierMCC: "452", carrierMNC: "04", carrierISO: "vn",
            radioTech: "CTRadioAccessTechnologyNRNSA", batteryLevel: 0.81, batteryState: "uncharging"
        ),
        DevicePreset(
            id: "iPhone16,1", productType: "iPhone16,1", marketingName: "iPhone 15 Pro",
            productName: "iPhone", hardwareModel: "D83AP", modelNumber: "MTUW3LL/A",
            deviceClass: "D83", boardId: "0x08", chipId: "t8120", cpuArchitecture: "arm64e",
            internalName: "D83AP", regionCode: "LL/A", regulatoryModelNumber: "A2848",
            screenWidth: 1179, screenHeight: 2556, screenScale: 3, screenInches: 6.1, ppi: 460,
            capacityGB: "256", colorCode: "Natural Titanium",
            carrierName: "Viettel", carrierMCC: "452", carrierMNC: "04", carrierISO: "vn",
            radioTech: "CTRadioAccessTechnologyNRNSA", batteryLevel: 0.86, batteryState: "uncharging"
        ),
        DevicePreset(
            id: "iPhone16,2", productType: "iPhone16,2", marketingName: "iPhone 15 Pro Max",
            productName: "iPhone", hardwareModel: "D84AP", modelNumber: "MU653LL/A",
            deviceClass: "D84", boardId: "0x0A", chipId: "t8120", cpuArchitecture: "arm64e",
            internalName: "D84AP", regionCode: "LL/A", regulatoryModelNumber: "A2849",
            screenWidth: 1290, screenHeight: 2796, screenScale: 3, screenInches: 6.7, ppi: 460,
            capacityGB: "512", colorCode: "Blue Titanium",
            carrierName: "Viettel", carrierMCC: "452", carrierMNC: "04", carrierISO: "vn",
            radioTech: "CTRadioAccessTechnologyNRNSA", batteryLevel: 0.90, batteryState: "uncharging"
        ),
    ]

    static func preset(for productType: String) -> DevicePreset? {
        all.first { $0.productType == productType }
    }

    static func random() -> DevicePreset {
        all.randomElement()!
    }

    // MARK: - ID Generators
    static func generateUDID() -> String {
        let chars = Array("0123456789abcdef")
        return String((0..<40).map { _ in chars[Int(arc4random_uniform(16))] })
    }

    static func generateSerialNumber() -> String {
        let chars = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        return String((0..<10).map { _ in chars[Int(arc4random_uniform(36))] })
    }

    static func generateECID() -> String {
        let chars = Array("0123456789ABCDEF")
        return String((0..<13).map { _ in chars[Int(arc4random_uniform(16))] })
    }

    static func generateMAC() -> String {
        var bytes: [UInt8] = (0..<6).map { _ in UInt8(arc4random_uniform(256)) }
        bytes[0] = (bytes[0] & 0xFE) | 0x02
        return bytes.map { String(format: "%02X", $0) }.joined(separator: ":")
    }

    static func generateIMEI() -> String {
        var digits: [Int] = [3, 5]
        for _ in 0..<12 { digits.append(Int(arc4random_uniform(10))) }
        var sum = 0
        for i in 0..<14 {
            var d = digits[i]
            if i % 2 == 1 {
                d *= 2
                if d > 9 { d -= 9 }
            }
            sum += d
        }
        let check = (10 - (sum % 10)) % 10
        digits.append(check)
        return digits.map { String($0) }.joined()
    }

    static func generateIDFA() -> String {
        UUID().uuidString.uppercased()
    }
}
