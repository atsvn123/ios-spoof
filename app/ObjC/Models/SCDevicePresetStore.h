#import <Foundation/Foundation.h>

@interface SCDevicePresetStore : NSObject
+ (NSArray<NSDictionary *> *)allPresets;
+ (NSDictionary *)presetForProductType:(NSString *)productType;
+ (NSDictionary *)randomPreset;
@end
