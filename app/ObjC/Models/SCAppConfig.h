#import <Foundation/Foundation.h>

extern NSString * const SCPreferencesChangedNotification;

@interface SCAppConfig : NSObject

@property (nonatomic) BOOL enabled;
@property (nonatomic, copy) NSString *productType;
@property (nonatomic) BOOL randomizeOnLaunch;
@property (nonatomic, copy) NSArray<NSString *> *targetBundles;

@property (nonatomic, copy) NSString *carrierName;
@property (nonatomic, copy) NSString *carrierMCC;
@property (nonatomic, copy) NSString *carrierMNC;
@property (nonatomic, copy) NSString *carrierISO;
@property (nonatomic, copy) NSString *radioTech;
@property (nonatomic, copy) NSArray<NSDictionary *> *simSlots;
@property (nonatomic) NSInteger activeSIMIndex;

@property (nonatomic) BOOL geoEnabled;
@property (nonatomic) double latitude;
@property (nonatomic) double longitude;
@property (nonatomic) double altitude;
@property (nonatomic) double horizontalAccuracy;
@property (nonatomic) double heading;

@property (nonatomic) BOOL proxyEnabled;
@property (nonatomic, copy) NSString *proxyType;
@property (nonatomic, copy) NSString *proxyHost;
@property (nonatomic) NSInteger proxyPort;
@property (nonatomic, copy) NSString *proxyUser;
@property (nonatomic, copy) NSString *proxyPass;
@property (nonatomic) BOOL proxyUDP;

@property (nonatomic) BOOL hideProxy;
@property (nonatomic) BOOL hideVPN;
@property (nonatomic) BOOL hideJailbreak;
@property (nonatomic) BOOL spoofIDFA;
@property (nonatomic) BOOL spoofIDFV;
@property (nonatomic) BOOL spoofBattery;

// Network mode: 0=default, 1=wifi, 2=cellular
@property (nonatomic) NSInteger networkMode;
// Virtual WiFi BSSID/SSID
@property (nonatomic, copy) NSString *wifiSSID;
@property (nonatomic, copy) NSString *wifiBSSID;
// Virtual cellular network identity
@property (nonatomic, copy) NSString *cellularServiceID;
@property (nonatomic, copy) NSString *cellularIPv4;
@property (nonatomic, copy) NSString *cellularRouter;
// Phone number spoof
@property (nonatomic, copy) NSString *phoneNumber;
// Geo from IP
@property (nonatomic) BOOL geoFromIP;
// IP geo cached data
@property (nonatomic, copy) NSString *geoIPCity;
@property (nonatomic, copy) NSString *geoIPCountry;
@property (nonatomic, copy) NSString *geoIPIsp;

// iOS version / system spoof
@property (nonatomic, copy) NSString *systemVersion;
@property (nonatomic, copy) NSString *buildID;
@property (nonatomic, copy) NSString *uniqueID;
// Storage spoof (GB)
@property (nonatomic) NSUInteger totalStorage;
@property (nonatomic) NSUInteger freeStorage;
// Power state
@property (nonatomic) BOOL lowPowerMode;

// Custom device name (overrides marketingName)
@property (nonatomic, copy) NSString *deviceName;

// Bluetooth spoof
@property (nonatomic, copy) NSString *bluetoothMAC;
@property (nonatomic, copy) NSString *bluetoothDeviceName;
@property (nonatomic) BOOL bluetoothConnected;
// Carrier signal strength (0-4)
@property (nonatomic) NSInteger signalStrength;

// Locale / Timezone / Timestamp
@property (nonatomic, copy) NSString *localeIdentifier;
@property (nonatomic, copy) NSString *timezoneIdentifier;
@property (nonatomic) NSTimeInterval timestampOffset;

// Kernel-Level Spoof mode
@property (nonatomic) BOOL kernelMode;
+ (BOOL)systemhookInstalled;

+ (instancetype)shared;
- (void)load;
- (void)save;
- (void)resetAll;
- (void)randomizeAll;
- (void)fetchGeoFromIP;
- (NSDictionary *)resolvedPreset;
- (NSDictionary *)cachedIDsForBundle:(NSString *)bundleID;
- (void)clearIDCache;
- (NSString *)prefsPath;
- (NSString *)idsPath;

@end
