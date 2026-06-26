#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

/**
 * SCDevicePreset
 *
 * Mô tả đầy đủ thông số của một model iPhone. Mọi giá trị đều dựa trên dữ liệu
 * thật (hw.machine, ProductType, resolution, ppi, chip...) để app không thể
 * phát hiện bất nhất giữa các API.
 */
@interface SCDevicePreset : NSObject <NSCopying>

@property (nonatomic, copy) NSString *productType;       // iPhone14,5
@property (nonatomic, copy) NSString *marketingName;     // iPhone 13
@property (nonatomic, copy) NSString *productName;       // iPhone
@property (nonatomic, copy) NSString *hardwareModel;     // D63AP
@property (nonatomic, copy) NSString *modelNumber;       // MLNG3LL/A
@property (nonatomic, copy) NSString *deviceClass;       // D63
@property (nonatomic, copy) NSString *boardId;           // 0x08
@property (nonatomic, copy) NSString *chipId;            // t8101
@property (nonatomic, copy) NSString *cpuArchitecture;   // arm64e
@property (nonatomic, copy) NSString *internalName;      // D63AP
@property (nonatomic, copy) NSString *regionCode;        // LL/A
@property (nonatomic, copy) NSString *regulatoryModelNumber; // A2633

@property (nonatomic) NSUInteger screenWidth;            // 1170
@property (nonatomic) NSUInteger screenHeight;           // 2532
@property (nonatomic) NSUInteger screenScale;            // 3
@property (nonatomic) CGFloat screenInches;              // 6.1
@property (nonatomic) NSUInteger ppi;                    // 460

@property (nonatomic, copy) NSString *capacityGB;        // 256
@property (nonatomic, copy) NSString *colorCode;         // Sierra Blue

@property (nonatomic, copy) NSString *carrierName;       // Viettel
@property (nonatomic, copy) NSString *carrierMCC;        // 452
@property (nonatomic, copy) NSString *carrierMNC;        // 04
@property (nonatomic, copy) NSString *carrierISO;        // vn
@property (nonatomic, copy) NSString *radioTech;         // CTRadioAccessTechnologyLTE

@property (nonatomic, copy) NSNumber *batteryLevel;      // 0.85
@property (nonatomic, copy) NSString *batteryState;      // uncharging

- (NSDictionary *)dictionaryRepresentation;
+ (instancetype)presetFromDictionary:(NSDictionary *)dict;

@end

/**
 * SCDevicePresets
 * Quản lý danh sách preset built-in + randomize.
 */
@interface SCDevicePresets : NSObject

+ (instancetype)shared;

/** Tất cả preset built-in, theo key = productType. */
+ (NSArray<SCDevicePreset *> *)allPresets;

/** Lấy preset theo productType. */
+ (SCDevicePreset *)presetForProductType:(NSString *)productType;

/** Random một preset bất kỳ. */
+ (SCDevicePreset *)randomPreset;

/** Sinh UDID 40 ký tự hex hợp lệ. */
+ (NSString *)generateUDID;

/** Sinh serial number 12 ký tự. */
+ (NSString *)generateSerialNumber;

/** Sinh ECID 13-16 hex. */
+ (NSString *)generateECID;

/** Sinh WiFi MAC hợp lệ (locally administered). */
+ (NSString *)generateMAC;

/** Sinh IMEI 15 số (Luhn). */
+ (NSString *)generateIMEI;

/** Sinh IDFA / IDFV format. */
+ (NSString *)generateIDFA;

@end
