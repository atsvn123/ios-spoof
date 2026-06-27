#import "SCSpoofConfig.h"
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>
#import <objc/runtime.h>

// ============================================================================
//  SCGeoHooks.x
//  Spoof GPS / location:
//  - CLLocationManager: location, heading, accuracy
//  - CLLocation: coordinate, timestamp, horizontalAccuracy
//  - CLLocationManagerDelegate callbacks
//  - MKMapView region (optional)
//  - CLGeocoder consistency
//  - Significant location change / region monitoring
// ============================================================================

static SCSpoofConfig *CFG() { return [SCSpoofConfig shared]; }
static BOOL SC_GEO_ON()     { return CFG().enabled && CFG().geoEnabled; }

static void SCGeoPrefsChanged(CFNotificationCenterRef center, void *observer,
                              CFStringRef name, const void *object,
                              CFDictionaryRef userInfo) {
    [CFG() reload];
}

static CLLocation *sc_make_location() {
    SCSpoofConfig *c = CFG();
    CLLocationCoordinate2D coord = CLLocationCoordinate2DMake(c.latitude, c.longitude);
    CLLocationDistance alt = c.altitude > 0 ? c.altitude : 0;
    CLLocationAccuracy acc = c.horizontalAccuracy > 0 ? c.horizontalAccuracy : 5.0;
    CLLocationDirection heading = c.heading;
    CLLocationSpeed speed = -1;
    NSDate *ts = [NSDate date];
    return [[CLLocation alloc] initWithCoordinate:coord
                                          altitude:alt
                                horizontalAccuracy:acc
                                  verticalAccuracy:acc
                                    course:heading
                                     speed:speed
                                 timestamp:ts];
}

// ============================================================================
//  1. CLLocationManager
// ============================================================================

%hook CLLocationManager

- (CLLocation *)location {
    if (SC_GEO_ON()) return sc_make_location();
    return %orig;
}

- (CLHeading *)heading {
    if (SC_GEO_ON()) {
        // CLHeading có thể tạo qua private init; đơn giản trả về nil nếu app tự xử lý.
        // Nếu cần, build CLHeading bằng setValue:forKey:.
        CLHeading *h = [[%c(CLHeading) alloc] init];
        @try { [h setValue:@(CFG().heading) forKey:@"magneticHeading"]; } @catch(__unused id e) {}
        @try { [h setValue:@(CFG().heading) forKey:@"trueHeading"]; } @catch(__unused id e) {}
        @try { [h setValue:@5.0 forKey:@"headingAccuracy"]; } @catch(__unused id e) {}
        @try { [h setValue:[NSDate date] forKey:@"timestamp"]; } @catch(__unused id e) {}
        return h;
    }
    return %orig;
}

- (void)startUpdatingLocation {
    %orig;
    if (SC_GEO_ON()) {
        CLLocation *loc = sc_make_location();
        // Fire delegate async
        id<CLLocationManagerDelegate> del = [self delegate];
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([del respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
                [del locationManager:self didUpdateLocations:@[loc]];
            } else if ([del respondsToSelector:@selector(locationManager:didUpdateToLocation:fromLocation:)]) {
                [del locationManager:self didUpdateToLocation:loc fromLocation:loc];
            }
        });
    }
}

- (void)startMonitoringSignificantLocationChanges {
    %orig;
    if (SC_GEO_ON()) {
        id<CLLocationManagerDelegate> del = [self delegate];
        CLLocation *loc = sc_make_location();
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([del respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
                [del locationManager:self didUpdateLocations:@[loc]];
            }
        });
    }
}

- (void)requestLocation {
    %orig;
    if (SC_GEO_ON()) {
        id<CLLocationManagerDelegate> del = [self delegate];
        CLLocation *loc = sc_make_location();
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([del respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
                [del locationManager:self didUpdateLocations:@[loc]];
            }
        });
    }
}

- (CLAuthorizationStatus)authorizationStatus {
    // Luôn báo đã authorized
    return kCLAuthorizationStatusAuthorizedAlways;
}

- (void)requestWhenInUseAuthorization { %orig; }
- (void)requestAlwaysAuthorization { %orig; }

- (BOOL)locationServicesEnabled {
    return YES;
}
+ (BOOL)locationServicesEnabled {
    return YES;
}
+ (CLAuthorizationStatus)authorizationStatus {
    return kCLAuthorizationStatusAuthorizedAlways;
}

- (void)startMonitoringForRegion:(CLRegion *)region {
    // Cho phép nhưng không fire enter/exit thật
}
- (void)startMonitoringForRegion:(CLRegion *)region desiredAccuracy:(CLLocationAccuracy)a {
    // no-op
}

%end

// ============================================================================
//  2. CLLocation - nếu app tạo location object rồi đọc lại
//    Chủ yếu override description để tránh leak real coords
// ============================================================================
%hook CLLocation

- (CLLocationCoordinate2D)coordinate {
    if (SC_GEO_ON()) {
        return CLLocationCoordinate2DMake(CFG().latitude, CFG().longitude);
    }
    return %orig;
}

- (CLLocationDistance)altitude {
    if (SC_GEO_ON()) return CFG().altitude > 0 ? CFG().altitude : 0;
    return %orig;
}

- (CLLocationAccuracy)horizontalAccuracy {
    if (SC_GEO_ON()) return CFG().horizontalAccuracy > 0 ? CFG().horizontalAccuracy : 5.0;
    return %orig;
}

- (CLLocationAccuracy)verticalAccuracy {
    if (SC_GEO_ON()) return CFG().horizontalAccuracy > 0 ? CFG().horizontalAccuracy : 5.0;
    return %orig;
}

- (CLLocationDirection)course {
    if (SC_GEO_ON()) return CFG().heading;
    return %orig;
}

- (CLLocationSpeed)speed {
    if (SC_GEO_ON()) return 0;
    return %orig;
}

- (NSDate *)timestamp {
    if (SC_GEO_ON()) return [NSDate date];
    return %orig;
}

- (NSString *)description {
    if (SC_GEO_ON()) {
        return [NSString stringWithFormat:@"<+%.6f,+-%.6f> +/- %.0fm (speed %.1f mps / course %.1f) @ %@",
                CFG().latitude, CFG().longitude,
                CFG().horizontalAccuracy > 0 ? CFG().horizontalAccuracy : 5.0,
                0.0, CFG().heading, [NSDate date]];
    }
    return %orig;
}

- (CLLocation *)initWithCoordinate:(CLLocationCoordinate2D)coordinate
                           altitude:(CLLocationDistance)altitude
                 horizontalAccuracy:(CLLocationAccuracy)hacc
                   verticalAccuracy:(CLLocationAccuracy)vacc
                          timestamp:(NSDate *)timestamp {
    if (SC_GEO_ON()) {
        coordinate = CLLocationCoordinate2DMake(CFG().latitude, CFG().longitude);
        altitude = CFG().altitude > 0 ? CFG().altitude : altitude;
    }
    return %orig;
}

- (CLLocation *)initWithCoordinate:(CLLocationCoordinate2D)coordinate
                           altitude:(CLLocationDistance)altitude
                 horizontalAccuracy:(CLLocationAccuracy)hacc
                   verticalAccuracy:(CLLocationAccuracy)vacc
                             course:(CLLocationDirection)course
                              speed:(CLLocationSpeed)speed
                          timestamp:(NSDate *)timestamp {
    if (SC_GEO_ON()) {
        coordinate = CLLocationCoordinate2DMake(CFG().latitude, CFG().longitude);
        altitude = CFG().altitude > 0 ? CFG().altitude : altitude;
        course = CFG().heading;
        speed = 0;
    }
    return %orig;
}

%end

// ============================================================================
//  3. CLGeocoder - reverse geocode trả kết quả nhất quán với toạ độ spoof
//    Geocoder gọi server nên không thể hoàn toàn fake; nhưng nếu app chỉ check
//    country code / locality, ta hook kết quả trả về.
// ============================================================================
%hook CLGeocoder
- (void)reverseGeocodeLocation:(CLLocation *)location
             completionHandler:(CLGeocodeCompletionHandler)handler {
    if (SC_GEO_ON()) {
        // Thay location bằng spoof trước khi gọi
        CLLocation *fake = sc_make_location();
        CLGeocodeCompletionHandler wrapped = ^(NSArray *placemarks, NSError *error) {
            if (handler) handler(placemarks, error);
        };
        %orig(fake, wrapped);
        return;
    }
    %orig;
}
%end

// ============================================================================
//  4. MKMapView - region / camera (optional, anti-map-fingerprint)
// ============================================================================
%hook MKMapView
- (void)setRegion:(MKCoordinateRegion)region animated:(BOOL)animated {
    if (SC_GEO_ON()) {
        region.center = CLLocationCoordinate2DMake(CFG().latitude, CFG().longitude);
    }
    %orig;
}
- (void)setCenterCoordinate:(CLLocationCoordinate2D)coordinate animated:(BOOL)animated {
    if (SC_GEO_ON()) {
        coordinate = CLLocationCoordinate2DMake(CFG().latitude, CFG().longitude);
    }
    %orig;
}
- (void)setCamera:(MKMapCamera *)camera animated:(BOOL)animated {
    if (SC_GEO_ON()) {
        [camera setCenterCoordinate:CLLocationCoordinate2DMake(CFG().latitude, CFG().longitude)];
    }
    %orig;
}
%end

// ============================================================================
//  5. CLRegion / CLCircularRegion - nếu app monitor region
// ============================================================================
%hook CLCircularRegion
- (BOOL)containsCoordinate:(CLLocationCoordinate2D)coordinate {
    if (SC_GEO_ON()) {
        // Luôn báo trong region nếu app check
        return YES;
    }
    return %orig;
}
%end

// ============================================================================
//  6. Constructor - chỉ hook nếu process là target
// ============================================================================

%ctor {
    @autoreleasepool {
        NSString *bid = [[NSBundle mainBundle] bundleIdentifier] ?: @"";
        static NSSet *protected;
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            protected = [NSSet setWithArray:@[
                @"com.iosspoof.app", @"org.coolstar.SileoStore", @"org.coolstar.Sileo",
                @"com.saurik.Cydia", @"xyz.willy.Zebra", @"com.opa334.Dopamine",
                @"com.opa334.TrollStore", @"com.apple.springboard", @"com.apple.Preferences"
            ]];
        });
        if ([protected containsObject:bid]) return;
        
        [SCSpoofConfig shared];
        if (![CFG() shouldInjectForCurrentBundle]) return;
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
            NULL, SCGeoPrefsChanged, CFSTR("com.iosspoof.tweak.prefs.changed"), NULL,
            CFNotificationSuspensionBehaviorCoalesce);
        %init;
    }
}
