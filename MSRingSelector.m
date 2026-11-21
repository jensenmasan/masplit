#import "MSRingSelector.h"
#import "MSPreferences.h"

static MSRingSelector *gSelector = nil;

@interface MSRingSelector () {
	NSArray<MSAppInfo *> *_apps;
	void (^_onPick)(MSAppInfo *);
	NSMutableArray<UIButton *> *_iconButtons;
	CGPoint _panStartCenter;
}
@end

@implementation MSRingSelector

+ (void)presentFromView:(UIView *)hostView apps:(NSArray<MSAppInfo *> *)apps onPick:(void (^)(MSAppInfo *))onPick {
	if (!hostView || gSelector) return;
	MSRingSelector *sel = [[MSRingSelector alloc] initWithFrame:hostView.bounds apps:apps onPick:onPick];
	sel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[hostView addSubview:sel];
	gSelector = sel;
	[sel animateIn];
}

- (instancetype)initWithFrame:(CGRect)frame apps:(NSArray<MSAppInfo *> *)apps onPick:(void (^)(MSAppInfo *))onPick {
	if ((self = [super initWithFrame:frame])) {
		_apps = apps ?: @[];
		_onPick = [onPick copy];
		_iconButtons = [NSMutableArray array];

		self.backgroundColor = [UIColor colorWithWhite:0.02 alpha:0.72];
		self.alpha = 0;

		[self buildStars];
		[self buildHeader];
		[self buildIcons];
		[self buildGestures];
	}
	return self;
}

- (void)buildStars {
	NSInteger count = 70;
	unsigned int seed = 20261121;
	for (NSInteger i = 0; i < count; i++) {
		seed = seed * 1103515245 + 12345;
		CGFloat x = (CGFloat)((seed >> 8) % 1000) / 1000.0 * self.bounds.size.width;
		seed = seed * 1103515245 + 12345;
		CGFloat y = (CGFloat)((seed >> 8) % 1000) / 1000.0 * self.bounds.size.height;
		CGFloat r = 0.7 + (CGFloat)((seed >> 16) % 16) / 10.0;

		CALayer *dot = [CALayer layer];
		dot.frame = CGRectMake(x, y, r, r);
		dot.cornerRadius = r / 2;
		dot.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.18 + (CGFloat)((seed >> 4) % 40) / 100.0].CGColor;
		[self.layer addSublayer:dot];
	}
}

- (void)buildHeader {
	UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(0, 64, self.bounds.size.width, 26)];
	title.text = @"马老师专属 · 挑一个放上来";
	title.textAlignment = NSTextAlignmentCenter;
	title.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
	title.textColor = [UIColor colorWithWhite:1.0 alpha:0.85];
	[self addSubview:title];

	UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(0, 90, self.bounds.size.width, 18)];
	sub.text = @"点图标开浮窗 · 点空白收起";
	sub.textAlignment = NSTextAlignmentCenter;
	sub.font = [UIFont systemFontOfSize:10 weight:UIFontWeightRegular];
	sub.textColor = [UIColor colorWithWhite:1.0 alpha:0.4];
	[self addSubview:sub];
}

- (void)buildIcons {
	NSUInteger n = _apps.count;
	if (n == 0) return;

	CGPoint center = CGPointMake(self.bounds.size.width / 2, self.bounds.size.height * 0.56);
	CGFloat maxRadius = MIN(self.bounds.size.width * 0.42, self.bounds.size.height * 0.30);
	CGFloat goldenAngle = M_PI * (3.0 - sqrt(5.0));
	CGFloat iconSize = 56.0;

	for (NSUInteger i = 0; i < n; i++) {
		MSAppInfo *info = _apps[i];
		CGFloat t = (n <= 1) ? 0.0 : (CGFloat)i / (CGFloat)(n - 1);
		CGFloat radius = sqrt(t) * maxRadius;
		CGFloat theta = (CGFloat)i * goldenAngle;

		CGPoint p = CGPointMake(center.x + cos(theta) * radius, center.y + sin(theta) * radius);
		p.y = MAX(130.0, MIN(self.bounds.size.height - 60.0, p.y));

		UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
		btn.frame = CGRectMake(p.x - iconSize / 2, p.y - iconSize / 2, iconSize, iconSize);
		btn.layer.cornerRadius = iconSize / 2;
		btn.layer.cornerCurve = kCACornerCurveContinuous;
		btn.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.10];
		btn.layer.borderWidth = 0.8;
		btn.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.22].CGColor;
		btn.layer.shadowColor = [UIColor blackColor].CGColor;
		btn.layer.shadowOpacity = 0.35;
		btn.layer.shadowRadius = 10;
		btn.layer.shadowOffset = CGSizeMake(0, 5);
		btn.tag = (NSInteger)i;
		[btn addTarget:self action:@selector(onIconTapped:) forControlEvents:UIControlEventTouchUpInside];

		UIImage *icon = [MSAppListProvider iconForBundleID:info.bundleID size:40];
		[btn setImage:[icon imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] forState:UIControlStateNormal];
		btn.imageView.contentMode = UIViewContentModeScaleAspectFit;

		btn.alpha = 0;
		btn.transform = CGAffineTransformMakeScale(0.3, 0.3);
		[self addSubview:btn];
		[_iconButtons addObject:btn];
	}
}

- (void)buildGestures {
	UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onBackgroundTap:)];
	[self addGestureRecognizer:tap];

	UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onPan:)];
	[self addGestureRecognizer:pan];
}

- (void)onBackgroundTap:(UITapGestureRecognizer *)g {
	// 图标是 UIButton，会自己消化点击；能走到这里就是点了空白
	[self dismiss];
}

- (void)onPan:(UIPanGestureRecognizer *)g {
	CGPoint t = [g translationInView:self];
	if (g.state == UIGestureRecognizerStateBegan) _panStartCenter = self.center;
	if (g.state == UIGestureRecognizerStateChanged) {
		CGFloat dx = MAX(-40, MIN(40, t.x * 0.25));
		CGFloat dy = MAX(-40, MIN(40, t.y * 0.25));
		for (UIButton *btn in _iconButtons) {
			btn.transform = CGAffineTransformMakeTranslation(dx, dy);
		}
	}
	if (g.state == UIGestureRecognizerStateEnded || g.state == UIGestureRecognizerStateCancelled) {
		[UIView animateWithDuration:0.4 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.4 options:0 animations:^{
			for (UIButton *btn in self->_iconButtons) btn.transform = CGAffineTransformIdentity;
		} completion:nil];
	}
}

- (void)onIconTapped:(UIButton *)btn {
	NSInteger idx = btn.tag;
	if (idx < 0 || idx >= (NSInteger)_apps.count) return;
	MSAppInfo *info = _apps[idx];

	[UIView animateWithDuration:0.18 animations:^{
		btn.transform = CGAffineTransformMakeScale(1.18, 1.18);
	}];

	void (^pick)(void) = ^{
		if (self->_onPick) self->_onPick(info);
	};
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		[self dismiss];
		pick();
	});
}

- (void)animateIn {
	self.alpha = 0;
	[UIView animateWithDuration:0.22 animations:^{ self.alpha = 1; }];

	for (NSUInteger i = 0; i < _iconButtons.count; i++) {
		UIButton *btn = _iconButtons[i];
		[UIView animateWithDuration:0.5
		                      delay:0.012 * i
		     usingSpringWithDamping:0.68
		      initialSpringVelocity:0.5
		                    options:UIViewAnimationOptionAllowUserInteraction
		                 animations:^{
			btn.alpha = 1;
			btn.transform = CGAffineTransformIdentity;
		} completion:nil];
	}
}

- (void)dismiss {
	[UIView animateWithDuration:0.22 animations:^{
		self.alpha = 0;
		for (UIButton *btn in self->_iconButtons) {
			btn.transform = CGAffineTransformMakeScale(0.4, 0.4);
			btn.alpha = 0;
		}
	} completion:^(BOOL finished) {
		[self removeFromSuperview];
		gSelector = nil;
	}];
}

- (void)dealloc {
	if (gSelector == self) gSelector = nil;
}

@end
