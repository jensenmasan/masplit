#import "MSSnapshotProvider.h"
#import "MSAppListProvider.h"
#import "MSPreferences.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>

static id MSCall0(id target, NSString *selName) {
	if (!target) return nil;
	SEL sel = NSSelectorFromString(selName);
	if (![target respondsToSelector:sel]) return nil;
	return ((id (*)(id, SEL))objc_msgSend)(target, sel);
}

static id MSCall1(id target, NSString *selName, id arg) {
	if (!target) return nil;
	SEL sel = NSSelectorFromString(selName);
	if (![target respondsToSelector:sel]) return nil;
	return ((id (*)(id, SEL, id))objc_msgSend)(target, sel, arg);
}

static UIColor *MSColor(NSString *hex) {
	unsigned int v = 0;
	NSScanner *scanner = [NSScanner scannerWithString:[hex stringByReplacingOccurrencesOfString:@"#" withString:@""]];
	[scanner scanHexInt:&v];
	return [UIColor colorWithRed:((v >> 16) & 0xFF) / 255.0
	                       green:((v >> 8) & 0xFF) / 255.0
	                        blue:(v & 0xFF) / 255.0
	                       alpha:1.0];
}

@implementation MSSnapshotProvider

+ (NSArray<NSArray<NSString *> *> *)_gradients {
	static NSArray *g;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		g = @[
			@[@"#22314F", @"#0A0F1A"],
			@[@"#3A2350", @"#120B1E"],
			@[@"#123A38", @"#07120F"],
			@[@"#4A2A22", @"#170C09"],
			@[@"#1E2B4A", @"#080D16"],
			@[@"#2F1B3E", @"#100714"],
		];
	});
	return g;
}

+ (UIImage *)_switcherSnapshotFor:(NSString *)bundleID {
	@synchronized (self) {
		Class cacheCls = objc_getClass("SBAppSwitcherSnapshotImageCache");
		if (!cacheCls) return nil;
		id cache = MSCall0((id)cacheCls, @"sharedInstance");
		if (!cache) return nil;

		Class appCtrlCls = objc_getClass("SBApplicationController");
		id ctrl = MSCall0((id)appCtrlCls, @"sharedInstance");
		id app = MSCall1(ctrl, @"applicationWithBundleIdentifier:", bundleID);
		if (!app) return nil;

		for (NSString *selName in @[@"snapshotForApplication:", @"snapshotForDisplayItem:"]) {
			SEL sel = NSSelectorFromString(selName);
			if (![cache respondsToSelector:sel]) continue;
			@try {
				id result = ((id (*)(id, SEL, id))objc_msgSend)(cache, sel, app);
				if ([result isKindOfClass:[UIImage class]]) return result;
				if (result) {
					id img = MSCall0(result, @"image");
					if ([img isKindOfClass:[UIImage class]]) return img;
					img = MSCall0(result, @"snapshot");
					if ([img isKindOfClass:[UIImage class]]) return img;
				}
			} @catch (__unused NSException *e) {}
		}
	}
	return nil;
}

+ (UIImage *)_screenGrab {
	static UIImage *(*fn)(void) = NULL;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		fn = (UIImage *(*)(void))dlsym(RTLD_DEFAULT, "_UICreateScreenUIImage");
	});
	if (!fn) return nil;
	@try { return fn(); } @catch (__unused NSException *e) { return nil; }
}

+ (UIImage *)_resize:(UIImage *)image to:(CGSize)size {
	if (!image || size.width <= 0 || size.height <= 0) return image;
	UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat defaultFormat];
	fmt.opaque = YES;
	UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size format:fmt];
	return [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
		CGRect target = CGRectMake(0, 0, size.width, size.height);
		CGFloat iw = image.size.width, ih = image.size.height;
		if (iw <= 0 || ih <= 0) return;
		CGFloat scale = MAX(target.size.width / iw, target.size.height / ih);
		CGRect draw = CGRectMake((target.size.width - iw * scale) / 2.0,
		                         (target.size.height - ih * scale) / 2.0,
		                         iw * scale, ih * scale);
		[image drawInRect:draw];
	}];
}

+ (UIImage *)placeholderForBundleID:(NSString *)bundleID size:(CGSize)size {
	NSUInteger hash = bundleID.hash;
	NSArray *pair = [self _gradients][hash % [self _gradients].count];

	UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat defaultFormat];
	fmt.opaque = YES;
	UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size format:fmt];

	UIImage *icon = [MSAppListProvider iconForBundleID:bundleID size:132];
	NSString *name = [MSAppListProvider appForBundleID:bundleID].name ?: bundleID;

	return [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
		CGContextRef c = ctx.CGContext;
		CGRect rect = CGRectMake(0, 0, size.width, size.height);

		// 渐变底
		CGGradientRef grad = CGGradientCreateWithColors(NULL,
			(__bridge CFArrayRef)@[(__bridge id)MSColor(pair[0]), (__bridge id)MSColor(pair[1])],
			NULL);
		CGContextDrawLinearGradient(c, grad, CGPointMake(0, 0), CGPointMake(size.width * 0.4, size.height), 0);
		CGGradientRelease(grad);

		// 星点
		CGContextSetFillColorWithColor(c, [UIColor colorWithWhite:1.0 alpha:0.5].CGColor);
		for (int i = 0; i < 26; i++) {
			CGFloat r = 0.6 + (CGFloat)((hash + i * 37) % 14) / 10.0;
			CGFloat x = (CGFloat)((hash * 13 + i * 71) % (int)size.width);
			CGFloat y = (CGFloat)((hash * 7 + i * 113) % (int)size.height);
			CGContextFillEllipseInRect(c, CGRectMake(x, y, r, r));
		}

		// 图标
		if (icon) {
			CGFloat s = MIN(size.width * 0.36, 96);
			CGRect iconRect = CGRectMake((size.width - s) / 2.0, size.height * 0.36 - s / 2.0, s, s);
			CGContextSaveGState(c);
			CGContextSetShadowWithColor(c, CGSizeMake(0, 8), 18, [UIColor colorWithWhite:0 alpha:0.45].CGColor);
			[icon drawInRect:iconRect];
			CGContextRestoreGState(c);
		}

		// 名称
		NSMutableParagraphStyle *ps = [NSMutableParagraphStyle new];
		ps.alignment = NSTextAlignmentCenter;
		NSDictionary *attrs = @{
			NSFontAttributeName: [UIFont systemFontOfSize:MAX(11, size.width * 0.075) weight:UIFontWeightSemibold],
			NSForegroundColorAttributeName: [UIColor colorWithWhite:1.0 alpha:0.92],
			NSParagraphStyleAttributeName: ps,
		};
		CGRect nameRect = CGRectMake(10, size.height * 0.60, size.width - 20, size.height * 0.18);
		[name drawInRect:nameRect withAttributes:attrs];

		// 品牌水印
		NSDictionary *wmAttrs = @{
			NSFontAttributeName: [UIFont systemFontOfSize:MAX(8, size.width * 0.05) weight:UIFontWeightMedium],
			NSForegroundColorAttributeName: [UIColor colorWithWhite:1.0 alpha:0.30],
			NSParagraphStyleAttributeName: ps,
		};
		[[MSPreferences shared].watermark drawInRect:CGRectMake(0, size.height - 26, size.width, 18) withAttributes:wmAttrs];
	}];
}

+ (UIImage *)snapshotForBundleID:(NSString *)bundleID size:(CGSize)size {
	if (!bundleID.length) return nil;

	UIImage *image = nil;
	@try { image = [self _switcherSnapshotFor:bundleID]; } @catch (__unused NSException *e) {}

	if (!image) {
		NSString *front = [MSAppListProvider frontmostBundleID];
		if (front && [front isEqualToString:bundleID]) {
			image = [self _screenGrab];
		}
	}

	if (!image) image = [self placeholderForBundleID:bundleID size:size];
	return [self _resize:image to:size];
}

+ (void)invalidate:(NSString *)bundleID {
	(void)bundleID;
}

@end
