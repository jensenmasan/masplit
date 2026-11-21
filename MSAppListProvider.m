#import "MSAppListProvider.h"
#import <objc/runtime.h>
#import <objc/message.h>

@implementation MSAppInfo
- (NSString *)description {
	return [NSString stringWithFormat:@"<%@ %@ %@>", self.name, self.bundleID, self.version];
}
@end

static NSMutableDictionary<NSString *, UIImage *> *MSIconCache(void) {
	static NSMutableDictionary *cache;
	static dispatch_once_t once;
	dispatch_once(&once, ^{ cache = [NSMutableDictionary dictionary]; });
	return cache;
}

static id MSCall(id target, NSString *selName) {
	if (!target) return nil;
	SEL sel = NSSelectorFromString(selName);
	if (![target respondsToSelector:sel]) return nil;
	return ((id (*)(id, SEL))objc_msgSend)(target, sel);
}

static id MSCallInt(id target, NSString *selName, NSInteger arg) {
	if (!target) return nil;
	SEL sel = NSSelectorFromString(selName);
	if (![target respondsToSelector:sel]) return nil;
	return ((id (*)(id, SEL, NSInteger))objc_msgSend)(target, sel, arg);
}

@implementation MSAppListProvider

+ (id)_workspace {
	Class cls = objc_getClass("LSApplicationWorkspace");
	if (!cls) return nil;
	return MSCall((id)cls, @"defaultWorkspace");
}

+ (NSArray *)_proxies {
	id ws = [self _workspace];
	NSArray *apps = MSCall(ws, @"allInstalledApplications");
	return [apps isKindOfClass:[NSArray class]] ? apps : @[];
}

+ (MSAppInfo *)_infoFromProxy:(id)proxy {
	if (!proxy) return nil;

	NSString *bid = MSCall(proxy, @"bundleIdentifier");
	if (!bid.length) return nil;

	MSAppInfo *info = [MSAppInfo new];
	info.bundleID = bid;

	NSString *name = MSCall(proxy, @"localizedName");
	if (!name.length) name = MSCall(proxy, @"itemName");
	if (!name.length) name = bid;
	info.name = name;

	NSString *ver = MSCall(proxy, @"shortVersionString");
	info.version = ver.length ? ver : @"";

	return info;
}

+ (BOOL)_isUserApp:(id)proxy {
	id type = MSCall(proxy, @"applicationType");
	if ([type isKindOfClass:[NSString class]]) {
		if ([type isEqualToString:@"User"]) return YES;
		if ([type isEqualToString:@"System"]) return NO;
	}
	// 兜底：可删除 = 用户安装
	id deletable = MSCall(proxy, @"isDeletable");
	if ([deletable isKindOfClass:[NSNumber class]]) return [deletable boolValue];
	return YES;
}

+ (NSArray<MSAppInfo *> *)allApps {
	static NSArray *cached;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		NSMutableArray *list = [NSMutableArray array];
		for (id proxy in [self _proxies]) {
			@try {
				MSAppInfo *info = [self _infoFromProxy:proxy];
				if (info) [list addObject:info];
			} @catch (__unused NSException *e) {}
		}
		[list sortUsingComparator:^NSComparisonResult(MSAppInfo *a, MSAppInfo *b) {
			return [a.name localizedStandardCompare:b.name];
		}];
		cached = [list copy];
	});
	return cached;
}

+ (NSArray<MSAppInfo *> *)userApps {
	static NSArray *cached;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		NSMutableArray *list = [NSMutableArray array];
		for (id proxy in [self _proxies]) {
			@try {
				if (![self _isUserApp:proxy]) continue;
				MSAppInfo *info = [self _infoFromProxy:proxy];
				if (info) [list addObject:info];
			} @catch (__unused NSException *e) {}
		}
		[list sortUsingComparator:^NSComparisonResult(MSAppInfo *a, MSAppInfo *b) {
			return [a.name localizedStandardCompare:b.name];
		}];
		cached = [list copy];
	});
	return cached;
}

+ (MSAppInfo *)appForBundleID:(NSString *)bundleID {
	if (!bundleID.length) return nil;
	for (MSAppInfo *info in [self allApps]) {
		if ([info.bundleID isEqualToString:bundleID]) return info;
	}
	// 系统 App 可能不在列表里，手工兜底
	MSAppInfo *info = [MSAppInfo new];
	info.bundleID = bundleID;
	info.name = bundleID;
	info.version = @"";
	return info;
}

+ (UIImage *)_iconViaPrivateAPI:(NSString *)bid size:(CGFloat)size {
	SEL sel = NSSelectorFromString(@"_applicationIconImageForBundleIdentifier:format:scale:");
	if (![UIImage respondsToSelector:sel]) return nil;
	CGFloat scale = [UIScreen mainScreen].scale;
	id img = ((id (*)(id, SEL, id, int, CGFloat))objc_msgSend)([UIImage class], sel, bid, 10, scale);
	return [img isKindOfClass:[UIImage class]] ? img : nil;
}

+ (UIImage *)_iconViaProxy:(NSString *)bid {
	Class cls = objc_getClass("LSApplicationProxy");
	if (!cls) return nil;
	id proxy = ((id (*)(id, SEL, id))objc_msgSend)((id)cls, NSSelectorFromString(@"applicationProxyForIdentifier:"), bid);
	if (!proxy) return nil;

	// iOS 15+ 优先
	id data = nil;
	SEL sel2 = NSSelectorFromString(@"iconDataForVariant:withOptions:");
	if ([proxy respondsToSelector:sel2]) {
		data = ((id (*)(id, SEL, int, id))objc_msgSend)(proxy, sel2, 0, nil);
	}
	if (!data) {
		data = MSCallInt(proxy, @"iconDataForVariant:", 0);
	}
	if ([data isKindOfClass:[NSData class]]) {
		UIImage *img = [UIImage imageWithData:data];
		if (img) return img;
	}
	return nil;
}

+ (UIImage *)iconForBundleID:(NSString *)bundleID size:(CGFloat)size {
	if (!bundleID.length) return nil;
	NSString *key = [NSString stringWithFormat:@"%@@%.0f", bundleID, size];
	@synchronized (MSIconCache()) {
		UIImage *cached = MSIconCache()[key];
		if (cached) return cached;
	}

	UIImage *icon = [self _iconViaPrivateAPI:bundleID size:size];
	if (!icon) icon = [self _iconViaProxy:bundleID];
	if (!icon) {
		// 最后兜底：系统占位
		icon = [UIImage systemImageNamed:@"square.grid.2x2.fill"];
	}

	if (icon && size > 0) {
		UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat defaultFormat];
		fmt.opaque = NO;
		UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(size, size) format:fmt];
		icon = [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
			[icon drawInRect:CGRectMake(0, 0, size, size)];
		}];
	}

	if (icon) {
		@synchronized (MSIconCache()) {
			MSIconCache()[key] = icon;
		}
	}
	return icon;
}

+ (BOOL)openApp:(NSString *)bundleID {
	if (!bundleID.length) return NO;
	id ws = [self _workspace];
	SEL sel = NSSelectorFromString(@"openApplicationWithBundleID:");
	if ([ws respondsToSelector:sel]) {
		BOOL ok = ((BOOL (*)(id, SEL, id))objc_msgSend)(ws, sel, bundleID);
		if (ok) return YES;
	}
	// 兜底：LSApplicationWorkspace 的 options 版本
	SEL sel2 = NSSelectorFromString(@"openApplicationWithBundleID:options:error:");
	if ([ws respondsToSelector:sel2]) {
		NSError *err = nil;
		BOOL ok = ((BOOL (*)(id, SEL, id, id, NSError **))objc_msgSend)(ws, sel2, bundleID, @{}, &err);
		return ok;
	}
	return NO;
}

+ (NSString *)frontmostBundleID {
	// SBWorkspace / SBMainWorkspace 的 application 属性 = 当前前台应用
	for (NSString *clsName in @[@"SBWorkspace", @"SBMainWorkspace"]) {
		Class cls = objc_getClass(clsName.UTF8String);
		if (!cls) continue;
		id ws = MSCall((id)cls, @"sharedInstance");
		id app = MSCall(ws, @"application");
		NSString *bid = MSCall(app, @"bundleIdentifier");
		if (bid.length) return bid;
	}
	// 兜底：switcher 列表里的第一个
	Class swCls = objc_getClass("SBAppSwitcherModel");
	id sw = MSCall((id)swCls, @"sharedInstance");
	id list = MSCall(sw, @"_appLayouts");
	for (id layout in ([list isKindOfClass:[NSArray class]] ? list : @[])) {
		id item = MSCall(layout, @"primaryDisplayItem");
		id app = MSCall(item, @"application");
		NSString *bid = MSCall(app, @"bundleIdentifier");
		if (bid.length) return bid;
	}
	return nil;
}

@end
