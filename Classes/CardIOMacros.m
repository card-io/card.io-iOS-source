//
//  CardIOMacros.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#import "CardIOMacros.h"

@implementation CardIOMacros

+ (id)localSettingForKey:(NSString *)key defaultValue:(NSString *)defaultValue productionValue:(NSString *)productionValue {
#if CARDIO_DEBUG
#pragma unused(productionValue)
  NSString *localSettingsPath = [[NSBundle bundleForClass:self] pathForResource:@"local_settings" ofType:@"plist"];
  
  NSDictionary *settingsDictionary = [NSDictionary dictionaryWithContentsOfFile:localSettingsPath];
  id val = settingsDictionary[key];
  
  if(!val) {
    val = defaultValue;
  }
  
  return val;
#else
#pragma unused(defaultValue)
#pragma unused(key)
  return productionValue;
#endif
}

// Via recommended detection logic in the iOS7 prerelease docs:
// https://developer.apple.com/library/prerelease/ios/documentation/UserExperience/Conceptual/TransitionGuide/SupportingEarlieriOS.html

+ (NSUInteger)deviceSystemMajorVersion {
  static NSUInteger _deviceSystemMajorVersion = -1;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    _deviceSystemMajorVersion = [[[[[UIDevice currentDevice] systemVersion] componentsSeparatedByString:@"."] objectAtIndex:0] intValue];
  });
  return _deviceSystemMajorVersion;
}

+ (BOOL)appHasViewControllerBasedStatusBar {
  static BOOL _appHasViewControllerBasedStatusBar = NO;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    _appHasViewControllerBasedStatusBar = !iOS_7_PLUS || [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"UIViewControllerBasedStatusBarAppearance"] boolValue];
  });
  return _appHasViewControllerBasedStatusBar;
}

@end
