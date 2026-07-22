ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TOOL_NAME = sckrwprobe

sckrwprobe_FILES = sckrwprobe.m
sckrwprobe_CFLAGS = -fobjc-arc -Wall -Wextra -Wno-unused-parameter
sckrwprobe_FRAMEWORKS = Foundation
sckrwprobe_INSTALL_PATH = /usr/bin
sckrwprobe_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/tool.mk
