export ARCHS = arm64 arm64e
export TARGET = iphone:clang:latest:14.0
export THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = MaSplitPrefs

MaSplitPrefs_FILES = MSPrefsRootListController.m
MaSplitPrefs_INSTALL_PATH = /Library/PreferenceBundles
MaSplitPrefs_FRAMEWORKS = UIKit
MaSplitPrefs_CFLAGS = -fobjc-arc -Wno-error -Iinclude
MaSplitPrefs_LDFLAGS = -undefined dynamic_lookup
MaSplitPrefs_RESOURCE_DIRS = Resources

include $(THEOS_MAKE_PATH)/bundle.mk
