#import "MSPrefsRootListController.h"
#import <notify.h>
#import <stdlib.h>

@implementation MSPrefsRootListController

- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
	}
	return _specifiers;
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	self.navigationItem.title = @"马老师分屏";
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
	[super setPreferenceValue:value specifier:specifier];
	notify_post("com.malaoshi.masplit/prefsChanged");
}

#pragma mark - 按钮

- (void)openSelector {
	notify_post("com.malaoshi.masplit.openSelector");
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"已发送"
	                                                               message:@"回到桌面，屏幕右侧会弹出应用选择器。"
	                                                        preferredStyle:UIAlertControllerStyleAlert];
	[alert addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
	[self presentViewController:alert animated:YES completion:nil];
}

- (void)restartSpringBoard {
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"重启桌面"
	                                                               message:@"重启后所有设置生效，确定？"
	                                                        preferredStyle:UIAlertControllerStyleAlert];
	[alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
	[alert addAction:[UIAlertAction actionWithTitle:@"重启" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
		system("killall -9 SpringBoard");
	}]];
	[self presentViewController:alert animated:YES completion:nil];
}

- (void)resetDefaults {
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSDictionary *domain = [defaults persistentDomainForName:@"com.malaoshi.masplit"];
	for (NSString *key in domain.allKeys) {
		[defaults removeObjectForKey:key];
	}
	[defaults synchronize];
	notify_post("com.malaoshi.masplit/prefsChanged");

	[self reloadSpecifiers];
}

@end
