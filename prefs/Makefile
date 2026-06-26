include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = iOSSpoofPrefs
iOSSpoofPrefs_FILES = SCRootListController.m ../src/SCDevicePresets.m
iOSSpoofPrefs_CFLAGS = -fobjc-arc
iOSSpoofPrefs_FRAMEWORKS = UIKit Foundation
iOSSpoofPrefs_LDFLAGS = -undefined dynamic_lookup

include $(THEOS_MAKE_PATH)/bundle.mk
