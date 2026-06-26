#import "SCDevicePresets.h"

#pragma mark - SCDevicePreset

@implementation SCDevicePreset

- (id)copyWithZone:(NSZone *)zone {
    SCDevicePreset *c = [SCDevicePreset new];
    for (NSString *k in [self dictionaryWithValuesForKeys:@[
        @"productType",@"marketingName",@"productName",@"hardwareModel",
        @"modelNumber",@"deviceClass",@"boardId",@"chipId",@"cpuArchitecture",
        @"internalName",@"regionCode",@"regulatoryModelNumber",
        @"screenWidth",@"screenHeight",@"screenScale",@"screenInches",@"ppi",
        @"capacityGB",@"colorCode",@"carrierName",@"carrierMCC",@"carrierMNC",
        @"carrierISO",@"radioTech",@"batteryLevel",@"batteryState"]]) {
        [c setValue:[self valueForKey:k] forKey:k];
    }
    return c;
}

- (NSDictionary *)dictionaryRepresentation {
    return @{
        @"productType": self.productType ?: @"",
        @"marketingName": self.marketingName ?: @"",
        @"productName": self.productName ?: @"",
        @"hardwareModel": self.hardwareModel ?: @"",
        @"modelNumber": self.modelNumber ?: @"",
        @"deviceClass": self.deviceClass ?: @"",
        @"boardId": self.boardId ?: @"",
        @"chipId": self.chipId ?: @"",
        @"cpuArchitecture": self.cpuArchitecture ?: @"",
        @"internalName": self.internalName ?: @"",
        @"regionCode": self.regionCode ?: @"",
        @"regulatoryModelNumber": self.regulatoryModelNumber ?: @"",
        @"screenWidth": @(self.screenWidth),
        @"screenHeight": @(self.screenHeight),
        @"screenScale": @(self.screenScale),
        @"screenInches": @(self.screenInches),
        @"ppi": @(self.ppi),
        @"capacityGB": self.capacityGB ?: @"",
        @"colorCode": self.colorCode ?: @"",
        @"carrierName": self.carrierName ?: @"",
        @"carrierMCC": self.carrierMCC ?: @"",
        @"carrierMNC": self.carrierMNC ?: @"",
        @"carrierISO": self.carrierISO ?: @"",
        @"radioTech": self.radioTech ?: @"",
        @"batteryLevel": self.batteryLevel ?: @0,
        @"batteryState": self.batteryState ?: @""
    };
}

+ (instancetype)presetFromDictionary:(NSDictionary *)dict {
    SCDevicePreset *p = [SCDevicePreset new];
    p.productType = dict[@"productType"];
    p.marketingName = dict[@"marketingName"];
    p.productName = dict[@"productName"];
    p.hardwareModel = dict[@"hardwareModel"];
    p.modelNumber = dict[@"modelNumber"];
    p.deviceClass = dict[@"deviceClass"];
    p.boardId = dict[@"boardId"];
    p.chipId = dict[@"chipId"];
    p.cpuArchitecture = dict[@"cpuArchitecture"];
    p.internalName = dict[@"internalName"];
    p.regionCode = dict[@"regionCode"];
    p.regulatoryModelNumber = dict[@"regulatoryModelNumber"];
    p.screenWidth = [dict[@"screenWidth"] unsignedIntegerValue];
    p.screenHeight = [dict[@"screenHeight"] unsignedIntegerValue];
    p.screenScale = [dict[@"screenScale"] unsignedIntegerValue];
    p.screenInches = [dict[@"screenInches"] doubleValue];
    p.ppi = [dict[@"ppi"] unsignedIntegerValue];
    p.capacityGB = dict[@"capacityGB"];
    p.colorCode = dict[@"colorCode"];
    p.carrierName = dict[@"carrierName"];
    p.carrierMCC = dict[@"carrierMCC"];
    p.carrierMNC = dict[@"carrierMNC"];
    p.carrierISO = dict[@"carrierISO"];
    p.radioTech = dict[@"radioTech"];
    p.batteryLevel = dict[@"batteryLevel"];
    p.batteryState = dict[@"batteryState"];
    return p;
}

@end

#pragma mark - Helpers random

static NSString *sc_rand_hex(NSUInteger len) {
    static const char *h = "0123456789abcdef";
    NSMutableString *s = [NSMutableString stringWithCapacity:len];
    for (NSUInteger i = 0; i < len; i++) {
        [s appendFormat:@"%c", h[arc4random_uniform(16)]];
    }
    return s;
}

static NSString *sc_rand_alnum_upper(NSUInteger len) {
    static const char *a = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    NSMutableString *s = [NSMutableString stringWithCapacity:len];
    for (NSUInteger i = 0; i < len; i++) {
        [s appendFormat:@"%c", a[arc4random_uniform(36)]];
    }
    return s;
}

@implementation SCDevicePresets

+ (NSString *)generateUDID {
    // 40 hex, resembles real UDID format (Apple dùng 40 hex)
    return sc_rand_hex(40);
}

+ (NSString *)generateSerialNumber {
    // Modern serial: 10 ký tự alphanumeric
    return sc_rand_alnum_upper(10);
}

+ (NSString *)generateECID {
    // 13-16 hex uppercase
    return [sc_rand_hex(13) uppercaseString];
}

+ (NSString *)generateMAC {
    // Locally administered, unicast
    uint8_t b[6];
    for (int i = 0; i < 6; i++) b[i] = (uint8_t)arc4random_uniform(256);
    b[0] = (b[0] & 0xFE) | 0x02; // locally administered, unicast
    return [NSString stringWithFormat:@"%02X:%02X:%02X:%02X:%02X:%02X",
            b[0],b[1],b[2],b[3],b[4],b[5]];
}

+ (NSString *)generateIMEI {
    // 15 số, kiểm tra Luhn
    int digits[15];
    // Cơ sở: TAC 35 + 8 số random
    digits[0]=3; digits[1]=5;
    for (int i = 2; i < 14; i++) digits[i] = (int)arc4random_uniform(10);
    // Luhn check digit
    int sum = 0;
    for (int i = 0; i < 14; i++) {
        int d = digits[i];
        if (i % 2 == 1) {
            d *= 2;
            if (d > 9) d -= 9;
        }
        sum += d;
    }
    int check = (10 - (sum % 10)) % 10;
    digits[14] = check;
    NSMutableString *s = [NSMutableString stringWithCapacity:15];
    for (int i = 0; i < 15; i++) [s appendFormat:@"%d", digits[i]];
    return s;
}

+ (NSString *)generateIDFA {
    // UUID uppercase no dashes -> 32 hex, hoặc UUID format
    return [[NSUUID UUID].UUIDString uppercaseString];
}

+ (NSArray<SCDevicePreset *> *)allPresets {
    static NSArray *presets = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSArray *raw = @[
            // ===== iPhone 8 =====
            @{
                @"productType":@"iPhone10,1", @"marketingName":@"iPhone 8",
                @"productName":@"iPhone", @"hardwareModel":@"D20AP",
                @"modelNumber":@"MQ6G3LL/A", @"deviceClass":@"D20",
                @"boardId":@"0x0A", @"chipId":@"t8015", @"cpuArchitecture":@"arm64e",
                @"internalName":@"D20AP", @"regionCode":@"LL/A",
                @"regulatoryModelNumber":@"A1863",
                @"screenWidth":@(750), @"screenHeight":@(1334), @"screenScale":@(2),
                @"screenInches":@(4.7), @"ppi":@(326),
                @"capacityGB":@"128", @"colorCode":@"Space Gray",
                @"carrierName":@"Viettel", @"carrierMCC":@"452", @"carrierMNC":@"04",
                @"carrierISO":@"vn", @"radioTech":@"CTRadioAccessTechnologyLTE",
                @"batteryLevel":@0.82, @"batteryState":@"uncharging"
            },
            // ===== iPhone X =====
            @{
                @"productType":@"iPhone10,3", @"marketingName":@"iPhone X",
                @"productName":@"iPhone", @"hardwareModel":@"D22AP",
                @"modelNumber":@"MQAQ2LL/A", @"deviceClass":@"D22",
                @"boardId":@"0x0C", @"chipId":@"t8015", @"cpuArchitecture":@"arm64e",
                @"internalName":@"D22AP", @"regionCode":@"LL/A",
                @"regulatoryModelNumber":@"A1865",
                @"screenWidth":@(1125), @"screenHeight":@(2436), @"screenScale":@(3),
                @"screenInches":@(5.8), @"ppi":@(458),
                @"capacityGB":@"256", @"colorCode":@"Space Gray",
                @"carrierName":@"Viettel", @"carrierMCC":@"452", @"carrierMNC":@"04",
                @"carrierISO":@"vn", @"radioTech":@"CTRadioAccessTechnologyLTE",
                @"batteryLevel":@0.76, @"batteryState":@"uncharging"
            },
            // ===== iPhone 11 =====
            @{
                @"productType":@"iPhone12,1", @"marketingName":@"iPhone 11",
                @"productName":@"iPhone", @"hardwareModel":@"N104AP",
                @"modelNumber":@"MWLU2LL/A", @"deviceClass":@"N104",
                @"boardId":@"0x0A", @"chipId":@"t8030", @"cpuArchitecture":@"arm64e",
                @"internalName":@"N104AP", @"regionCode":@"LL/A",
                @"regulatoryModelNumber":@"A2111",
                @"screenWidth":@(828), @"screenHeight":@(1792), @"screenScale":@(2),
                @"screenInches":@(6.1), @"ppi":@(326),
                @"capacityGB":@"128", @"colorCode":@"Black",
                @"carrierName":@"Viettel", @"carrierMCC":@"452", @"carrierMNC":@"04",
                @"carrierISO":@"vn", @"radioTech":@"CTRadioAccessTechnologyLTE",
                @"batteryLevel":@0.91, @"batteryState":@"uncharging"
            },
            // ===== iPhone 12 =====
            @{
                @"productType":@"iPhone13,2", @"marketingName":@"iPhone 12",
                @"productName":@"iPhone", @"hardwareModel":@"D53gAP",
                @"modelNumber":@"MGE93LL/A", @"deviceClass":@"D53g",
                @"boardId":@"0x0A", @"chipId":@"t8101", @"cpuArchitecture":@"arm64e",
                @"internalName":@"D53gAP", @"regionCode":@"LL/A",
                @"regulatoryModelNumber":@"A2172",
                @"screenWidth":@(1170), @"screenHeight":@(2532), @"screenScale":@(3),
                @"screenInches":@(6.1), @"ppi":@(460),
                @"capacityGB":@"256", @"colorCode":@"Black",
                @"carrierName":@"Viettel", @"carrierMCC":@"452", @"carrierMNC":@"04",
                @"carrierISO":@"vn", @"radioTech":@"CTRadioAccessTechnologyNRNSA",
                @"batteryLevel":@0.68, @"batteryState":@"uncharging"
            },
            // ===== iPhone 13 =====
            @{
                @"productType":@"iPhone14,5", @"marketingName":@"iPhone 13",
                @"productName":@"iPhone", @"hardwareModel":@"D63AP",
                @"modelNumber":@"MLNG3LL/A", @"deviceClass":@"D63",
                @"boardId":@"0x08", @"chipId":@"t8110", @"cpuArchitecture":@"arm64e",
                @"internalName":@"D63AP", @"regionCode":@"LL/A",
                @"regulatoryModelNumber":@"A2633",
                @"screenWidth":@(1170), @"screenHeight":@(2532), @"screenScale":@(3),
                @"screenInches":@(6.1), @"ppi":@(460),
                @"capacityGB":@"256", @"colorCode":@"Sierra Blue",
                @"carrierName":@"Viettel", @"carrierMCC":@"452", @"carrierMNC":@"04",
                @"carrierISO":@"vn", @"radioTech":@"CTRadioAccessTechnologyNRNSA",
                @"batteryLevel":@0.85, @"batteryState":@"uncharging"
            },
            // ===== iPhone 13 Pro =====
            @{
                @"productType":@"iPhone14,2", @"marketingName":@"iPhone 13 Pro",
                @"productName":@"iPhone", @"hardwareModel":@"D63pAP",
                @"modelNumber":@"MLTT3LL/A", @"deviceClass":@"D63p",
                @"boardId":@"0x0A", @"chipId":@"t8110", @"cpuArchitecture":@"arm64e",
                @"internalName":@"D63pAP", @"regionCode":@"LL/A",
                @"regulatoryModelNumber":@"A2482",
                @"screenWidth":@(1170), @"screenHeight":@(2532), @"screenScale":@(3),
                @"screenInches":@(6.1), @"ppi":@(460),
                @"capacityGB":@"256", @"colorCode":@"Graphite",
                @"carrierName":@"Viettel", @"carrierMCC":@"452", @"carrierMNC":@"04",
                @"carrierISO":@"vn", @"radioTech":@"CTRadioAccessTechnologyNRNSA",
                @"batteryLevel":@0.79, @"batteryState":@"uncharging"
            },
            // ===== iPhone 14 =====
            @{
                @"productType":@"iPhone14,7", @"marketingName":@"iPhone 14",
                @"productName":@"iPhone", @"hardwareModel":@"D27AP",
                @"modelNumber":@"MMX93LL/A", @"deviceClass":@"D27",
                @"boardId":@"0x08", @"chipId":@"t8110", @"cpuArchitecture":@"arm64e",
                @"internalName":@"D27AP", @"regionCode":@"LL/A",
                @"regulatoryModelNumber":@"A2649",
                @"screenWidth":@(1170), @"screenHeight":@(2532), @"screenScale":@(3),
                @"screenInches":@(6.1), @"ppi":@(460),
                @"capacityGB":@"256", @"colorCode":@"Midnight",
                @"carrierName":@"Viettel", @"carrierMCC":@"452", @"carrierMNC":@"04",
                @"carrierISO":@"vn", @"radioTech":@"CTRadioAccessTechnologyNRNSA",
                @"batteryLevel":@0.88, @"batteryState":@"uncharging"
            },
            // ===== iPhone 14 Pro =====
            @{
                @"productType":@"iPhone15,2", @"marketingName":@"iPhone 14 Pro",
                @"productName":@"iPhone", @"hardwareModel":@"D14AP",
                @"modelNumber":@"MTLV3LL/A", @"deviceClass":@"D14",
                @"boardId":@"0x08", @"chipId":@"t8110", @"cpuArchitecture":@"arm64e",
                @"internalName":@"D14AP", @"regionCode":@"LL/A",
                @"regulatoryModelNumber":@"A2650",
                @"screenWidth":@(1179), @"screenHeight":@(2556), @"screenScale":@(3),
                @"screenInches":@(6.1), @"ppi":@(460),
                @"capacityGB":@"256", @"colorCode":@"Deep Purple",
                @"carrierName":@"Viettel", @"carrierMCC":@"452", @"carrierMNC":@"04",
                @"carrierISO":@"vn", @"radioTech":@"CTRadioAccessTechnologyNRNSA",
                @"batteryLevel":@0.74, @"batteryState":@"uncharging"
            },
            // ===== iPhone 14 Pro Max =====
            @{
                @"productType":@"iPhone15,3", @"marketingName":@"iPhone 14 Pro Max",
                @"productName":@"iPhone", @"hardwareModel":@"D16AP",
                @"modelNumber":@"MU2K3LL/A", @"deviceClass":@"D16",
                @"boardId":@"0x0A", @"chipId":@"t8110", @"cpuArchitecture":@"arm64e",
                @"internalName":@"D16AP", @"regionCode":@"LL/A",
                @"regulatoryModelNumber":@"A2651",
                @"screenWidth":@(1290), @"screenHeight":@(2796), @"screenScale":@(3),
                @"screenInches":@(6.7), @"ppi":@(460),
                @"capacityGB":@"512", @"colorCode":@"Deep Purple",
                @"carrierName":@"Viettel", @"carrierMCC":@"452", @"carrierMNC":@"04",
                @"carrierISO":@"vn", @"radioTech":@"CTRadioAccessTechnologyNRNSA",
                @"batteryLevel":@0.93, @"batteryState":@"uncharging"
            },
            // ===== iPhone 15 =====
            @{
                @"productType":@"iPhone15,4", @"marketingName":@"iPhone 15",
                @"productName":@"iPhone", @"hardwareModel":@"D37AP",
                @"modelNumber":@"MTX93LL/A", @"deviceClass":@"D37",
                @"boardId":@"0x08", @"chipId":@"t8120", @"cpuArchitecture":@"arm64e",
                @"internalName":@"D37AP", @"regionCode":@"LL/A",
                @"regulatoryModelNumber":@"A2846",
                @"screenWidth":@(1179), @"screenHeight":@(2556), @"screenScale":@(3),
                @"screenInches":@(6.1), @"ppi":@(460),
                @"capacityGB":@"256", @"colorCode":@"Pink",
                @"carrierName":@"Viettel", @"carrierMCC":@"452", @"carrierMNC":@"04",
                @"carrierISO":@"vn", @"radioTech":@"CTRadioAccessTechnologyNRNSA",
                @"batteryLevel":@0.81, @"batteryState":@"uncharging"
            },
            // ===== iPhone 15 Pro =====
            @{
                @"productType":@"iPhone16,1", @"marketingName":@"iPhone 15 Pro",
                @"productName":@"iPhone", @"hardwareModel":@"D83AP",
                @"modelNumber":@"MTUW3LL/A", @"deviceClass":@"D83",
                @"boardId":@"0x08", @"chipId":@"t8120", @"cpuArchitecture":@"arm64e",
                @"internalName":@"D83AP", @"regionCode":@"LL/A",
                @"regulatoryModelNumber":@"A2848",
                @"screenWidth":@(1179), @"screenHeight":@(2556), @"screenScale":@(3),
                @"screenInches":@(6.1), @"ppi":@(460),
                @"capacityGB":@"256", @"colorCode":@"Natural Titanium",
                @"carrierName":@"Viettel", @"carrierMCC":@"452", @"carrierMNC":@"04",
                @"carrierISO":@"vn", @"radioTech":@"CTRadioAccessTechnologyNRNSA",
                @"batteryLevel":@0.86, @"batteryState":@"uncharging"
            },
            // ===== iPhone 15 Pro Max =====
            @{
                @"productType":@"iPhone16,2", @"marketingName":@"iPhone 15 Pro Max",
                @"productName":@"iPhone", @"hardwareModel":@"D84AP",
                @"modelNumber":@"MU653LL/A", @"deviceClass":@"D84",
                @"boardId":@"0x0A", @"chipId":@"t8120", @"cpuArchitecture":@"arm64e",
                @"internalName":@"D84AP", @"regionCode":@"LL/A",
                @"regulatoryModelNumber":@"A2849",
                @"screenWidth":@(1290), @"screenHeight":@(2796), @"screenScale":@(3),
                @"screenInches":@(6.7), @"ppi":@(460),
                @"capacityGB":@"512", @"colorCode":@"Blue Titanium",
                @"carrierName":@"Viettel", @"carrierMCC":@"452", @"carrierMNC":@"04",
                @"carrierISO":@"vn", @"radioTech":@"CTRadioAccessTechnologyNRNSA",
                @"batteryLevel":@0.90, @"batteryState":@"uncharging"
            },
        ];
        NSMutableArray *arr = [NSMutableArray arrayWithCapacity:raw.count];
        for (NSDictionary *d in raw) {
            [arr addObject:[SCDevicePreset presetFromDictionary:d]];
        }
        presets = arr;
    });
    return presets;
}

+ (SCDevicePreset *)presetForProductType:(NSString *)productType {
    for (SCDevicePreset *p in [self allPresets]) {
        if ([p.productType isEqualToString:productType]) return p;
    }
    return nil;
}

+ (SCDevicePreset *)randomPreset {
    NSArray *all = [self allPresets];
    return all[arc4random_uniform((uint32_t)all.count)];
}

+ (instancetype)shared { return [self new]; }

@end
