//
//  CardIOPaymentViewController.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#import "CardIOPaymentViewControllerContinuation.h"
#import "CardIOAnalytics.h"
#import "CardIOViewController.h"
#import "CardIOContext.h"
#import "CardIODataEntryViewController.h"
#import "CardIODevice.h"
#import "CardIOLocalizer.h"
#import "CardIOMacros.h"
#import "CardIOStyles.h"
#import "CardIOView.h"
#import "CardIOUtilities.h"

#import "CardIOGPUGaussianBlurFilter.h"
#import "warp.h"

#import "CardIODetectionMode.h"

#if CARDIO_DEBUG
  #import "CardIOBundle.h"
#endif

#import "NSObject+CardioCategoryTest.h"

#if USE_CAMERA && SIMULATE_CAMERA
  #error USE_CAMERA and SIMULATE_CAMERA should not both evaluate to 1
#endif

@interface CardIOPaymentViewController ()
  @property (nonatomic, assign) BOOL hasAddedObservers;
@end

@implementation CardIOPaymentViewController

+ (CardIOPaymentViewController *)cardIOPaymentViewControllerForResponder:(UIResponder *)responder {
  while (responder && ![responder isKindOfClass:[CardIOPaymentViewController class]]) {
    responder = responder.nextResponder;
  }
  
  return (CardIOPaymentViewController *)responder;
}

- (id)initWithPaymentDelegate:(id<CardIOPaymentViewControllerDelegate>)aDelegate {
  return [self initWithPaymentDelegate:aDelegate scanningEnabled:YES];
}

- (id)initWithPaymentDelegate:(id<CardIOPaymentViewControllerDelegate>)aDelegate scanningEnabled:(BOOL)scanningEnabled {
#if CARDIO_DEBUG
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSError *error;
#if BALER_DEBUG
    NSAssert([[CardIOBundle sharedInstance] passesSelfTest:&error], error.description);
#endif
    NSAssert([CardIOLocalizer passesSelfTest:&error], error.description);
  });
#endif

  // test that categories are enabled
  @try {
    [NSObject testForObjCLinkerFlag];
  } @catch (NSException *exception) {
    [NSException raise:@"CardIO-IncompleteIntegration" format:@"Please add -ObjC to 'Other Linker Flags' in your project settings. (%@)", exception];
  }
  
  if(!aDelegate) {
    NSLog(@"Failed to initialize CardIOPaymentViewController -- no delegate provided");
    return nil;
  }

  CardIOContext *context = [[CardIOContext alloc] init];
  UIViewController *viewController = [[self class] viewControllerWithScanningEnabled:scanningEnabled withContext:context];

  if((self = [super initWithRootViewController:viewController])) {
    _context = context;
    _context.scannedImageDuration = (CGFloat) 0.1f;
    _currentViewControllerIsDataEntry = [viewController isKindOfClass:[CardIODataEntryViewController class]];
    _initialInterfaceOrientationForViewcontroller = [UIApplication sharedApplication].statusBarOrientation;
#if USE_CAMERA || SIMULATE_CAMERA
    if(!self.currentViewControllerIsDataEntry) {
      CardIOViewController *cameraVC = (CardIOViewController *)viewController;
      cameraVC.context = self.context;
    }
#endif

    _paymentDelegate = aDelegate;
    _shouldStoreStatusBarStyle = YES;
  }
  return self;
}

- (id)initWithRootViewController:(UIViewController *)rootViewController {
  [NSException raise:@"Wrong initializer" format:@"The designated initializer for CardIOPaymentViewController is -initWithPaymentDelegate:"];
  return nil;
}

- (void)viewDidLoad {
  [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
  UIApplication *theApp = [UIApplication sharedApplication];

  // Store the current state BEFORE calling super!
  if(self.shouldStoreStatusBarStyle) {
    self.originalStatusBarStyle = theApp.statusBarStyle;
    self.statusBarWasOriginallyHidden = theApp.statusBarHidden;
    self.shouldStoreStatusBarStyle = NO; // only store the very first time
  }
  
  self.navigationBar.barStyle = self.context.navigationBarStyle;
  if (iOS_7_PLUS) {
    self.navigationBar.barTintColor = self.context.navigationBarTintColor;
  }
  else {
    self.navigationBar.tintColor = self.context.navigationBarTintColor;
  }

  [super viewWillAppear:animated];

  if (self.modalPresentationStyle == UIModalPresentationFullScreen && !self.context.keepStatusBarStyle) {
    if (iOS_7_PLUS) {
      [theApp setStatusBarStyle:UIStatusBarStyleDefault animated:animated];
    }
    else {
      [theApp setStatusBarStyle:UIStatusBarStyleLightContent animated:animated];
    }
  }
  
  // Write console message for confused developers who have given us confusing directives
  if (self.suppressScanConfirmation && (self.collectExpiry || self.collectCVV || self.collectPostalCode)) {
    NSMutableString *collect = [NSMutableString string];
    if (self.collectExpiry) {
      [collect appendString:@"collectExpiry"];
    }
    if (self.collectCVV) {
      if ([collect length]) {
        [collect appendString:@"/"];
      }
      [collect appendString:@"collectCVV"];
    }
    if (self.collectPostalCode) {
      if ([collect length]) {
        [collect appendString:@"/"];
      }
      [collect appendString:@"collectPostalCode"];
    }
    NSLog(@"Warning: suppressScanConfirmation blocks %@.", collect);
  }
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  
  if (!self.hasAddedObservers) {
    self.hasAddedObservers = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceiveBackgroundingNotification:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceiveForegroundingNotification:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
  }
}

- (void)viewWillDisappear:(BOOL)animated {
  [super viewWillDisappear:animated];
  if (self.modalPresentationStyle == UIModalPresentationFullScreen) {
    [[UIApplication sharedApplication] setStatusBarStyle:self.originalStatusBarStyle animated:animated];
    [[UIApplication sharedApplication] setStatusBarHidden:self.statusBarWasOriginallyHidden withAnimation:UIStatusBarAnimationFade];
    if (iOS_7_PLUS) {
      [self setNeedsStatusBarAppearanceUpdate];
    }
  }
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
  if (self.currentViewControllerIsDataEntry) {
    return YES;
  }
  else {
    return [self isBeingPresentedModally] || (toInterfaceOrientation == UIInterfaceOrientationPortrait);
  }
}

- (BOOL)shouldAutorotate {
  if (self.currentViewControllerIsDataEntry) {
    return YES;
  }
  else {
    return [self isBeingPresentedModally];
  }
}

- (NSUInteger)supportedInterfaceOrientations {
  if (self.currentViewControllerIsDataEntry) {
    return [super supportedInterfaceOrientations];
  }
  else {
    if ([self isBeingPresentedModally]) {
      return UIInterfaceOrientationMaskAll;
    }
    else {
      return UIInterfaceOrientationMaskPortrait;
    }
  }
}

- (BOOL)isBeingPresentedModally {
  UIViewController *viewController = self;
  while (viewController) {
    if (viewController.modalPresentationStyle == UIModalPresentationFormSheet || viewController.modalPresentationStyle == UIModalPresentationPageSheet) {
      return YES;
    }
    else {
      if (viewController.presentingViewController) {
        viewController = viewController.presentingViewController;
      }
      else {
        viewController = viewController.parentViewController;
      }
    }
  }
  
  return NO;
}

- (UIInterfaceOrientationMask)supportedOverlayOrientationsMask {
  if (self.context.allowFreelyRotatingCardGuide) {
    return UIInterfaceOrientationMaskAll;
  }
  else {
    UIInterfaceOrientationMask pListMask = UIInterfaceOrientationMaskAll;
    
    // As far as I can determine, when we call [super supportedInterfaceOrientations],
    // iOS should already be intersecting that result either with application:supportedInterfaceOrientationsForWindow:
    // or with the plist values for UISupportedInterfaceOrientations.
    // I'm reasonably sure that I extensively tested and confirmed all that a year or two ago.
    // However, today that's definitely not happening. So let's do the work ourselves, just to be safe!
    // [- Dave Goldman, 7 Jun 2015]
    
    UIApplication *application = [UIApplication sharedApplication];
    if ([application.delegate respondsToSelector:@selector(application:supportedInterfaceOrientationsForWindow:)]) {
      pListMask = [application.delegate application:application supportedInterfaceOrientationsForWindow:self.view.window];
    }
    else {
      static UIInterfaceOrientationMask cachedPListMask = UIInterfaceOrientationMaskAll;
      static dispatch_once_t onceToken;
      dispatch_once(&onceToken, ^{
        NSArray *supportedOrientations = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"UISupportedInterfaceOrientations"];
        if ([supportedOrientations count]) {
          cachedPListMask = 0;
          for (NSString *orientationString in supportedOrientations) {
            if ([orientationString isEqualToString:@"UIInterfaceOrientationPortrait"]) {
              cachedPListMask |= UIInterfaceOrientationMaskPortrait;
            }
            else if ([orientationString isEqualToString:@"UIInterfaceOrientationLandscapeLeft"]) {
              cachedPListMask |= UIInterfaceOrientationMaskLandscapeLeft;
            }
            else if ([orientationString isEqualToString:@"UIInterfaceOrientationLandscapeRight"]) {
              cachedPListMask |= UIInterfaceOrientationMaskLandscapeRight;
            }
            else if ([orientationString isEqualToString:@"UIInterfaceOrientationPortraitUpsideDown"]) {
              cachedPListMask |= UIInterfaceOrientationMaskPortraitUpsideDown;
            }
          }
        }
      });
      
      pListMask = cachedPListMask;
    }
    
    return [super supportedInterfaceOrientations] & pListMask;
  }
}

// Allow keyboad dismissal in UIModalPresentationFormSheet or UIModalPresentationPageSheet.
// Keeps the keyboard from staying popped open when going from data entry back to camera view.
- (BOOL)disablesAutomaticKeyboardDismissal {
  return NO;
}

+ (UIViewController *)viewControllerWithScanningEnabled:(BOOL)scanningEnabled withContext:(CardIOContext *)aContext {
  id returnVC = nil;
#if USE_CAMERA || SIMULATE_CAMERA
  if([CardIOUtilities canReadCardWithCamera] && scanningEnabled) {
    returnVC = [[CardIOViewController alloc] init];
  }
#endif
  if(!returnVC) {
    returnVC = [[CardIODataEntryViewController alloc] initWithContext:aContext withStatusBarHidden:[UIApplication sharedApplication].statusBarHidden];
    [returnVC setManualEntry:YES];
  }

  return returnVC;
}

- (void)didReceiveBackgroundingNotification:(NSNotification *)notification {
  if (!self.context.disableBlurWhenBackgrounding) {
    self.obfuscatingView = [CardIOUtilities blurredScreenImageView];
    [[UIApplication sharedApplication].keyWindow addSubview:self.obfuscatingView];
  }
}

- (void)didReceiveForegroundingNotification:(NSNotification *)notification {
  if (!self.context.disableBlurWhenBackgrounding) {
    [UIView animateWithDuration:0.5
                     animations:
                     ^
                     {
                       self.obfuscatingView.alpha = 0;
                     }
                     completion:
                     ^(BOOL finished)
                     {
                       [self.obfuscatingView removeFromSuperview];
                       self.obfuscatingView = nil;
                     }
     ];
  }
}

#pragma mark - Description method

#define DESCRIBE_BOOL(property) (self.property ? "; " #property : "")

- (NSString *)description {
  return [NSString stringWithFormat:@"{delegate: %@; %s%s%s%s%s%s%s%s%s%s%s%s%s%s}"
          ,self.paymentDelegate
          ,DESCRIBE_BOOL(keepStatusBarStyle)
          ,DESCRIBE_BOOL(disableBlurWhenBackgrounding)
          ,DESCRIBE_BOOL(suppressScanConfirmation)
          ,DESCRIBE_BOOL(suppressScannedCardImage)
          ,DESCRIBE_BOOL(maskManualEntryDigits)
          ,DESCRIBE_BOOL(collectExpiry)
          ,DESCRIBE_BOOL(collectCVV)
          ,DESCRIBE_BOOL(collectPostalCode)
          ,DESCRIBE_BOOL(scanExpiry)
          ,DESCRIBE_BOOL(useCardIOLogo)
          ,DESCRIBE_BOOL(disableManualEntryButtons)
          ,DESCRIBE_BOOL(allowFreelyRotatingCardGuide)
          ,DESCRIBE_BOOL(hideCardIOLogo)
          ,(self.detectionMode == CardIODetectionModeCardImageAndNumber
            ? "DetectNumber"
            : (self.detectionMode == CardIODetectionModeCardImageOnly
               ? "DetectImage"
               : "DetectAuto"))
          ];
}

#pragma mark - Manual property implementations (passthrough to context)

#define CONTEXT_PASSTHROUGH_GETTER(t, prop) \
- (t)prop { \
  return self.context.prop; \
}

#define CONTEXT_PASSTHROUGH_SETTER(t, prop_lc, prop_uc) \
- (void)set##prop_uc:(t)prop_lc { \
  self.context.prop_lc = prop_lc; \
}

#define CONTEXT_PASSTHROUGH_READWRITE(t, prop_lc, prop_uc) \
CONTEXT_PASSTHROUGH_GETTER(t, prop_lc) \
CONTEXT_PASSTHROUGH_SETTER(t, prop_lc, prop_uc)


CONTEXT_PASSTHROUGH_READWRITE(NSString *, languageOrLocale, LanguageOrLocale)
CONTEXT_PASSTHROUGH_READWRITE(BOOL, keepStatusBarStyle, KeepStatusBarStyle)
CONTEXT_PASSTHROUGH_READWRITE(UIBarStyle, navigationBarStyle, NavigationBarStyle)
CONTEXT_PASSTHROUGH_READWRITE(UIColor *, navigationBarTintColor, NavigationBarTintColor)
CONTEXT_PASSTHROUGH_READWRITE(BOOL, disableBlurWhenBackgrounding, DisableBlurWhenBackgrounding)
CONTEXT_PASSTHROUGH_READWRITE(BOOL, collectCVV, CollectCVV)
CONTEXT_PASSTHROUGH_READWRITE(BOOL, collectPostalCode, CollectPostalCode)
CONTEXT_PASSTHROUGH_READWRITE(BOOL, collectExpiry, CollectExpiry)
CONTEXT_PASSTHROUGH_READWRITE(BOOL, scanExpiry, ScanExpiry)
CONTEXT_PASSTHROUGH_READWRITE(BOOL, useCardIOLogo, UseCardIOLogo)
CONTEXT_PASSTHROUGH_READWRITE(BOOL, disableManualEntryButtons, DisableManualEntryButtons)
CONTEXT_PASSTHROUGH_READWRITE(UIColor *, guideColor, GuideColor)
CONTEXT_PASSTHROUGH_READWRITE(BOOL, suppressScanConfirmation, SuppressScanConfirmation)
CONTEXT_PASSTHROUGH_READWRITE(BOOL, suppressScannedCardImage, SuppressScannedCardImage)
CONTEXT_PASSTHROUGH_READWRITE(BOOL, maskManualEntryDigits, MaskManualEntryDigits)
CONTEXT_PASSTHROUGH_READWRITE(CGFloat, scannedImageDuration, ScannedImageDuration)
CONTEXT_PASSTHROUGH_READWRITE(BOOL, allowFreelyRotatingCardGuide, AllowFreelyRotatingCardGuide)

CONTEXT_PASSTHROUGH_GETTER(CardIOAnalytics *, scanReport)

CONTEXT_PASSTHROUGH_READWRITE(NSString *, scanInstructions, ScanInstructions)
CONTEXT_PASSTHROUGH_READWRITE(BOOL, hideCardIOLogo, HideCardIOLogo)
CONTEXT_PASSTHROUGH_READWRITE(UIView *, scanOverlayView, ScanOverlayView)

CONTEXT_PASSTHROUGH_READWRITE(CardIODetectionMode, detectionMode, DetectionMode)

#if CARDIO_DEBUG
CONTEXT_PASSTHROUGH_READWRITE(BOOL, doABTesting, DoABTesting)
#endif

@end
