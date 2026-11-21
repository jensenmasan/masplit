//
//  MSRingSelector.h
//  环形应用选择器：图标按黄金角螺旋散开，点一个就开浮窗
//

#import <UIKit/UIKit.h>
#import "MSAppListProvider.h"

@interface MSRingSelector : UIView

+ (void)presentFromView:(UIView *)hostView
                   apps:(NSArray<MSAppInfo *> *)apps
                 onPick:(void (^)(MSAppInfo *app))onPick;

@end
