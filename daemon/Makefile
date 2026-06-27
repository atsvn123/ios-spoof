include $(THEOS)/makefiles/common.mk

TOOL_NAME = scproxyd

scproxyd_FILES = scproxyd.m
scproxyd_CFLAGS = -fobjc-arc -Wno-unused-variable -Wno-unused-function
scproxyd_FRAMEWORKS = Foundation CFNetwork
scproxyd_LDFLAGS = -lresolv -Wl,-w

include $(THEOS_MAKE_PATH)/tool.mk
