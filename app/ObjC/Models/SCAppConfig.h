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

+ (instancetype)shared;
- (void)load;
- (void)save;
- (void)resetAll;
- (void)randomizeAll;
- (NSDictionary *)resolvedPreset;
- (NSDictionary *)cachedIDsForBundle:(NSString *)bundleID;
- (void)clearIDCache;
- (NSString *)prefsPath;
- (NSString *)idsPath;

@end
