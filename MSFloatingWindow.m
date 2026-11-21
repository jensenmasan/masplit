#import "MSFloatingWindow.h"
#import "MSSnapshotProvider.h"
#import "MSPreferences.h"

static CGFloat MSClamp(CGFloat v, CGFloat lo, CGFloat hi) {
	return MAX(lo, MIN(hi, v));
}

@interface MSFloatingWindow () <UIGestureRecognizerDelegate> {
	UIView *_container;
	UIView *_header;
	UILabel *_titleLabel;
	UIButton *_minButton;
	UIButton *_closeButton;
	UIImageView *_snapshotView;
	UILabel *_hintLabel;
	UILabel *_watermark;

	CGPoint _panStartCenter;
	CGFloat _pinchStartScale;
	CGPoint _lastExpandedCenter;
	BOOL _interacting;
}
@end

@implementation MSFloatingWindow

#pragma mark - 尺寸

+ (CGSize)expandedSizeForScale:(CGFloat)scale screen:(CGRect)screen {
	CGFloat w = screen.size.width * scale;
	CGFloat maxHeightRatio = [MSPreferences shared].externalKeyboardMode ? 0.94 : 0.80;
	CGFloat h = MIN(screen.size.height * maxHeightRatio, w * 1.62);
	return CGSizeMake(round(w), round(h));
}

- (instancetype)initWithApp:(MSAppInfo *)app {
	CGRect screen = [UIScreen mainScreen].bounds;
	CGSize size = [MSFloatingWindow expandedSizeForScale:[MSPreferences shared].windowScale screen:screen];

	if ((self = [super initWithFrame:CGRectMake(0, 0, size.width, size.height)])) {
		_bundleID = [app.bundleID copy];
		_appName = [app.name copy];
		self.backgroundColor = [UIColor clearColor];
		self.center = CGPointMake(CGRectGetMidX(screen), CGRectGetMidY(screen) - 20);
		_lastExpandedCenter = self.center;

		self.layer.shadowColor = [UIColor blackColor].CGColor;
		self.layer.shadowOpacity = 0.42;
		self.layer.shadowRadius = 26;
		self.layer.shadowOffset = CGSizeMake(0, 14);

		[self buildUI];
		[self buildGestures];
		[self refreshSnapshot];
	}
	return self;
}

#pragma mark - UI

- (void)buildUI {
	CGFloat radius = [MSPreferences shared].cornerRadius;

	_container = [[UIView alloc] initWithFrame:self.bounds];
	_container.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	_container.backgroundColor = [UIColor blackColor];
	_container.layer.cornerRadius = radius;
	_container.layer.cornerCurve = kCACornerCurveContinuous;
	_container.layer.masksToBounds = YES;
	_container.layer.borderWidth = 0.8;
	_container.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.20].CGColor;
	[self addSubview:_container];

	_snapshotView = [[UIImageView alloc] initWithFrame:self.bounds];
	_snapshotView.contentMode = UIViewContentModeScaleAspectFill;
	_snapshotView.clipsToBounds = YES;
	_snapshotView.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1.0];
	[_container addSubview:_snapshotView];

	_header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.bounds.size.width, 36)];
	_header.layer.masksToBounds = YES;
	CAGradientLayer *grad = [CAGradientLayer layer];
	grad.frame = _header.bounds;
	grad.colors = @[
		(__bridge id)[UIColor colorWithWhite:0.0 alpha:0.62].CGColor,
		(__bridge id)[UIColor colorWithWhite:0.0 alpha:0.0].CGColor,
	];
	[_header.layer addSublayer:grad];
	[_container addSubview:_header];

	_titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_titleLabel.text = _appName;
	_titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
	_titleLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.92];
	[_header addSubview:_titleLabel];

	_minButton = [self _circleButtonWithSymbol:@"minus" action:@selector(onMinimizeTapped)];
	[_header addSubview:_minButton];

	_closeButton = [self _circleButtonWithSymbol:@"xmark" action:@selector(onCloseTapped)];
	[_header addSubview:_closeButton];

	_hintLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_hintLabel.text = @"轻点打开 · 拖动移动 · 双指缩放";
	_hintLabel.font = [UIFont systemFontOfSize:9.5 weight:UIFontWeightMedium];
	_hintLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.55];
	[_container addSubview:_hintLabel];

	_watermark = [[UILabel alloc] initWithFrame:CGRectZero];
	_watermark.text = [MSPreferences shared].watermark;
	_watermark.font = [UIFont systemFontOfSize:9 weight:UIFontWeightSemibold];
	_watermark.textColor = [UIColor colorWithWhite:1.0 alpha:0.28];
	_watermark.textAlignment = NSTextAlignmentRight;
	[_container addSubview:_watermark];

	[self updateShadowPath];
}

- (UIButton *)_circleButtonWithSymbol:(NSString *)symbol action:(SEL)action {
	UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
	btn.frame = CGRectMake(0, 0, 26, 26);
	btn.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.35];
	btn.layer.cornerRadius = 13;
	btn.tintColor = [UIColor colorWithWhite:1.0 alpha:0.9];
	UIImage *img = [UIImage systemImageNamed:symbol];
	[btn setImage:img forState:UIControlStateNormal];
	btn.imageView.contentMode = UIViewContentModeScaleAspectFit;
	btn.contentEdgeInsets = UIEdgeInsetsMake(6, 6, 6, 6);
	[btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
	return btn;
}

- (void)layoutSubviews {
	[super layoutSubviews];

	CGFloat w = self.bounds.size.width;
	CGFloat h = self.bounds.size.height;

	_container.frame = self.bounds;
	_snapshotView.frame = self.bounds;
	_header.frame = CGRectMake(0, 0, w, 36);
	_titleLabel.frame = CGRectMake(12, 4, w - 84, 28);
	_minButton.frame = CGRectMake(w - 64, 5, 26, 26);
	_closeButton.frame = CGRectMake(w - 34, 5, 26, 26);
	_hintLabel.frame = CGRectMake(12, h - 24, w - 24, 14);
	_watermark.frame = CGRectMake(12, h - 40, w - 24, 14);

	for (CALayer *layer in _header.layer.sublayers) {
		if ([layer isKindOfClass:[CAGradientLayer class]]) layer.frame = _header.bounds;
	}
	[self updateShadowPath];
}

- (void)updateShadowPath {
	CGFloat radius = _container.layer.cornerRadius;
	self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:radius].CGPath;
}

#pragma mark - 手势

- (void)buildGestures {
	UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onPan:)];
	pan.delegate = self;
	[self addGestureRecognizer:pan];

	UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(onPinch:)];
	[self addGestureRecognizer:pinch];

	UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onDoubleTap:)];
	doubleTap.numberOfTapsRequired = 2;
	[self addGestureRecognizer:doubleTap];

	UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap:)];
	[tap requireGestureRecognizerToFail:doubleTap];
	[self addGestureRecognizer:tap];

	UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(onLongPress:)];
	longPress.minimumPressDuration = 0.55;
	[self addGestureRecognizer:longPress];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)g shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
	return g == other ? YES : NO;
}

- (void)onPan:(UIPanGestureRecognizer *)g {
	CGPoint translation = [g translationInView:self.superview];

	switch (g.state) {
		case UIGestureRecognizerStateBegan: {
			_panStartCenter = self.center;
			[self.superview bringSubviewToFront:self];
			_interacting = YES;
			[self.delegate floatingWindowDidBeginInteraction:self];
			break;
		}
		case UIGestureRecognizerStateChanged: {
			self.center = CGPointMake(_panStartCenter.x + translation.x, _panStartCenter.y + translation.y);
			break;
		}
		case UIGestureRecognizerStateEnded:
		case UIGestureRecognizerStateCancelled:
		case UIGestureRecognizerStateFailed: {
			_interacting = NO;
			[self settleAfterDrag];
			[self.delegate floatingWindowDidEndInteraction:self];
			break;
		}
		default: break;
	}
}

- (void)settleAfterDrag {
	CGRect screen = [UIScreen mainScreen].bounds;

	if (self.minimized) {
		CGFloat y = MSClamp(self.center.y, 120, screen.size.height - 120);
		BOOL left = self.center.x < screen.size.width / 2;
		CGPoint target = CGPointMake(left ? 30 : screen.size.width - 30, y);
		[UIView animateWithDuration:0.24 delay:0 usingSpringWithDamping:0.86 initialSpringVelocity:0.4 options:UIViewAnimationOptionAllowUserInteraction animations:^{
			self.center = target;
		} completion:nil];
		return;
	}

	CGFloat w = self.bounds.size.width * self.transform.a;
	CGFloat h = self.bounds.size.height * self.transform.d;

	// 拖到左右边缘 → 自动收成卡片
	if (self.center.x < screen.size.width * 0.14) {
		[self minimizeToEdge:YES animated:YES];
		return;
	}
	if (self.center.x > screen.size.width * 0.86) {
		[self minimizeToEdge:NO animated:YES];
		return;
	}

	CGPoint clamped = CGPointMake(MSClamp(self.center.x, w / 2 + 6, screen.size.width - w / 2 - 6),
	                              MSClamp(self.center.y, h / 2 + 28, screen.size.height - h / 2 - 16));
	if (!CGPointEqualToPoint(clamped, self.center)) {
		[UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionAllowUserInteraction animations:^{
			self.center = clamped;
		} completion:nil];
	}
	_lastExpandedCenter = clamped;
}

- (void)onPinch:(UIPinchGestureRecognizer *)g {
	if (self.minimized) return;

	if (g.state == UIGestureRecognizerStateBegan) {
		_pinchStartScale = self.bounds.size.width / [UIScreen mainScreen].bounds.size.width;
	}
	if (g.state == UIGestureRecognizerStateChanged) {
		CGFloat shown = MSClamp(_pinchStartScale * g.scale, 0.30, 1.0);
		CGFloat factor = shown / _pinchStartScale;
		self.transform = CGAffineTransformMakeScale(factor, factor);
	}
	if (g.state == UIGestureRecognizerStateEnded || g.state == UIGestureRecognizerStateCancelled) {
		CGFloat finalScale = MSClamp(_pinchStartScale * g.scale, 0.30, 1.0);
		self.transform = CGAffineTransformIdentity;
		[self applyWindowScale:finalScale cornerRadius:[MSPreferences shared].cornerRadius];
		[self settleAfterDrag];
	}
}

- (void)onTap:(UITapGestureRecognizer *)g {
	if (self.minimized) {
		[self setMinimized:NO animated:YES];
		return;
	}
	[self.delegate floatingWindowDidTap:self];
}

- (void)onDoubleTap:(UITapGestureRecognizer *)g {
	[self setMinimized:!self.minimized animated:YES];
}

- (void)onLongPress:(UILongPressGestureRecognizer *)g {
	if (g.state != UIGestureRecognizerStateBegan) return;

	UIAlertController *sheet = [UIAlertController alertControllerWithTitle:self.appName
	                                                               message:@"马老师专属分屏"
	                                                        preferredStyle:UIAlertControllerStyleActionSheet];
	[sheet addAction:[UIAlertAction actionWithTitle:@"刷新快照" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
		[self refreshSnapshot];
	}]];
	[sheet addAction:[UIAlertAction actionWithTitle:self.minimized ? @"展开浮窗" : @"收起到边缘" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
		[self setMinimized:!self.minimized animated:YES];
	}]];
	[sheet addAction:[UIAlertAction actionWithTitle:@"关闭浮窗" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
		[self.delegate floatingWindowDidRequestClose:self];
	}]];
	[sheet addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];

	UIViewController *host = [self _hostViewController];
	if (host) {
		if (sheet.popoverPresentationController) {
			sheet.popoverPresentationController.sourceView = self;
			sheet.popoverPresentationController.sourceRect = self.bounds;
		}
		[host presentViewController:sheet animated:YES completion:nil];
	}
}

- (UIViewController *)_hostViewController {
	UIResponder *responder = self;
	while (responder) {
		if ([responder isKindOfClass:[UIViewController class]]) return (UIViewController *)responder;
		responder = responder.nextResponder;
	}
	return [UIApplication sharedApplication].keyWindow.rootViewController;
}

#pragma mark - 按钮

- (void)onMinimizeTapped { [self setMinimized:YES animated:YES]; }
- (void)onCloseTapped { [self.delegate floatingWindowDidRequestClose:self]; }

#pragma mark - 状态

- (void)setMinimized:(BOOL)minimized animated:(BOOL)animated {
	if (_minimized == minimized) return;
	_minimized = minimized;

	CGRect screen = [UIScreen mainScreen].bounds;
	if (minimized) _lastExpandedCenter = self.center;

	CGFloat cardWidth = 54.0;
	CGFloat scale = cardWidth / MAX(1, self.bounds.size.width);
	CGFloat y = MSClamp(self.center.y, 130, screen.size.height - 130);
	BOOL left = self.center.x < screen.size.width / 2;
	CGPoint target = CGPointMake(left ? 30 : screen.size.width - 30, y);

	void (^apply)(void) = ^{
		self.transform = minimized ? CGAffineTransformMakeScale(scale, scale) : CGAffineTransformIdentity;
		self.center = minimized ? target : self->_lastExpandedCenter;
		self->_header.alpha = minimized ? 0 : 1;
		self->_hintLabel.alpha = minimized ? 0 : 1;
		self->_watermark.alpha = minimized ? 0 : 1;
		self.layer.shadowOpacity = minimized ? 0.22 : 0.42;
		self->_container.layer.cornerRadius = minimized ? 12 : [MSPreferences shared].cornerRadius;
	};

	if (animated) {
		[UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.84 initialSpringVelocity:0.5
		                    options:UIViewAnimationOptionAllowUserInteraction animations:apply completion:nil];
	} else {
		apply();
	}

	[self.delegate floatingWindowDidChangeMinimizedState:self];
}

- (void)minimizeToEdge:(BOOL)left animated:(BOOL)animated {
	if (_minimized) return;
	CGRect screen = [UIScreen mainScreen].bounds;
	CGFloat cardWidth = 54.0;
	CGFloat scale = cardWidth / MAX(1, self.bounds.size.width);
	CGFloat y = MSClamp(self.center.y, 130, screen.size.height - 130);
	CGPoint target = CGPointMake(left ? 30 : screen.size.width - 30, y);
	_lastExpandedCenter = self.center;
	_minimized = YES;

	void (^apply)(void) = ^{
		self.transform = CGAffineTransformMakeScale(scale, scale);
		self.center = target;
		self->_header.alpha = 0;
		self->_hintLabel.alpha = 0;
		self->_watermark.alpha = 0;
		self.layer.shadowOpacity = 0.22;
		self->_container.layer.cornerRadius = 12;
	};
	if (animated) {
		[UIView animateWithDuration:0.32 delay:0 usingSpringWithDamping:0.82 initialSpringVelocity:0.6
		                    options:UIViewAnimationOptionAllowUserInteraction animations:apply completion:nil];
	} else {
		apply();
	}
	[self.delegate floatingWindowDidChangeMinimizedState:self];
}

- (void)refreshSnapshot {
	CGSize size = self.bounds.size;
	if (size.width < 1) size = CGSizeMake(240, 400);
	UIImage *snap = [MSSnapshotProvider snapshotForBundleID:_bundleID size:size];
	if (snap) _snapshotView.image = snap;
}

- (void)applyWindowScale:(CGFloat)scale cornerRadius:(CGFloat)radius {
	CGRect screen = [UIScreen mainScreen].bounds;
	CGSize size = [MSFloatingWindow expandedSizeForScale:scale screen:screen];
	self.bounds = CGRectMake(0, 0, size.width, size.height);
	_container.layer.cornerRadius = radius;
	[self setNeedsLayout];
	[self layoutIfNeeded];
	[self refreshSnapshot];
}

- (void)presentWithAnimation {
	self.alpha = 0;
	self.transform = CGAffineTransformMakeScale(0.88, 0.88);
	self.center = CGPointMake(self.center.x, self.center.y + 26);
	[UIView animateWithDuration:0.36 delay:0 usingSpringWithDamping:0.76 initialSpringVelocity:0.7
	                    options:UIViewAnimationOptionAllowUserInteraction animations:^{
		self.alpha = 1;
		self.transform = CGAffineTransformIdentity;
		self.center = self->_lastExpandedCenter;
	} completion:nil];
}

- (void)dismissWithAnimation:(void (^)(void))completion {
	[UIView animateWithDuration:0.22 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
		self.alpha = 0;
		self.transform = CGAffineTransformMakeScale(0.86, 0.86);
	} completion:^(BOOL finished) {
		[self removeFromSuperview];
		if (completion) completion();
	}];
}

- (BOOL)expanded { return !_minimized; }

- (CGRect)visibleFrameInScreen {
	CGSize size = CGSizeMake(self.bounds.size.width * self.transform.a,
	                         self.bounds.size.height * self.transform.d);
	return CGRectMake(self.center.x - size.width / 2, self.center.y - size.height / 2, size.width, size.height);
}

@end
