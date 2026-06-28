#import <Foundation/Foundation.h>
#import "SCDevicePresets.h"

/**
 * SCSpoofConfig
 *
 * Đọc cấu hình từ preferences plist (cfsuite com.iosspoof.tweak).
 * Hỗ trợ:
 *  - enabled master toggle
 *  - preset device (productType) hoặc randomize
 *  - per-bundle override (bundle id -> dict override)
 *  - carrier / radio override
 *  - geo override (lat/lon/alt/accuracy/heading)
 *  - proxy config (socks5 / http, host, port, user, pass, udp)
 *  - anti-detect flags (hideProxy, hideVPN, hideJailbreak)
 *
 * Preference plist schema (com.iosspoof.tweak.plist):
 *  {
 *    enabled: bool,
 *    productType: "iPhone15,2" | "random",
 *    randomizeOnLaunch: bool,
 *    bundleOverrides: { "com.app.id": { ...override... } },
 *    carrierName, carrierMCC, carrierMNC, carrierISO, radioTech,
 *    geoEnabled: bool, latitude, longitude, altitude, horizontalAccuracy, heading,
 *    proxyEnabled: bool, proxyType: "socks5"|"http", proxyHost, proxyPort,
 *       proxyUser, proxyPass, proxyUDP: bool,
 *    hideProxy: bool, hideVPN: bool, hideJailbreak: bool,
 *    spoofIDFA: bool, spoofIDFV: bool, spoofBattery: bool
 *  }
 */
@interface SCSpoofConfig : NSObject

@property (nonatomic, readonly) BOOL enabled;
@property (nonatomic, readonly) NSString *productType;       // nil = randomize
@property (nonatomic, readonly) BOOL randomizeOnLaunch;
@property (nonatomic, readonly) NSDictionary *bundleOverrides;
@property (nonatomic, readonly) NSString *carrierName;
@property (nonatomic, readonly) NSString *carrierMCC;
@property (nonatomic, readonly) NSString *carrierMNC;
@property (nonatomic, readonly) NSString *carrierISO;
@property (nonatomic, readonly) NSString *radioTech;
@property (nonatomic, readonly) NSArray<NSDictionary *> *simSlots;
@property (nonatomic, readonly) NSInteger activeSIMIndex;
@property (nonatomic, readonly) BOOL geoEnabled;
@property (nonatomic, readonly) double latitude;
@property (nonatomic, readonly) double longitude;
@property (nonatomic, readonly) double altitude;
@property (nonatomic, readonly) double horizontalAccuracy;
@property (nonatomic, readonly) double heading;
@property (nonatomic, readonly) BOOL proxyEnabled;
@property (nonatomic, readonly) NSString *proxyType;
@property (nonatomic, readonly) NSString *proxyHost;
@property (nonatomic, readonly) uint16_t proxyPort;
@property (nonatomic, readonly) NSString *proxyUser;
@property (nonatomic, readonly) NSString *proxyPass;
@property (nonatomic, readonly) BOOL proxyUDP;
@property (nonatomic, readonly) BOOL hideProxy;
@property (nonatomic, readonly) BOOL hideVPN;
@property (nonatomic, readonly) BOOL hideJailbreak;
@property (nonatomic, readonly) BOOL spoofIDFA;
@property (nonatomic, readonly) BOOL spoofIDFV;
@property (nonatomic, readonly) BOOL spoofBattery;

// Network mode: 0=default, 1=wifi, 2=cellular
@property (nonatomic, readonly) NSInteger networkMode;
@property (nonatomic, readonly) NSString *wifiSSID;
@property (nonatomic, readonly) NSString *wifiBSSID;
@property (nonatomic, readonly) NSString *cellularServiceID;
@property (nonatomic, readonly) NSString *cellularIPv4;
@property (nonatomic, readonly) NSString *cellularRouter;
// iOS version spoof
@property (nonatomic, readonly) NSString *systemVersion;
// Storage spoof (GB)
@property (nonatomic, readonly) NSUInteger totalStorage;
@property (nonatomic, readonly) NSUInteger freeStorage;
// Power state
@property (nonatomic, readonly) BOOL lowPowerMode;
@property (nonatomic, readonly) NSString *buildID;
@property (nonatomic, readonly) NSString *uniqueID;
@property (nonatomic, readonly) NSString *pasteboardUUID;
@property (nonatomic, readonly) NSString *deviceName;

// Bluetooth
@property (nonatomic, readonly) NSString *bluetoothMAC;
@property (nonatomic, readonly) NSString *bluetoothDeviceName;
@property (nonatomic, readonly) BOOL bluetoothConnected;
// Carrier signal strength (0-4 bars)
@property (nonatomic, readonly) NSInteger signalStrength;

// Locale / Timezone / Timestamp
@property (nonatomic, readonly) NSString *localeIdentifier;  // e.g. "en_US"
@property (nonatomic, readonly) NSString *timezoneIdentifier; // e.g. "Asia/Ho_Chi_Minh"
@property (nonatomic, readonly) NSTimeInterval timestampOffset;

// Kernel-Level Spoof mode
@property (nonatomic, readonly) BOOL kernelMode; // seconds to offset

/** Danh sách bundle ID mục tiêu. Nếu rỗng = không inject vào app nào. */
@property (nonatomic, readonly) NSArray *targetBundles;

/** Kiểm tra process hiện tại có nên inject hook hay không. */
- (BOOL)shouldInjectForCurrentBundle;

/** Preset đã resolve (kèm per-bundle override nếu có). */
@property (nonatomic, readonly) SCDevicePreset *resolvedPreset;

/** UDID/serial/ECID/IMEI/MAC/IDFA đã sinh & cache cho process hiện tại. */
@property (nonatomic, readonly) NSString *spoofedUDID;
@property (nonatomic, readonly) NSString *spoofedSerial;
@property (nonatomic, readonly) NSString *spoofedECID;
@property (nonatomic, readonly) NSString *spoofedIMEI;
@property (nonatomic, readonly) NSString *spoofedMAC;
@property (nonatomic, readonly) NSString *spoofedIDFA;

+ (instancetype)shared;

/** Reload config từ preferences (gọi khi nhận notification đổi prefs). */
- (void)reload;

/** Bundle id của process hiện tại. */
- (NSString *)currentBundleID;

@end

/** Notification name khi preferences thay đổi. */
extern NSNotificationName const SCSpoofConfigDidChangeNotification;
