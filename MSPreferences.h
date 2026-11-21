//
//  MSPreferences.h
//  马老师分屏 / MaSplit
//
//  统一设置读取层。设置面板写入 com.malaoshi.masplit，
//  SpringBoard 侧通过 Darwin 通知热加载，改完滑杆立刻生效。
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

extern NSString *const MSPrefDomain;

@interface MSPreferences : NSObject

+ (instancetype)shared;
- (void)reload;

@property (nonatomic, readonly) BOOL enabled;
@property (nonatomic, readonly) CGFloat windowScale;      // 0.30 ~ 1.00
@property (nonatomic, readonly) CGFloat cornerRadius;     // 0 ~ 40
@property (nonatomic, readonly) CGFloat topTriggerHeight; // 顶部边缘触发高度
@property (nonatomic, readonly) CGFloat bottomTriggerHeight;
@property (nonatomic, readonly) CGFloat swipeVelocity;    // 上滑速度阈值
@property (nonatomic, readonly) NSInteger maxWindows;
@property (nonatomic, readonly) CGFloat animationDuration;
@property (nonatomic, readonly) BOOL dismissOnBlankTap;
@property (nonatomic, readonly) BOOL externalKeyboardMode;
@property (nonatomic, readonly) BOOL experimentalMultitasking;
@property (nonatomic, copy, readonly) NSString *watermark;

@end
