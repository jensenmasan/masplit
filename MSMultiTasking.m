#import "MSMultiTasking.h"
#import "MSPreferences.h"
#import <objc/runtime.h>

@interface MSMultiTasking () {
	BOOL _activated;
}
@end

@implementation MSMultiTasking

+ (instancetype)shared {
	static dispatch_once_t once;
	static MSMultiTasking *inst;
	dispatch_once(&once, ^{ inst = [[MSMultiTasking alloc] init]; });
	return inst;
}

- (BOOL)isActive { return _activated; }

- (BOOL)_forceBool:(NSString *)className selector:(NSString *)selName value:(BOOL)value {
	Class cls = objc_getClass(className.UTF8String);
	if (!cls) return NO;
	SEL sel = NSSelectorFromString(selName);
	Method m = class_getInstanceMethod(cls, sel);
	if (!m) {
		// 可能是类方法
		Method cm = class_getClassMethod(cls, sel);
		if (!cm) return NO;
		IMP imp = imp_implementationWithBlock(^BOOL(id _self) { return value; });
		method_setImplementation(cm, imp);
		NSLog(@"[MaSplit] 已强制 %@ +%@ = %d", className, selName, value);
		return YES;
	}
	IMP imp = imp_implementationWithBlock(^BOOL(id _self) { return value; });
	method_setImplementation(m, imp);
	NSLog(@"[MaSplit] 已强制 %@ -%@ = %d", className, selName, value);
	return YES;
}

- (void)activateIfEnabled {
	if (_activated) return;
	if (![MSPreferences shared].experimentalMultitasking) return;
	_activated = YES;

	// Medusa（iPad 多窗口）总开关
	[self _forceBool:@"SBMedusaSettings" selector:@"medusaEnabled" value:YES];
	[self _forceBool:@"SBMedusaSettings" selector:@"isMedusaSupported" value:YES];
	[self _forceBool:@"SBMedusaSettings" selector:@"medusaSupported" value:YES];
	[self _forceBool:@"SBMedusaSettings" selector:@"splitViewEnabled" value:YES];
	[self _forceBool:@"SBMedusaSettings" selector:@"slideOverEnabled" value:YES];
	[self _forceBool:@"SBMedusaSettings" selector:@"allowMultipleWindows" value:YES];

	// 策略聚合器：放开"这台设备不支持分屏"的限制
	[self _forceBool:@"SBMainDisplayPolicyAggregator" selector:@"supportsMedusa" value:YES];
	[self _forceBool:@"SBMainDisplayPolicyAggregator" selector:@"supportsSplitView" value:YES];
	[self _forceBool:@"SBMainDisplayPolicyAggregator" selector:@"supportsSlideOver" value:YES];
	[self _forceBool:@"SBMainDisplayPolicyAggregator" selector:@"supportsMultipleWindows" value:YES];
	[self _forceBool:@"SBMainDisplayPolicyAggregator" selector:@"isMedusaSupported" value:YES];

	// App 侧能力
	[self _forceBool:@"SBApplication" selector:@"supportsSplitView" value:YES];
	[self _forceBool:@"SBApplication" selector:@"supportsMultipleScenes" value:YES];
	[self _forceBool:@"SBApplication" selector:@"isMedusaCapable" value:YES];

	NSLog(@"[MaSplit] 实验性多窗口已尝试激活（是否生效取决于 App 自身是否支持多场景）");
}

@end
