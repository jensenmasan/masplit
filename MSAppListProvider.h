//
//  MSAppListProvider.h
//  已安装应用清单 + 图标 + 启动
//

#import <UIKit/UIKit.h>

@interface MSAppInfo : NSObject
@property (nonatomic, copy) NSString *bundleID;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *version;
@property (nonatomic, strong) UIImage *icon;
@end

@interface MSAppListProvider : NSObject

/// 用户安装的应用（排除系统 App），按名称排序
+ (NSArray<MSAppInfo *> *)userApps;
/// 全部应用（含系统）
+ (NSArray<MSAppInfo *> *)allApps;
+ (MSAppInfo *)appForBundleID:(NSString *)bundleID;

+ (UIImage *)iconForBundleID:(NSString *)bundleID size:(CGFloat)size;
+ (BOOL)openApp:(NSString *)bundleID;

/// 当前前台 App 的 bundle id（取不到返回 nil）
+ (NSString *)frontmostBundleID;

@end
