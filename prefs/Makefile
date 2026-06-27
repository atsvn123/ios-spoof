include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = iOSSpoofPrefs
iOSSpoofPrefs_FILES = SCRootListController.m SCAppListController.m ../src/SCDevicePresets.m
iOSSpoofPrefs_CFLAGS = -fobjc-arc
iOSSpoofPrefs_FRAMEWORKS = UIKit Foundation
iOSSpoofPrefs_LDFLAGS = -undefined dynamic_lookup
iOSSpoofPrefs_INSTALL_PATH = /Library/PreferenceBundles
iOSSpoofPrefs_RESOURCE_FILES = Root.plist iosspoof.png

include $(THEOS_MAKE_PATH)/bundle.mk
