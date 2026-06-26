ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = iOSSpoof

iOSSpoof_FILES = \
	src/SCSpoofConfig.m \
	src/SCDevicePresets.m \
	src/SCProxyManager.m \
	src/Tweak.x \
	src/SCNetworkHooks.x \
	src/SCGeoHooks.x

iOSSpoof_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable -Wno-unused-function
iOSSpoof_FRAMEWORKS = Foundation CoreFoundation UIKit CoreLocation CoreTelephony SystemConfiguration MapKit
iOSSpoof_PRIVATE_FRAMEWORKS = MobileCoreServices AppSupport SpringBoardServices IOKit
iOSSpoof_LDFLAGS = -framework CFNetwork

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS = prefs daemon
include $(THEOS_MAKE_PATH)/aggregate.mk
