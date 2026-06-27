ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = iOSSpoofApp

iOSSpoofApp_FILES = \
	ObjC/main.m \
	ObjC/SCAppDelegate.m \
	ObjC/SCTabBarController.m \
	ObjC/Models/SCAppConfig.m \
	ObjC/Models/SCDevicePresetStore.m \
	ObjC/Controllers/SCBaseTableViewController.m \
	ObjC/Controllers/SCStatusViewController.m \
	ObjC/Controllers/SCDeviceViewController.m \
	ObjC/Controllers/SCAppsViewController.m \
	ObjC/Controllers/SCNetworkViewController.m \
	ObjC/Controllers/SCGPSViewController.m \
	ObjC/Controllers/SCCellularViewController.m \
	ObjC/Controllers/SCHardwareViewController.m

iOSSpoofApp_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-arc-performSelector-leaks
iOSSpoofApp_FRAMEWORKS = UIKit Foundation CoreLocation CoreTelephony SystemConfiguration
iOSSpoofApp_LDFLAGS = -Wl,-w

iOSSpoofApp_INSTALL_PATH = /Applications
iOSSpoofApp_CODESIGN_FLAGS = -S
iOSSpoofApp_INFO_PLIST = iOSSpoofApp-Info.plist
iOSSpoofApp_BUNDLE_NAME = iOSSpoof
iOSSpoofApp_RESOURCE_FILES = \
	Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png \
	Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png \
	Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png \
	Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png \
	Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png

include $(THEOS_MAKE_PATH)/application.mk
