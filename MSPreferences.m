#import "MSPreferences.h"
#import <notify.h>

NSString *const MSPrefDomain = @"com.malaoshi.masplit";

static NSString *const kPrefPath  = @"/var/mobile/Library/Preferences/com.malaoshi.masplit.plist";
static NSString *const kNotifyName = "com.malaoshi.masplit/prefsChanged";

@implementation MSPreferences {
	NSDictionary *_cache;
}

+ (instancetype)shared {
	static dispatch_once_t once;
	static MSPreferences *inst;
	dispatch_once(&once, ^{ inst = [[MSPreferences alloc] init]; });
	return inst;
}

- (instancetype)init {
	if ((self = [super init])) {
		[self reload];
		int token = 0;
		notify_register_dispatch(kNotifyName, &token, dispatch_get_main_queue(), ^(int t) {
			[self reload];
		});
	}
	return self;
}

- (void)reload {
	_cache = [NSDictionary dictionaryWithContentsOfFile:kPrefPath] ?: @{};
}

#pragma mark - 原始取值

- (id)_raw:(NSString *)key {
	return _cache[key];
}

- (BOOL)_bool:(NSString *)key def:(BOOL)def {
	id v = [self _raw:key];
	return v ? [v boolValue] : def;
}

- (double)_double:(NSString *)key def:(double)def {
	id v = [self _raw:key];
	return v ? [v doubleValue] : def;
}

#pragma mark - 对外属性

- (BOOL)enabled { return [self _bool:@"enabled" def:YES]; }

- (CGFloat)windowScale {
	return MAX(0.30, MIN(1.0, [self _double:@"windowScale" def:0.65]));
}

- (CGFloat)cornerRadius {
	return MAX(0.0, MIN(46.0, [self _double:@"cornerRadius" def:30.0]));
}

- (CGFloat)topTriggerHeight {
	return MAX(8.0, MIN(160.0, [self _double:@"topTriggerHeight" def:20.0]));
}

- (CGFloat)bottomTriggerHeight {
	return MAX(12.0, MIN(200.0, [self _double:@"bottomTriggerHeight" def:40.0]));
}

- (CGFloat)swipeVelocity {
	// 设置里 20~80 是「手感档位」，换算成 pt/s
	return MAX(80.0, MIN(2400.0, [self _double:@"swipeVelocity" def:40.0] * 20.0));
}

- (NSInteger)maxWindows {
	return (NSInteger)MAX(2.0, MIN(12.0, [self _double:@"maxWindows" def:8.0]));
}

- (CGFloat)animationDuration {
	return MAX(0.0, MIN(0.6, [self _double:@"animationDuration" def:0.2]));
}

- (BOOL)dismissOnBlankTap { return [self _bool:@"dismissOnBlankTap" def:YES]; }
- (BOOL)externalKeyboardMode { return [self _bool:@"externalKeyboardMode" def:NO]; }
- (BOOL)experimentalMultitasking { return [self _bool:@"experimentalMultitasking" def:NO]; }

- (NSString *)watermark {
	NSString *s = [self _raw:@"watermark"];
	return s.length ? s : @"马老师专属";
}

@end
