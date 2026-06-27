ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:16.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = iOSSpoofApp

iOSSpoofApp_FILES = \
	iOSSpoofApp.swift \
	Views/ContentView.swift \
	Views/DeviceTabView.swift \
	Views/AppsTabView.swift \
	Views/NetworkTabView.swift \
	Views/GPSTabView.swift \
	Views/CellularTabView.swift \
	Views/DisplayTabView.swift \
	Views/HardwareTabView.swift \
	Models/SpoofConfig.swift \
	Models/DevicePreset.swift \
	Models/PresetManager.swift \
	Models/DaemonClient.swift \
	Models/AppsViewModel.swift

iOSSpoofApp_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
iOSSpoofApp_FRAMEWORKS = UIKit SwiftUI Foundation CoreLocation CoreTelephony SystemConfiguration MapKit
iOSSpoofApp_PRIVATE_FRAMEWORKS = IOKit
iOSSpoofApp_LDFLAGS = -Wl,-undefined,dynamic_lookup

iOSSpoofApp_INSTALL_PATH = /Applications
iOSSpoofApp_CODESIGN_FLAGS = -S-
iOSSpoofApp_BUNDLE_NAME = iOSSpoof
iOSSpoofApp_INFO_PLIST = iOSSpoofApp-Info.plist

include $(THEOS_MAKE_PATH)/application.mk
