//
//  CardIOContext.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#import "CardIOContext.h"
#import "CardIOAnalytics.h"
#import "CardIOConfig.h"

@implementation CardIOContext

- (id)init {
  self = [super init];
  if(self) {
    _config = [[CardIOConfig alloc] init];
    _collectCVV = YES;
    _collectExpiry = YES;
  }
  return self;
}

#define CONFIG_PASSTHROUGH_GETTER(t, prop) \
- (t)prop { \
return self.config.prop; \
}

#define CONFIG_PASSTHROUGH_SETTER(t, prop_lc, prop_uc) \
- (void)set##prop_uc:(t)prop_lc { \
self.config.prop_lc = prop_lc; \
}

#define CONFIG_PASSTHROUGH_READWRITE(t, prop_lc, prop_uc) \
CONFIG_PASSTHROUGH_GETTER(t, prop_lc) \
CONFIG_PASSTHROUGH_SETTER(t, prop_lc, prop_uc)

CONFIG_PASSTHROUGH_READWRITE(CardIOAnalytics *, scanReport, ScanReport)
CONFIG_PASSTHROUGH_READWRITE(NSString *, languageOrLocale, LanguageOrLocale)
CONFIG_PASSTHROUGH_READWRITE(BOOL, useCardIOLogo, UseCardIOLogo)
CONFIG_PASSTHROUGH_READWRITE(UIColor *, guideColor, GuideColor)
CONFIG_PASSTHROUGH_READWRITE(CGFloat, scannedImageDuration, ScannedImageDuration)
CONFIG_PASSTHROUGH_READWRITE(BOOL, allowFreelyRotatingCardGuide, AllowFreelyRotatingCardGuide)

CONFIG_PASSTHROUGH_READWRITE(NSString *, scanInstructions, ScanInstructions)
CONFIG_PASSTHROUGH_READWRITE(BOOL, hideCardIOLogo, HideCardIOLogo)
CONFIG_PASSTHROUGH_READWRITE(UIView *, scanOverlayView, ScanOverlayView)

CONFIG_PASSTHROUGH_READWRITE(CardIODetectionMode, detectionMode, DetectionMode)

CONFIG_PASSTHROUGH_READWRITE(BOOL, scanExpiry, ScanExpiry)

@end
