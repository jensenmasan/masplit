export ARCHS = arm64 arm64e
export TARGET = iphone:clang:latest:14.0
export THEOS_PACKAGE_SCHEME = rootless
export DEBUG = 0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MaSplit

MaSplit_FILES = Tweak.xm \
	MSPreferences.m \
	MSFloatingWindow.m \
	MSWindowManager.m \
	MSSnapshotProvider.m \
	MSAppListProvider.m \
	MSRingSelector.m \
	MSMultiTasking.m

MaSplit_CFLAGS = -fobjc-arc -Wno-error -Wno-deprecated-declarations -Wno-unused-function -Wno-unused-variable
MaSplit_FRAMEWORKS = UIKit QuartzCore CoreGraphics
MaSplit_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += prefs
include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "killall -9 SpringBoard"
