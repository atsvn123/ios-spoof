ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = iOSSpoof

iOSSpoof_FILES = \
	ObjC/main.m \
	ObjC/SCAppDelegate.m \
	ObjC/SCTabBarController.m \
	ObjC/Models/SCAppConfig.m \
	ObjC/Models/SCDevicePresetStore.m \
	ObjC/Models/SCLocaleStore.m \
	ObjC/Controllers/SCBaseTableViewController.m \
	ObjC/Controllers/SCStatusViewController.m \
	ObjC/Controllers/SCDeviceViewController.m \
	ObjC/Controllers/SCAppsViewController.m \
	ObjC/Controllers/SCSpoofViewController.m

iOSSpoof_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-arc-performSelector-leaks
iOSSpoof_FRAMEWORKS = UIKit Foundation CoreLocation CoreTelephony SystemConfiguration
iOSSpoof_LDFLAGS = -Wl,-w

iOSSpoof_INSTALL_PATH = /Applications
iOSSpoof_CODESIGN_FLAGS = -S
iOSSpoof_INFO_PLIST = Info.plist
iOSSpoof_RESOURCE_FILES = \
	Info.plist \
	PkgInfo \
	Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png \
	Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png \
	Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png \
	Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png \
	Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png

include $(THEOS_MAKE_PATH)/application.mk
