//
//  MSSnapshotProvider.h
//  应用快照：优先拿系统 AppSwitcher 快照，
//  拿不到就生成一张带星空质感的「马老师专属」封面。
//

#import <UIKit/UIKit.h>

@interface MSSnapshotProvider : NSObject

+ (UIImage *)snapshotForBundleID:(NSString *)bundleID size:(CGSize)size;
+ (void)invalidate:(NSString *)bundleID;

@end
