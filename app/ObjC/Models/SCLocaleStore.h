#import <Foundation/Foundation.h>

@interface SCLocaleStore : NSObject
+ (NSArray<NSDictionary *> *)allLocales;
+ (NSDictionary *)localeForCountryCode:(NSString *)code;
+ (NSDictionary *)localeForGeo:(double)lat lon:(double)lon;
+ (NSArray<NSDictionary *> *)searchLocales:(NSString *)query;
@end
