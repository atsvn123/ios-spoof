#import "SCLocaleStore.h"

@implementation SCLocaleStore

+ (NSArray<NSDictionary *> *)allLocales {
    static NSArray *locales;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        locales = @[
            @{ @"country": @"Vietnam", @"code": @"VN", @"locale": @"vi_VN", @"tz": @"Asia/Ho_Chi_Minh", @"lang": @"vi" },
            @{ @"country": @"United States", @"code": @"US", @"locale": @"en_US", @"tz": @"America/New_York", @"lang": @"en" },
            @{ @"country": @"United Kingdom", @"code": @"GB", @"locale": @"en_GB", @"tz": @"Europe/London", @"lang": @"en" },
            @{ @"country": @"Japan", @"code": @"JP", @"locale": @"ja_JP", @"tz": @"Asia/Tokyo", @"lang": @"ja" },
            @{ @"country": @"South Korea", @"code": @"KR", @"locale": @"ko_KR", @"tz": @"Asia/Seoul", @"lang": @"ko" },
            @{ @"country": @"China", @"code": @"CN", @"locale": @"zh_CN", @"tz": @"Asia/Shanghai", @"lang": @"zh-Hans" },
            @{ @"country": @"Taiwan", @"code": @"TW", @"locale": @"zh_TW", @"tz": @"Asia/Taipei", @"lang": @"zh-Hant" },
            @{ @"country": @"Hong Kong", @"code": @"HK", @"locale": @"zh_HK", @"tz": @"Asia/Hong_Kong", @"lang": @"zh-Hant" },
            @{ @"country": @"Singapore", @"code": @"SG", @"locale": @"en_SG", @"tz": @"Asia/Singapore", @"lang": @"en" },
            @{ @"country": @"Thailand", @"code": @"TH", @"locale": @"th_TH", @"tz": @"Asia/Bangkok", @"lang": @"th" },
            @{ @"country": @"Indonesia", @"code": @"ID", @"locale": @"id_ID", @"tz": @"Asia/Jakarta", @"lang": @"id" },
            @{ @"country": @"Malaysia", @"code": @"MY", @"locale": @"ms_MY", @"tz": @"Asia/Kuala_Lumpur", @"lang": @"ms" },
            @{ @"country": @"Philippines", @"code": @"PH", @"locale": @"en_PH", @"tz": @"Asia/Manila", @"lang": @"en" },
            @{ @"country": @"India", @"code": @"IN", @"locale": @"hi_IN", @"tz": @"Asia/Kolkata", @"lang": @"hi" },
            @{ @"country": @"Australia", @"code": @"AU", @"locale": @"en_AU", @"tz": @"Australia/Sydney", @"lang": @"en" },
            @{ @"country": @"New Zealand", @"code": @"NZ", @"locale": @"en_NZ", @"tz": @"Pacific/Auckland", @"lang": @"en" },
            @{ @"country": @"Canada", @"code": @"CA", @"locale": @"en_CA", @"tz": @"America/Toronto", @"lang": @"en" },
            @{ @"country": @"Mexico", @"code": @"MX", @"locale": @"es_MX", @"tz": @"America/Mexico_City", @"lang": @"es" },
            @{ @"country": @"Brazil", @"code": @"BR", @"locale": @"pt_BR", @"tz": @"America/Sao_Paulo", @"lang": @"pt" },
            @{ @"country": @"Argentina", @"code": @"AR", @"locale": @"es_AR", @"tz": @"America/Argentina/Buenos_Aires", @"lang": @"es" },
            @{ @"country": @"Chile", @"code": @"CL", @"locale": @"es_CL", @"tz": @"America/Santiago", @"lang": @"es" },
            @{ @"country": @"Colombia", @"code": @"CO", @"locale": @"es_CO", @"tz": @"America/Bogota", @"lang": @"es" },
            @{ @"country": @"Peru", @"code": @"PE", @"locale": @"es_PE", @"tz": @"America/Lima", @"lang": @"es" },
            @{ @"country": @"France", @"code": @"FR", @"locale": @"fr_FR", @"tz": @"Europe/Paris", @"lang": @"fr" },
            @{ @"country": @"Germany", @"code": @"DE", @"locale": @"de_DE", @"tz": @"Europe/Berlin", @"lang": @"de" },
            @{ @"country": @"Spain", @"code": @"ES", @"locale": @"es_ES", @"tz": @"Europe/Madrid", @"lang": @"es" },
            @{ @"country": @"Italy", @"code": @"IT", @"locale": @"it_IT", @"tz": @"Europe/Rome", @"lang": @"it" },
            @{ @"country": @"Portugal", @"code": @"PT", @"locale": @"pt_PT", @"tz": @"Europe/Lisbon", @"lang": @"pt" },
            @{ @"country": @"Netherlands", @"code": @"NL", @"locale": @"nl_NL", @"tz": @"Europe/Amsterdam", @"lang": @"nl" },
            @{ @"country": @"Belgium", @"code": @"BE", @"locale": @"nl_BE", @"tz": @"Europe/Brussels", @"lang": @"nl" },
            @{ @"country": @"Switzerland", @"code": @"CH", @"locale": @"de_CH", @"tz": @"Europe/Zurich", @"lang": @"de" },
            @{ @"country": @"Austria", @"code": @"AT", @"locale": @"de_AT", @"tz": @"Europe/Vienna", @"lang": @"de" },
            @{ @"country": @"Sweden", @"code": @"SE", @"locale": @"sv_SE", @"tz": @"Europe/Stockholm", @"lang": @"sv" },
            @{ @"country": @"Norway", @"code": @"NO", @"locale": @"nb_NO", @"tz": @"Europe/Oslo", @"lang": @"nb" },
            @{ @"country": @"Denmark", @"code": @"DK", @"locale": @"da_DK", @"tz": @"Europe/Copenhagen", @"lang": @"da" },
            @{ @"country": @"Finland", @"code": @"FI", @"locale": @"fi_FI", @"tz": @"Europe/Helsinki", @"lang": @"fi" },
            @{ @"country": @"Iceland", @"code": @"IS", @"locale": @"is_IS", @"tz": @"Atlantic/Reykjavik", @"lang": @"is" },
            @{ @"country": @"Ireland", @"code": @"IE", @"locale": @"en_IE", @"tz": @"Europe/Dublin", @"lang": @"en" },
            @{ @"country": @"Poland", @"code": @"PL", @"locale": @"pl_PL", @"tz": @"Europe/Warsaw", @"lang": @"pl" },
            @{ @"country": @"Czech Republic", @"code": @"CZ", @"locale": @"cs_CZ", @"tz": @"Europe/Prague", @"lang": @"cs" },
            @{ @"country": @"Hungary", @"code": @"HU", @"locale": @"hu_HU", @"tz": @"Europe/Budapest", @"lang": @"hu" },
            @{ @"country": @"Romania", @"code": @"RO", @"locale": @"ro_RO", @"tz": @"Europe/Bucharest", @"lang": @"ro" },
            @{ @"country": @"Greece", @"code": @"GR", @"locale": @"el_GR", @"tz": @"Europe/Athens", @"lang": @"el" },
            @{ @"country": @"Turkey", @"code": @"TR", @"locale": @"tr_TR", @"tz": @"Europe/Istanbul", @"lang": @"tr" },
            @{ @"country": @"Russia", @"code": @"RU", @"locale": @"ru_RU", @"tz": @"Europe/Moscow", @"lang": @"ru" },
            @{ @"country": @"Ukraine", @"code": @"UA", @"locale": @"uk_UA", @"tz": @"Europe/Kyiv", @"lang": @"uk" },
            @{ @"country": @"Israel", @"code": @"IL", @"locale": @"he_IL", @"tz": @"Asia/Jerusalem", @"lang": @"he" },
            @{ @"country": @"Saudi Arabia", @"code": @"SA", @"locale": @"ar_SA", @"tz": @"Asia/Riyadh", @"lang": @"ar" },
            @{ @"country": @"UAE", @"code": @"AE", @"locale": @"ar_AE", @"tz": @"Asia/Dubai", @"lang": @"ar" },
            @{ @"country": @"Qatar", @"code": @"QA", @"locale": @"ar_QA", @"tz": @"Asia/Qatar", @"lang": @"ar" },
            @{ @"country": @"Kuwait", @"code": @"KW", @"locale": @"ar_KW", @"tz": @"Asia/Kuwait", @"lang": @"ar" },
            @{ @"country": @"Egypt", @"code": @"EG", @"locale": @"ar_EG", @"tz": @"Africa/Cairo", @"lang": @"ar" },
            @{ @"country": @"South Africa", @"code": @"ZA", @"locale": @"en_ZA", @"tz": @"Africa/Johannesburg", @"lang": @"en" },
            @{ @"country": @"Nigeria", @"code": @"NG", @"locale": @"en_NG", @"tz": @"Africa/Lagos", @"lang": @"en" },
            @{ @"country": @"Kenya", @"code": @"KE", @"locale": @"sw_KE", @"tz": @"Africa/Nairobi", @"lang": @"sw" },
            @{ @"country": @"Morocco", @"code": @"MA", @"locale": @"ar_MA", @"tz": @"Africa/Casablanca", @"lang": @"ar" },
            @{ @"country": @"Pakistan", @"code": @"PK", @"locale": @"ur_PK", @"tz": @"Asia/Karachi", @"lang": @"ur" },
            @{ @"country": @"Bangladesh", @"code": @"BD", @"locale": @"bn_BD", @"tz": @"Asia/Dhaka", @"lang": @"bn" },
            @{ @"country": @"Sri Lanka", @"code": @"LK", @"locale": @"si_LK", @"tz": @"Asia/Colombo", @"lang": @"si" },
            @{ @"country": @"Cambodia", @"code": @"KH", @"locale": @"km_KH", @"tz": @"Asia/Phnom_Penh", @"lang": @"km" },
            @{ @"country": @"Laos", @"code": @"LA", @"locale": @"lo_LA", @"tz": @"Asia/Vientiane", @"lang": @"lo" },
            @{ @"country": @"Myanmar", @"code": @"MM", @"locale": @"my_MM", @"tz": @"Asia/Yangon", @"lang": @"my" },
            @{ @"country": @"Nepal", @"code": @"NP", @"locale": @"ne_NP", @"tz": @"Asia/Kathmandu", @"lang": @"ne" },
            @{ @"country": @"Kazakhstan", @"code": @"KZ", @"locale": @"kk_KZ", @"tz": @"Asia/Almaty", @"lang": @"kk" },
            @{ @"country": @"Uzbekistan", @"code": @"UZ", @"locale": @"uz_UZ", @"tz": @"Asia/Tashkent", @"lang": @"uz" },
            @{ @"country": @"Croatia", @"code": @"HR", @"locale": @"hr_HR", @"tz": @"Europe/Zagreb", @"lang": @"hr" },
            @{ @"country": @"Serbia", @"code": @"RS", @"locale": @"sr_RS", @"tz": @"Europe/Belgrade", @"lang": @"sr" },
            @{ @"country": @"Bulgaria", @"code": @"BG", @"locale": @"bg_BG", @"tz": @"Europe/Sofia", @"lang": @"bg" },
            @{ @"country": @"Slovakia", @"code": @"SK", @"locale": @"sk_SK", @"tz": @"Europe/Bratislava", @"lang": @"sk" },
            @{ @"country": @"Slovenia", @"code": @"SI", @"locale": @"sl_SI", @"tz": @"Europe/Ljubljana", @"lang": @"sl" },
            @{ @"country": @"Lithuania", @"code": @"LT", @"locale": @"lt_LT", @"tz": @"Europe/Vilnius", @"lang": @"lt" },
            @{ @"country": @"Latvia", @"code": @"LV", @"locale": @"lv_LV", @"tz": @"Europe/Riga", @"lang": @"lv" },
            @{ @"country": @"Estonia", @"code": @"EE", @"locale": @"et_EE", @"tz": @"Europe/Tallinn", @"lang": @"et" },
            @{ @"country": @"Luxembourg", @"code": @"LU", @"locale": @"fr_LU", @"tz": @"Europe/Luxembourg", @"lang": @"fr" },
            @{ @"country": @"Malta", @"code": @"MT", @"locale": @"mt_MT", @"tz": @"Europe/Malta", @"lang": @"mt" },
            @{ @"country": @"Cyprus", @"code": @"CY", @"locale": @"el_CY", @"tz": @"Asia/Nicosia", @"lang": @"el" },
            @{ @"country": @"Albania", @"code": @"AL", @"locale": @"sq_AL", @"tz": @"Europe/Tirane", @"lang": @"sq" },
            @{ @"country": @"Bosnia", @"code": @"BA", @"locale": @"bs_BA", @"tz": @"Europe/Sarajevo", @"lang": @"bs" },
            @{ @"country": @"Moldova", @"code": @"MD", @"locale": @"ro_MD", @"tz": @"Europe/Chisinau", @"lang": @"ro" },
            @{ @"country": @"Belarus", @"code": @"BY", @"locale": @"be_BY", @"tz": @"Europe/Minsk", @"lang": @"be" },
            @{ @"country": @"Georgia", @"code": @"GE", @"locale": @"ka_GE", @"tz": @"Asia/Tbilisi", @"lang": @"ka" },
            @{ @"country": @"Armenia", @"code": @"AM", @"locale": @"hy_AM", @"tz": @"Asia/Yerevan", @"lang": @"hy" },
            @{ @"country": @"Azerbaijan", @"code": @"AZ", @"locale": @"az_AZ", @"tz": @"Asia/Baku", @"lang": @"az" },
            @{ @"country": @"Vietnam", @"code": @"VN", @"locale": @"vi_VN", @"tz": @"Asia/Ho_Chi_Minh", @"lang": @"vi" },
        ];
    });
    return locales;
}

+ (NSDictionary *)localeForCountryCode:(NSString *)code {
    if (!code.length) return nil;
    NSString *upper = code.uppercaseString;
    for (NSDictionary *l in [self allLocales]) {
        if ([l[@"code"] isEqualToString:upper]) return l;
    }
    return nil;
}

+ (NSDictionary *)localeForGeo:(double)lat lon:(double)lon {
    // Simple geo → timezone mapping for common regions
    // Vietnam
    if (lat >= 8 && lat <= 24 && lon >= 102 && lon <= 110) return [self localeForCountryCode:@"VN"];
    // US East
    if (lat >= 25 && lat <= 49 && lon >= -80 && lon <= -67) return [self localeForCountryCode:@"US"];
    // US West
    if (lat >= 32 && lat <= 49 && lon >= -125 && lon <= -114) return [self localeForCountryCode:@"US"];
    // UK
    if (lat >= 49 && lat <= 61 && lon >= -8 && lon <= 2) return [self localeForCountryCode:@"GB"];
    // Japan
    if (lat >= 30 && lat <= 46 && lon >= 129 && lon <= 146) return [self localeForCountryCode:@"JP"];
    // Korea
    if (lat >= 33 && lat <= 39 && lon >= 124 && lon <= 132) return [self localeForCountryCode:@"KR"];
    // China
    if (lat >= 18 && lat <= 54 && lon >= 73 && lon <= 135) return [self localeForCountryCode:@"CN"];
    // India
    if (lat >= 6 && lat <= 36 && lon >= 68 && lon <= 98) return [self localeForCountryCode:@"IN"];
    // Australia
    if (lat >= -44 && lat <= -10 && lon >= 113 && lon <= 154) return [self localeForCountryCode:@"AU"];
    // Brazil
    if (lat >= -34 && lat <= 5 && lon >= -74 && lon <= -34) return [self localeForCountryCode:@"BR"];
    // Germany
    if (lat >= 47 && lat <= 55 && lon >= 6 && lon <= 15) return [self localeForCountryCode:@"DE"];
    // France
    if (lat >= 41 && lat <= 51 && lon >= -5 && lon <= 10) return [self localeForCountryCode:@"FR"];
    // Russia
    if (lat >= 41 && lat <= 82 && lon >= 19 && lon <= 180) return [self localeForCountryCode:@"RU"];
    // Thailand
    if (lat >= 5 && lat <= 21 && lon >= 97 && lon <= 106) return [self localeForCountryCode:@"TH"];
    // Indonesia
    if (lat >= -11 && lat <= 6 && lon >= 95 && lon <= 141) return [self localeForCountryCode:@"ID"];
    // Singapore
    if (lat >= 1.0 && lat <= 1.5 && lon >= 103.5 && lon <= 104.5) return [self localeForCountryCode:@"SG"];
    // Malaysia
    if (lat >= 0.5 && lat <= 8 && lon >= 99 && lon <= 120) return [self localeForCountryCode:@"MY"];
    // Philippines
    if (lat >= 4 && lat <= 21 && lon >= 116 && lon <= 127) return [self localeForCountryCode:@"PH"];
    // UAE
    if (lat >= 22 && lat <= 27 && lon >= 51 && lon <= 57) return [self localeForCountryCode:@"AE"];
    // Saudi Arabia
    if (lat >= 15 && lat <= 32 && lon >= 34 && lon <= 56) return [self localeForCountryCode:@"SA"];
    // South Africa
    if (lat >= -35 && lat <= -22 && lon >= 16 && lon <= 33) return [self localeForCountryCode:@"ZA"];
    // Canada
    if (lat >= 42 && lat <= 84 && lon >= -141 && lon <= -52) return [self localeForCountryCode:@"CA"];
    // Mexico
    if (lat >= 14 && lat <= 33 && lon >= -118 && lon <= -86) return [self localeForCountryCode:@"MX"];
    // Spain
    if (lat >= 35 && lat <= 44 && lon >= -10 && lon <= 4) return [self localeForCountryCode:@"ES"];
    // Italy
    if (lat >= 35 && lat <= 47 && lon >= 6 && lon <= 19) return [self localeForCountryCode:@"IT"];
    // Turkey
    if (lat >= 35 && lat <= 43 && lon >= 25 && lon <= 45) return [self localeForCountryCode:@"TR"];
    // Egypt
    if (lat >= 22 && lat <= 32 && lon >= 24 && lon <= 37) return [self localeForCountryCode:@"EG"];
    // Nigeria
    if (lat >= 4 && lat <= 14 && lon >= 2 && lon <= 15) return [self localeForCountryCode:@"NG"];
    // Argentina
    if (lat >= -56 && lat <= -21 && lon >= -74 && lon <= -53) return [self localeForCountryCode:@"AR"];
    // Pakistan
    if (lat >= 23 && lat <= 37 && lon >= 60 && lon <= 78) return [self localeForCountryCode:@"PK"];
    // Bangladesh
    if (lat >= 20 && lat <= 27 && lon >= 88 && lon <= 93) return [self localeForCountryCode:@"BD"];
    // Cambodia
    if (lat >= 10 && lat <= 15 && lon >= 102 && lon <= 108) return [self localeForCountryCode:@"KH"];
    // Laos
    if (lat >= 13 && lat <= 23 && lon >= 100 && lon <= 108) return [self localeForCountryCode:@"LA"];
    return nil;
}

+ (NSArray<NSDictionary *> *)searchLocales:(NSString *)query {
    if (!query.length) return [self allLocales];
    NSString *q = query.lowercaseString;
    NSMutableArray *results = [NSMutableArray array];
    for (NSDictionary *l in [self allLocales]) {
        NSString *country = [l[@"country"] lowercaseString];
        NSString *code = [l[@"code"] lowercaseString];
        NSString *locale = [l[@"locale"] lowercaseString];
        if ([country containsString:q] || [code containsString:q] || [locale containsString:q]) {
            [results addObject:l];
        }
    }
    return results;
}

@end
