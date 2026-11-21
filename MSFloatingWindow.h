//
//  MSFloatingWindow.h
//  单个浮窗：圆角卡片 + 快照 + 拖动/双指缩放/吸附边缘/最小化成侧边卡片
//

#import <UIKit/UIKit.h>
#import "MSAppListProvider.h"

@class MSFloatingWindow;

@protocol MSFloatingWindowDelegate <NSObject>
- (void)floatingWindowDidRequestClose:(MSFloatingWindow *)window;
- (void)floatingWindowDidTap:(MSFloatingWindow *)window;
- (void)floatingWindowDidBeginInteraction:(MSFloatingWindow *)window;
- (void)floatingWindowDidEndInteraction:(MSFloatingWindow *)window;
- (void)floatingWindowDidChangeMinimizedState:(MSFloatingWindow *)window;
@end

@interface MSFloatingWindow : UIView

@property (nonatomic, weak) id<MSFloatingWindowDelegate> delegate;
@property (nonatomic, copy, readonly) NSString *bundleID;
@property (nonatomic, copy, readonly) NSString *appName;
@property (nonatomic, assign, readonly) BOOL minimized;
@property (nonatomic, assign, readonly) BOOL expanded;

- (instancetype)initWithApp:(MSAppInfo *)app;

- (void)refreshSnapshot;
- (void)setMinimized:(BOOL)minimized animated:(BOOL)animated;
- (void)minimizeToEdge:(BOOL)left animated:(BOOL)animated;
- (void)presentWithAnimation;
- (void)dismissWithAnimation:(void (^)(void))completion;
- (void)applyWindowScale:(CGFloat)scale cornerRadius:(CGFloat)radius;

/// 屏幕坐标下窗口的可见区域（用于判断点击是否落在浮窗内）
- (CGRect)visibleFrameInScreen;

@end
