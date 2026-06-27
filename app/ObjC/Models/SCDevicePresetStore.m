#import "SCDevicePresetStore.h"

@implementation SCDevicePresetStore

+ (NSArray<NSDictionary *> *)allPresets {
    static NSArray *presets;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        presets = @[
            @{ @"productType":@"iPhone10,1", @"marketingName":@"iPhone 8", @"hardwareModel":@"D20AP", @"modelNumber":@"MQ6G3LL/A", @"deviceClass":@"D20", @"boardId":@"0x0A", @"chipId":@"t8015", @"cpuArchitecture":@"arm64e", @"screenWidth":@750, @"screenHeight":@1334, @"screenScale":@2, @"screenInches":@4.7, @"ppi":@326, @"capacityGB":@"128", @"carrierName":@"Viettel", @"carrierMCC":@"452", @"carrierMNC":@"04", @"carrierISO":@"vn", @"radioTech":@"CTRadioAccessTechnologyLTE", @"systemVersion":@"16.7", @"buildID":@"20H19" },
            @{ @"productType":@"iPhone10,3", @"marketingName":@"iPhone X", @"hardwareModel":@"D22AP", @"modelNumber":@"MQAQ2LL/A", @"deviceClass":@"D22", @"boardId":@"0x0C", @"chipId":@"t8015", @"cpuArchitecture":@"arm64e", @"screenWidth":@1125, @"screenHeight":@2436, @"screenScale":@3, @"screenInches":@5.8, @"ppi":@458, @"capacityGB":@"256", @"carrierName":@"Viettel", @"carrierMCC":@"452", @"carrierMNC":@"04", @"carrierISO":@"vn", @"radioTech":@"CTRadioAccessTechnologyLTE", @"systemVersion":@"16.7", @"buildID":@"20H19" },
            @{ @"productType":@"iPhone12,1", @"marketingName":@"iPhone 11", @"hardwareModel":@"N104AP", @"modelNumber":@"MWLU2LL/A", @"deviceClass":@"N104", @"boardId":@"0x0A", @"chipId":@"t8030", @"cpuArchitecture":@"arm64e", @"screenWidth":@828, @"screenHeight":@1792, @"screenScale":@2, @"screenInches":@6.1, @"ppi":@326, @"capacityGB":@"128", @"carrierName":@"Viettel", @"carrierMCC":@"452", @"carrierMNC":@"04", @"carrierISO":@"vn", @"radioTech":@"CTRadioAccessTechnologyLTE", @"systemVersion":@"16.7", @"buildID":@"20H19" },
            @{ @"productType":@"iPhone13,2", @"marketingName":@"iPhone 12", @"hardwareModel":@"D53gAP", @"modelNumber":@"MGE93LL/A", @"deviceClass":@"D53g", @"boardId":@"0x0A", @"chipId":@"t8101", @"cpuArchitecture":@"arm64e", @"screenWidth":@1170, @"screenHeight":@2532, @"screenScale":@3, @"screenInches":@6.1, @"ppi":@460, @"capacityGB":@"256", @"carrierName":@"Viettel", @"carrierMCC":@"452", @"carrierMNC":@"04", @"carrierISO":@"vn", @"radioTech":@"CTRadioAccessTechnologyNRNSA", @"systemVersion":@"17.5", @"buildID":@"21F90" },
            @{ @"productType":@"iPhone14,5", @"marketingName":@"iPhone 13", @"hardwareModel":@"D63AP", @"modelNumber":@"MLNG3LL/A", @"deviceClass":@"D63", @"boardId":@"0x08", @"chipId":@"t8110", @"cpuArchitecture":@"arm64e", @"screenWidth":@1170, @"screenHeight":@2532, @"screenScale":@3, @"screenInches":@6.1, @"ppi":@460, @"capacityGB":@"256", @"carrierName":@"Viettel", @"carrierMCC":@"452", @"carrierMNC":@"04", @"carrierISO":@"vn", @"radioTech":@"CTRadioAccessTechnologyNRNSA", @"systemVersion":@"17.5", @"buildID":@"21F90" },
            @{ @"productType":@"iPhone14,2", @"marketingName":@"iPhone 13 Pro", @"hardwareModel":@"D63pAP", @"modelNumber":@"MLTT3LL/A", @"deviceClass":@"D63p", @"boardId":@"0x0A", @"chipId":@"t8110", @"cpuArchitecture":@"arm64e", @"screenWidth":@1170, @"screenHeight":@2532, @"screenScale":@3, @"screenInches":@6.1, @"ppi":@460, @"capacityGB":@"256", @"carrierName":@"Viettel", @"carrierMCC":@"452", @"carrierMNC":@"04", @"carrierISO":@"vn", @"radioTech":@"CTRadioAccessTechnologyNRNSA", @"systemVersion":@"17.5", @"buildID":@"21F90" },
            @{ @"productType":@"iPhone14,7", @"marketingName":@"iPhone 14", @"hardwareModel":@"D27AP", @"modelNumber":@"MMX93LL/A", @"deviceClass":@"D27", @"boardId":@"0x08", @"chipId":@"t8110", @"cpuArchitecture":@"arm64e", @"screenWidth":@1170, @"screenHeight":@2532, @"screenScale":@3, @"screenInches":@6.1, @"ppi":@460, @"capacityGB":@"256", @"carrierName":@"Viettel", @"carrierMCC":@"452", @"carrierMNC":@"04", @"carrierISO":@"vn", @"radioTech":@"CTRadioAccessTechnologyNRNSA", @"systemVersion":@"17.5", @"buildID":@"21F90" },
            @{ @"productType":@"iPhone15,2", @"marketingName":@"iPhone 14 Pro", @"hardwareModel":@"D14AP", @"modelNumber":@"MTLV3LL/A", @"deviceClass":@"D14", @"boardId":@"0x08", @"chipId":@"t8110", @"cpuArchitecture":@"arm64e", @"screenWidth":@1179, @"screenHeight":@2556, @"screenScale":@3, @"screenInches":@6.1, @"ppi":@460, @"capacityGB":@"256", @"carrierName":@"Viettel", @"carrierMCC":@"452", @"carrierMNC":@"04", @"carrierISO":@"vn", @"radioTech":@"CTRadioAccessTechnologyNRNSA", @"systemVersion":@"17.5", @"buildID":@"21F90" },
            @{ @"productType":@"iPhone15,3", @"marketingName":@"iPhone 14 Pro Max", @"hardwareModel":@"D16AP", @"modelNumber":@"MU2K3LL/A", @"deviceClass":@"D16", @"boardId":@"0x0A", @"chipId":@"t8110", @"cpuArchitecture":@"arm64e", @"screenWidth":@1290, @"screenHeight":@2796, @"screenScale":@3, @"screenInches":@6.7, @"ppi":@460, @"capacityGB":@"512", @"carrierName":@"Viettel", @"carrierMCC":@"452", @"carrierMNC":@"04", @"carrierISO":@"vn", @"radioTech":@"CTRadioAccessTechnologyNRNSA", @"systemVersion":@"17.5", @"buildID":@"21F90" },
            @{ @"productType":@"iPhone15,4", @"marketingName":@"iPhone 15", @"hardwareModel":@"D37AP", @"modelNumber":@"MTX93LL/A", @"deviceClass":@"D37", @"boardId":@"0x08", @"chipId":@"t8120", @"cpuArchitecture":@"arm64e", @"screenWidth":@1179, @"screenHeight":@2556, @"screenScale":@3, @"screenInches":@6.1, @"ppi":@460, @"capacityGB":@"256", @"carrierName":@"Viettel", @"carrierMCC":@"452", @"carrierMNC":@"04", @"carrierISO":@"vn", @"radioTech":@"CTRadioAccessTechnologyNRNSA", @"systemVersion":@"17.5", @"buildID":@"21F90" },
            @{ @"productType":@"iPhone16,1", @"marketingName":@"iPhone 15 Pro", @"hardwareModel":@"D83AP", @"modelNumber":@"MTUW3LL/A", @"deviceClass":@"D83", @"boardId":@"0x08", @"chipId":@"t8120", @"cpuArchitecture":@"arm64e", @"screenWidth":@1179, @"screenHeight":@2556, @"screenScale":@3, @"screenInches":@6.1, @"ppi":@460, @"capacityGB":@"256", @"carrierName":@"Viettel", @"carrierMCC":@"452", @"carrierMNC":@"04", @"carrierISO":@"vn", @"radioTech":@"CTRadioAccessTechnologyNRNSA", @"systemVersion":@"17.5", @"buildID":@"21F90" },
            @{ @"productType":@"iPhone16,2", @"marketingName":@"iPhone 15 Pro Max", @"hardwareModel":@"D84AP", @"modelNumber":@"MU653LL/A", @"deviceClass":@"D84", @"boardId":@"0x0A", @"chipId":@"t8120", @"cpuArchitecture":@"arm64e", @"screenWidth":@1290, @"screenHeight":@2796, @"screenScale":@3, @"screenInches":@6.7, @"ppi":@460, @"capacityGB":@"512", @"carrierName":@"Viettel", @"carrierMCC":@"452", @"carrierMNC":@"04", @"carrierISO":@"vn", @"radioTech":@"CTRadioAccessTechnologyNRNSA", @"systemVersion":@"17.5", @"buildID":@"21F90" }
        ];
    });
    return presets;
}

+ (NSDictionary *)presetForProductType:(NSString *)productType {
    for (NSDictionary *p in [self allPresets]) if ([p[@"productType"] isEqualToString:productType]) return p;
    return nil;
}

+ (NSDictionary *)randomPreset {
    NSArray *all = [self allPresets];
    return all[arc4random_uniform((uint32_t)all.count)];
}

+ (NSArray<NSNumber *> *)storageOptionsForProductType:(NSString *)productType {
    NSDictionary *p = [self presetForProductType:productType];
    if (!p) return @[@64, @128, @256, @512];
    // iPhone 8/X: 64, 128, 256
    // iPhone 11-14: 128, 256, 512
    // iPhone 15 Pro: 128, 256, 512, 1024
    NSString *pt = p[@"productType"];
    if ([pt hasPrefix:@"iPhone10,"]) return @[@64, @128, @256];
    if ([pt hasPrefix:@"iPhone16,"]) return @[@128, @256, @512, @1024];
    return @[@128, @256, @512];
}

+ (NSDictionary *)iosVersionOptions {
    return @{
        @"iOS 15.8":  @{ @"version": @"15.8", @"build": @"19H370" },
        @"iOS 16.7":  @{ @"version": @"16.7", @"build": @"20H19" },
        @"iOS 17.5":  @{ @"version": @"17.5", @"build": @"21F90" },
        @"iOS 17.6":  @{ @"version": @"17.6", @"build": @"21G80" },
        @"iOS 17.7":  @{ @"version": @"17.7", @"build": @"21H30" },
        @"iOS 18.0":  @{ @"version": @"18.0", @"build": @"22A3354" },
        @"iOS 18.1":  @{ @"version": @"18.1", @"build": @"22B83" },
        @"iOS 18.2":  @{ @"version": @"18.2", @"build": @"22C152" }
    };
}

@end
