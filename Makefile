TARGET := iphone:clang:latest:11.0
INSTALL_TARGET_PROCESSES = YouTube
ARCHS = arm64
PACKAGE_VERSION = 1.1.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = YTABConfig

$(TWEAK_NAME)_FILES = Tweak.x
$(TWEAK_NAME)_CFLAGS = -fobjc-arc -DTWEAK_VERSION=$(PACKAGE_VERSION)

include $(THEOS_MAKE_PATH)/tweak.mk
