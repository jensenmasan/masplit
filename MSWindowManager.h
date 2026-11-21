//
//  MSWindowManager.h
//  浮窗调度中心：托管 UIWindow、边缘手势唤出、数量上限、状态持久化
//

#import <UIKit/UIKit.h>
#import "MSFloatingWindow.h"

@interface MSWindowManager : NSObject <MSFloatingWindowDelegate>

+ (instancetype)shared;

@property (nonatomic, readonly) UIWindow *hostWindow;
@property (nonatomic, readonly) NSArray<MSFloatingWindow *> *windows;
@property (nonatomic, readonly) BOOL hasVisibleWindows;

/// SpringBoard 桌面视图出现后挂载手势
- (void)attachToHomeScreen:(UIView *)homeView;

- (MSFloatingWindow *)showAppWithBundleID:(NSString *)bundleID;
- (void)showRingSelector;
- (void)toggleCollapse;
- (void)minimizeAll;
- (void)restoreAll;
- (void)closeAll;
- (void)applyPreferences;

@end
