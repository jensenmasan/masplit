//
//  Tweak.xm
//  马老师分屏 · SpringBoard 入口
//

#import <UIKit/UIKit.h>
#import <notify.h>
#import "MSWindowManager.h"
#import "MSPreferences.h"
#import "MSMultiTasking.h"

#pragma mark - 悬浮球拖动

@interface UIButton (MaSplitDrag)
- (void)ms_handlePan:(UIPanGestureRecognizer *)g;
@end

@implementation UIButton (MaSplitDrag)

- (void)ms_handlePan:(UIPanGestureRecognizer *)g {
	static CGPoint start;
	CGPoint translation = [g translationInView:self.superview];

	if (g.state == UIGestureRecognizerStateBegan) start = self.center;

	if (g.state == UIGestureRecognizerStateChanged) {
		CGRect sb = self.superview.bounds;
		CGFloat x = MAX(28, MIN(sb.size.width - 28, start.x + translation.x));
		CGFloat y = MAX(80, MIN(sb.size.height - 60, start.y + translation.y));
		self.center = CGPointMake(x, y);
	}

	if (g.state == UIGestureRecognizerStateEnded || g.state == UIGestureRecognizerStateCancelled) {
		CGRect sb = self.superview.bounds;
		BOOL left = self.center.x < sb.size.width / 2;
		[UIView animateWithDuration:0.28 delay:0 usingSpringWithDamping:0.82 initialSpringVelocity:0.4
		                    options:UIViewAnimationOptionAllowUserInteraction animations:^{
			self.center = CGPointMake(left ? 26 : sb.size.width - 26, self.center.y);
		} completion:nil];
	}
}

@end

#pragma mark - 右侧悬浮球

static UIButton *gLauncherButton = nil;

static void MSInstallLauncher(UIView *host) {
	if (!host) return;
	if (![MSPreferences shared].enabled) return;
	if (gLauncherButton && gLauncherButton.superview == host) return;

	[gLauncherButton removeFromSuperview];
	gLauncherButton = nil;

	CGFloat size = 44.0;
	CGRect bounds = host.bounds;
	UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
	btn.frame = CGRectMake(bounds.size.width - size - 8, bounds.size.height * 0.40, size, size);
	btn.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
	btn.layer.cornerRadius = size / 2.0;
	btn.layer.cornerCurve = kCACornerCurveContinuous;
	btn.backgroundColor = [UIColor colorWithWhite:0.04 alpha:0.55];
	btn.layer.borderWidth = 0.8;
	btn.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.30].CGColor;
	btn.layer.shadowColor = [UIColor blackColor].CGColor;
	btn.layer.shadowOpacity = 0.35;
	btn.layer.shadowRadius = 10;
	btn.layer.shadowOffset = CGSizeMake(0, 5);
	btn.tintColor = [UIColor colorWithWhite:1.0 alpha:0.92];
	[btn setImage:[UIImage systemImageNamed:@"rectangle.split.2x1.fill"] forState:UIControlStateNormal];
	btn.imageView.contentMode = UIViewContentModeScaleAspectFit;
	btn.contentEdgeInsets = UIEdgeInsetsMake(10, 8, 10, 8);
	[btn addTarget:[MSWindowManager shared] action:@selector(showRingSelector) forControlEvents:UIControlEventTouchUpInside];

	UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:btn action:@selector(ms_handlePan:)];
	[btn addGestureRecognizer:pan];

	[host addSubview:btn];
	gLauncherButton = btn;
}

#pragma mark - SpringBoard 钩子

%hook SBHomeScreenViewController

- (void)viewDidAppear:(BOOL)animated {
	%orig;
	UIView *hostView = self.view;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[[MSWindowManager shared] attachToHomeScreen:hostView];
		MSInstallLauncher(hostView);
	});
}

%end

#pragma mark - 启动初始化

%ctor {
	@autoreleasepool {
		int prefsToken = 0;
		notify_register_dispatch("com.malaoshi.masplit/prefsChanged", &prefsToken, dispatch_get_main_queue(), ^(int t) {
			[[MSMultiTasking shared] activateIfEnabled];
		});

		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			if (![MSPreferences shared].enabled) return;
			[[MSWindowManager shared] hostWindow];
			[[MSMultiTasking shared] activateIfEnabled];
		});
	}
}
