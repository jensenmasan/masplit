//
//  PSListController.h
//  最小私有头声明 —— 不依赖私有 SDK，运行时由 Preferences.framework 提供实现
//  链接时使用 -undefined dynamic_lookup，符号在注入 Preferences 进程时解析
//
#import <UIKit/UIKit.h>
#import <Preferences/PSSpecifier.h>

@interface PSListController : UIViewController {
@protected
	NSArray *_specifiers;
}
- (NSArray *)specifiers;
- (NSArray *)loadSpecifiersFromPlistName:(NSString *)name target:(id)target;
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier;
- (id)readPreferenceValue:(PSSpecifier *)specifier;
- (void)reloadSpecifiers;
@end

@interface PSViewController : UIViewController
@end
