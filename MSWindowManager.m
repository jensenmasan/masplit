#import "MSWindowManager.h"
#import "MSPreferences.h"
#import "MSAppListProvider.h"
#import "MSSnapshotProvider.h"
#import "MSRingSelector.h"
#import <notify.h>

static NSString *const kStatePath = @"/var/mobile/Library/Preferences/com.malaoshi.masplit.state.plist";

#pragma mark - 触摸穿透视图

@interface MSTouchPassThroughView : UIView @end
@implementation MSTouchPassThroughView
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
	UIView *hit = [super hitTest:point withEvent:event];
	// 空白处返回 nil，让触摸落到底下的 SpringBoard / App
	return (hit == self) ? nil : hit;
}
@end

@interface MSTouchPassThroughController : UIViewController @end
@implementation MSTouchPassThroughController
- (void)loadView {
	self.view = [[MSTouchPassThroughView alloc] initWithFrame:[UIScreen mainScreen].bounds];
	self.view.backgroundColor = [UIColor clearColor];
	self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
}
- (BOOL)prefersStatusBarHidden { return NO; }
- (UIStatusBarStyle)preferredStatusBarStyle { return UIStatusBarStyleLightContent; }
@end

#pragma mark - 管理器

@interface MSWindowManager () <UIGestureRecognizerDelegate> {
	NSMutableArray<MSFloatingWindow *> *_windows;
	UIWindow *_hostWindow;
	UIView *_homeView;
	__weak UIView *_gestureHost;
	CGPoint _edgeStartPoint;
	BOOL _gesturesInstalled;
}
@end

@implementation MSWindowManager

+ (instancetype)shared {
	static dispatch_once_t once;
	static MSWindowManager *inst;
	dispatch_once(&once, ^{ inst = [[MSWindowManager alloc] init]; });
	return inst;
}

- (instancetype)init {
	if ((self = [super init])) {
		_windows = [NSMutableArray array];

		int token = 0;
		notify_register_dispatch("com.malaoshi.masplit/prefsChanged", &token, dispatch_get_main_queue(), ^(int t) {
			[self applyPreferences];
			[self _installGesturesIfNeeded];
		});

		int openToken = 0;
		notify_register_dispatch("com.malaoshi.masplit.openSelector", &openToken, dispatch_get_main_queue(), ^(int t) {
			[self showRingSelector];
		});
	}
	return self;
}

#pragma mark - 宿主窗口

- (UIWindow *)hostWindow {
	if (_hostWindow) return _hostWindow;

	UIWindowScene *scene = nil;
	for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
		if ([s isKindOfClass:[UIWindowScene class]]) { scene = (UIWindowScene *)s; break; }
	}

	UIWindow *win = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
	if (scene) win.windowScene = scene;
	win.windowLevel = UIWindowLevelAlert - 1;
	win.backgroundColor = [UIColor clearColor];
	win.rootViewController = [MSTouchPassThroughController new];
	win.hidden = NO;
	_hostWindow = win;
	return _hostWindow;
}

- (BOOL)hasVisibleWindows {
	for (MSFloatingWindow *w in _windows) {
		if (w.window && !w.hidden) return YES;
	}
	return NO;
}

#pragma mark - 挂载

- (void)attachToHomeScreen:(UIView *)homeView {
	if (!homeView) return;
	_homeView = homeView;
	[self _installGesturesIfNeeded];
	[self _restoreSavedWindows];
}

- (void)_installGesturesIfNeeded {
	if (!_homeView || !_homeView.window) return;
	if (_gesturesInstalled && _gestureHost == _homeView) return;

	// 桌面视图重建过，旧手势跟着旧视图走了，这里重新挂
	_gestureHost = _homeView;
	_gesturesInstalled = YES;

	UIScreenEdgePanGestureRecognizer *left = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(onEdgePan:)];
	left.edges = UIRectEdgeLeft;
	left.delegate = self;
	[_homeView addGestureRecognizer:left];

	UIScreenEdgePanGestureRecognizer *right = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(onEdgePan:)];
	right.edges = UIRectEdgeRight;
	right.delegate = self;
	[_homeView addGestureRecognizer:right];

	UITapGestureRecognizer *blankTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onBlankTap:)];
	blankTap.delegate = self;
	blankTap.cancelsTouchesInView = NO;
	[_homeView addGestureRecognizer:blankTap];
}

#pragma mark - 边缘手势

- (void)onEdgePan:(UIScreenEdgePanGestureRecognizer *)g {
	if (![MSPreferences shared].enabled) return;

	switch (g.state) {
		case UIGestureRecognizerStateBegan:
			_edgeStartPoint = [g locationInView:_homeView];
			break;
		case UIGestureRecognizerStateEnded: {
			CGPoint v = [g velocityInView:_homeView];
			CGFloat need = [MSPreferences shared].swipeVelocity;
			CGFloat h = _homeView.bounds.size.height;
			CGFloat y = _edgeStartPoint.y;

			// 在顶部区域向下拉 → 收起；在底部区域向上推 → 环形选择器
			if (y < [MSPreferences shared].topTriggerHeight) {
				if (v.y > need) [self minimizeAll];
			} else if (y > h - [MSPreferences shared].bottomTriggerHeight) {
				if (v.y < -need) [self showRingSelector];
			} else {
				if (fabs(v.y) > need) [self toggleCollapse];
			}
			break;
		}
		default: break;
	}
}

- (void)onBlankTap:(UITapGestureRecognizer *)g {
	if (![MSPreferences shared].enabled || ![MSPreferences shared].dismissOnBlankTap) return;
	if (![self hasVisibleWindows]) return;

	CGPoint p = [g locationInView:_homeView];
	for (MSFloatingWindow *w in _windows) {
		if (w.hidden || !w.window) continue;
		if (CGRectContainsPoint([w visibleFrameInScreen], p)) return;
	}
	[self minimizeAll];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)g shouldReceiveTouch:(UITouch *)touch {
	if ([g isKindOfClass:[UITapGestureRecognizer class]]) {
		if ([touch.view isKindOfClass:[UIControl class]]) return NO;
		if ([touch.view isDescendantOfView:self.hostWindow.rootViewController.view]) return NO;
	}
	return YES;
}

#pragma mark - 显示 / 关闭

- (MSFloatingWindow *)showAppWithBundleID:(NSString *)bundleID {
	if (!bundleID.length || ![MSPreferences shared].enabled) return nil;

	for (MSFloatingWindow *w in _windows) {
		if ([w.bundleID isEqualToString:bundleID]) {
			[w setMinimized:NO animated:YES];
			return w;
		}
	}

	NSInteger limit = [MSPreferences shared].maxWindows;
	while ((NSInteger)_windows.count >= limit && _windows.count > 0) {
		MSFloatingWindow *oldest = _windows.firstObject;
		[oldest dismissWithAnimation:nil];
		[_windows removeObjectAtIndex:0];
	}

	MSAppInfo *info = [MSAppListProvider appForBundleID:bundleID];
	MSFloatingWindow *win = [[MSFloatingWindow alloc] initWithApp:info];
	win.delegate = self;

	UIView *host = self.hostWindow.rootViewController.view;
	NSInteger idx = (NSInteger)_windows.count;
	CGPoint offset = CGPointMake((idx % 3) * 18 - 18, (idx % 3) * 26 - 26);
	win.center = CGPointMake(win.center.x + offset.x, win.center.y + offset.y);

	[host addSubview:win];
	[win presentWithAnimation];
	[_windows addObject:win];

	[self _saveWindows];
	return win;
}

- (void)removeWindow:(MSFloatingWindow *)win {
	if (![_windows containsObject:win]) return;
	[_windows removeObject:win];
	[self _saveWindows];
}

- (void)minimizeAll {
	for (MSFloatingWindow *w in _windows) {
		if (!w.minimized) [w setMinimized:YES animated:YES];
	}
}

- (void)restoreAll {
	for (MSFloatingWindow *w in _windows) {
		if (w.minimized) [w setMinimized:NO animated:YES];
	}
}

- (void)toggleCollapse {
	BOOL anyExpanded = NO;
	for (MSFloatingWindow *w in _windows) {
		if (!w.minimized) { anyExpanded = YES; break; }
	}
	if (anyExpanded) [self minimizeAll];
	else [self restoreAll];
}

- (void)closeAll {
	for (MSFloatingWindow *w in [_windows copy]) {
		[w dismissWithAnimation:nil];
	}
	[_windows removeAllObjects];
	[self _saveWindows];
}

- (void)showRingSelector {
	[MSRingSelector presentFromView:self.hostWindow.rootViewController.view
	                     apps:[MSAppListProvider userApps]
	                 onPick:^(MSAppInfo *app) {
		[self showAppWithBundleID:app.bundleID];
	}];
}

#pragma mark - 设置变更

- (void)applyPreferences {
	CGFloat radius = [MSPreferences shared].cornerRadius;
	CGFloat scale = [MSPreferences shared].windowScale;
	for (MSFloatingWindow *w in _windows) {
		if (w.minimized) continue;
		[w applyWindowScale:scale cornerRadius:radius];
	}
	if (![MSPreferences shared].enabled) [self closeAll];
}

#pragma mark - 持久化

- (void)_saveWindows {
	NSMutableArray *ids = [NSMutableArray array];
	for (MSFloatingWindow *w in _windows) {
		if (w.bundleID) [ids addObject:w.bundleID];
	}
	NSDictionary *state = @{@"windows": ids, @"updated": [NSDate date]};
	[state writeToFile:kStatePath atomically:YES];
}

- (void)_restoreSavedWindows {
	if (_windows.count > 0) return;
	if (![MSPreferences shared].enabled) return;

	NSDictionary *state = [NSDictionary dictionaryWithContentsOfFile:kStatePath];
	NSArray *ids = state[@"windows"];
	if (![ids isKindOfClass:[NSArray class]] || ids.count == 0) return;

	NSInteger limit = [MSPreferences shared].maxWindows;
	NSInteger i = 0;
	for (NSString *bid in ids) {
		if (i++ >= limit) break;
		if (![bid isKindOfClass:[NSString class]]) continue;
		MSAppInfo *info = [MSAppListProvider appForBundleID:bid];
		MSFloatingWindow *win = [[MSFloatingWindow alloc] initWithApp:info];
		win.delegate = self;
		[self.hostWindow.rootViewController.view addSubview:win];
		[win setMinimized:YES animated:NO];
		win.hidden = YES;          // 重启后先藏在边缘，等手势唤出
		[_windows addObject:win];
	}
}

#pragma mark - MSFloatingWindowDelegate

- (void)floatingWindowDidRequestClose:(MSFloatingWindow *)window {
	[window dismissWithAnimation:^{
		[self removeWindow:window];
	}];
}

- (void)floatingWindowDidTap:(MSFloatingWindow *)window {
	[MSAppListProvider openApp:window.bundleID];
	[window setMinimized:YES animated:YES];
}

- (void)floatingWindowDidBeginInteraction:(MSFloatingWindow *)window {
	[window.superview bringSubviewToFront:window];
	window.hidden = NO;
}

- (void)floatingWindowDidEndInteraction:(MSFloatingWindow *)window {
	[self _saveWindows];
}

- (void)floatingWindowDidChangeMinimizedState:(MSFloatingWindow *)window {
	if (window.minimized) window.hidden = NO;
	[self _saveWindows];
}

@end
