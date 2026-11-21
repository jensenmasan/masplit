//
//  MSMultiTasking.h
//  实验性真·双 App 同屏：在 iPhone 上强制打开 iPad 的 Medusa 多窗口能力。
//  只在设置里手动开启后生效，任何一步失败都静默跳过，不影响主功能。
//

#import <Foundation/Foundation.h>

@interface MSMultiTasking : NSObject

+ (instancetype)shared;
- (void)activateIfEnabled;
- (BOOL)isActive;

@end
