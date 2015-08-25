//
//  CardIOView.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#if USE_CAMERA && SIMULATE_CAMERA
#error USE_CAMERA and SIMULATE_CAMERA are mutually exclusive!
#endif

#if USE_CAMERA || SIMULATE_CAMERA

#import "CardIOView.h"
#import "CardIOViewContinuation.h"
#import "CardIOUtilities.h"
#import "CardIOCameraView.h"
#import "CardIOCardOverlay.h"
#import "CardIOCardScanner.h"
#import "CardIOConfig.h"
#import "CardIOCreditCardInfo.h"
#import "CardIODevice.h"
#import "CardIOCGGeometry.h"
#import "CardIOLocalizer.h"
#import "CardIOMacros.h"
#import "CardIOOrientation.h"
#import "CardIOPaymentViewControllerContinuation.h"
#import "CardIOReadCardInfo.h"
#import "CardIOTransitionView.h"
#import "CardIOVideoFrame.h"
#import "CardIOVideoStreamDelegate.h"
#import "CardIOViewDelegate.h"
#import "NSObject+CardioCategoryTest.h"
#import "CardIODetectionMode.h"

NSString * const CardIOScanningOrientationDidChangeNotification = @"CardIOScanningOrientationDidChangeNotification";
NSString * const CardIOCurrentScanningOrientation = @"CardIOCurrentScanningOrientation";
NSString * const CardIOScanningOrientationAnimationDuration = @"CardIOScanningOrientationAnimationDuration";

@interface CardIOView () <CardIOVideoStreamDelegate>

@property(nonatomic, strong, readwrite) CardIOConfig *config;
@property(nonatomic, strong, readwrite) CardIOCameraView *cameraView;
@property(nonatomic, strong, readwrite) CardIOReadCardInfo *readCardInfo;
@property(nonatomic, strong, readwrite) UIImage *cardImage;

// These two properties were declared readonly in CardIOViewContinuation.h
@property(nonatomic, strong, readwrite) CardIOCardScanner *scanner;
@property(nonatomic, strong, readwrite) CardIOTransitionView *transitionView;

@property(nonatomic, assign, readwrite) BOOL scanHasBeenStarted;

@end


@implementation CardIOView

#pragma mark - Initialization and layout

- (id)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    [self commonInit];
    self.backgroundColor = [UIColor clearColor];
  }
  return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
  self = [super initWithCoder:aDecoder];
  if (self) {
    [self commonInit];
  }
  return self;
}

- (void)commonInit {
  // test that categories are enabled
  @try {
    [NSObject testForObjCLinkerFlag];
  } @catch (NSException *exception) {
    [NSException raise:@"CardIO-IncompleteIntegration" format:@"Please add -ObjC to 'Other Linker Flags' in your project settings. (%@)", exception];
  }

  _config = [[CardIOConfig alloc] init];
  _config.scannedImageDuration = 1.0;
}

- (CGSize)sizeThatFits:(CGSize)size {
  return [self.cameraView sizeThatFits:size];
}

- (void)layoutSubviews {
  [super layoutSubviews];
  
  self.cameraView.frame = self.bounds;
  [self.cameraView sizeToFit];
  self.cameraView.center = CenterOfRect(CGRectZeroWithSize(self.bounds.size));

  [self.cameraView layoutIfNeeded];
}

- (void)setHidden:(BOOL)hidden {
  if (hidden != self.hidden) {
    if (hidden) {
      [self implicitStop];
      [super setHidden:hidden];
    }
    else {
      [super setHidden:hidden];
      [self implicitStart];
    }
  }
}

- (void)willMoveToSuperview:(UIView *)newSuperview {
  if (!newSuperview) {
    [self implicitStop];
  }
  [super willMoveToSuperview:newSuperview];
}

- (void)didMoveToSuperview {
  [super didMoveToSuperview];
  if (self.superview) {
    [self implicitStart];
  }
}

- (void)willMoveToWindow:(UIWindow *)newWindow {
  if (!newWindow) {
    [self implicitStop];
  }
  [super willMoveToWindow:newWindow];
}

- (void)didMoveToWindow {
  [super didMoveToWindow];
  if (self.window) {
    [self implicitStart];
  }
}

- (void)implicitStart {
  if (!self.scanHasBeenStarted && self.window && self.superview && !self.hidden) {
    if (![CardIOUtilities canReadCardWithCamera]) {
      if (self.delegate) {
        [self.delegate cardIOView:self didScanCard:nil];
      }
      return;
    }
    
    self.scanHasBeenStarted = YES;
    
    CardIOLog(@"Creating cameraView");
    self.cameraView = [[CardIOCameraView alloc] initWithFrame:CGRectZeroWithSize(self.frame.size)
                                                     delegate:self
                                                       config:self.config];
    [self addSubview:self.cameraView];
    [self.cameraView willAppear];
    
    [self performSelector:@selector(startSession) withObject:nil afterDelay:0.0f];
  }
}

- (void)implicitStop {
  if (self.scanHasBeenStarted) {
    self.scanHasBeenStarted = NO;
    [self stopSession];
    [self.cameraView willDisappear];
    [self.cameraView removeFromSuperview];
    self.cameraView = nil;
  }
}

#pragma mark - Property accessors (passthroughs to CardIOCameraView)

- (CGRect)cameraPreviewFrame {
  return [self.cameraView cameraPreviewFrame];
}

- (CardIOCardScanner *)scanner {
  return self.cameraView.scanner;
}

#pragma mark - Video session start/stop

- (void)startSession {
  if (self.cameraView) {
    CardIOLog(@"Starting CameraViewController session");
    
    [self.cameraView startVideoStreamSession];
    
    [self.config.scanReport reportEventWithLabel:@"scan_start" withScanner:self.cameraView.scanner];
  }
}

- (void)stopSession {
  if (self.cameraView) {
    CardIOLog(@"Stopping CameraViewController session");
    [self.cameraView stopVideoStreamSession];
  }
}

#pragma mark - CardIOVideoStreamDelegate method and related methods

- (void)videoStream:(CardIOVideoStream *)stream didProcessFrame:(CardIOVideoFrame *)processedFrame {
  [self didDetectCard:processedFrame];
  
  if(processedFrame.scanner.complete) {
    [self didScanCard:processedFrame];
  }
}

- (void)didDetectCard:(CardIOVideoFrame *)processedFrame {
  if(processedFrame.foundAllEdges && processedFrame.focusOk) {
    if(self.detectionMode == CardIODetectionModeCardImageOnly) {
      [self stopSession];
      [self vibrate];
      
      CardIOCreditCardInfo *cardInfo = [[CardIOCreditCardInfo alloc] init];
      self.cardImage = [processedFrame imageWithGrayscale:NO];
      cardInfo.cardImage = self.cardImage;
      
      [self.config.scanReport reportEventWithLabel:@"scan_detection" withScanner:processedFrame.scanner];
      
      [self successfulScan:cardInfo];
    }
  }
}

- (void)didScanCard:(CardIOVideoFrame *)processedFrame {
  [self stopSession];
  [self vibrate];

  self.readCardInfo = processedFrame.scanner.cardInfo;
  CardIOCreditCardInfo *cardInfo = [[CardIOCreditCardInfo alloc] init];
  cardInfo.cardNumber = self.readCardInfo.numbers;
  cardInfo.expiryMonth = self.readCardInfo.expiryMonth;
  cardInfo.expiryYear = self.readCardInfo.expiryYear;
  cardInfo.scanned = YES;

  self.cardImage = [processedFrame imageWithGrayscale:NO];
  cardInfo.cardImage = self.cardImage;
  
  [self.config.scanReport reportEventWithLabel:@"scan_success" withScanner:processedFrame.scanner];
  
  [self successfulScan:cardInfo];
}

- (void)successfulScan:(CardIOCreditCardInfo *)cardInfo {
  // Even if not showing a transitionView (because self.scannedImageDuration == 0), we still create it.
  // This is because the CardIODataEntryView gets its cardImage from the transitionView. (A bit of a kludge, yes.)
  UIImage *annotatedImage = [CardIOCardOverlay cardImage:self.cardImage withDisplayInfo:self.readCardInfo annotated:YES];
  CGRect cameraPreviewFrame = [self cameraPreviewFrame];
  
  CGAffineTransform r = CGAffineTransformIdentity;
  CardIOPaymentViewController *vc = [CardIOPaymentViewController cardIOPaymentViewControllerForResponder:self];
  if (vc != nil &&
      [UIDevice currentDevice].orientation != UIDeviceOrientationPortrait &&
      vc.modalPresentationStyle == UIModalPresentationFullScreen) {
    UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;
    if (deviceOrientation == UIDeviceOrientationFaceUp || deviceOrientation == UIDeviceOrientationFaceDown) {
      deviceOrientation = (UIDeviceOrientation) vc.initialInterfaceOrientationForViewcontroller;
    }
    InterfaceToDeviceOrientationDelta delta = orientationDelta(UIInterfaceOrientationPortrait, deviceOrientation);
    CGFloat rotation = -rotationForOrientationDelta(delta); // undo the orientation delta
    r = CGAffineTransformMakeRotation(rotation);
  }
  
  self.transitionView = [[CardIOTransitionView alloc] initWithFrame:cameraPreviewFrame cardImage:annotatedImage transform:r];

  if (self.scannedImageDuration > 0.0) {
    [self addSubview:self.transitionView];
    
    [self.transitionView animateWithCompletion:^{
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.scannedImageDuration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
        if (self.delegate) {
          [self.delegate cardIOView:self didScanCard:cardInfo];
        }
        [self.transitionView removeFromSuperview];
      });
    }];
  }
  else {
    if (self.delegate) {
      self.transitionView.hidden = YES;
      [self.delegate cardIOView:self didScanCard:cardInfo];
    }
  }
}

- (void)vibrate {
  AudioServicesPlayAlertSound(kSystemSoundID_Vibrate);
}

#pragma mark - Description method

#define DESCRIBE_BOOL(property) (self.property ? "; " #property : "")

- (NSString *)description {
  return [NSString stringWithFormat:@"{delegate: %@; %s%s%s%s%s}"
          ,self.delegate
          ,DESCRIBE_BOOL(useCardIOLogo)
          ,DESCRIBE_BOOL(hideCardIOLogo)
          ,DESCRIBE_BOOL(allowFreelyRotatingCardGuide)
          ,DESCRIBE_BOOL(scanExpiry)
          ,(self.detectionMode == CardIODetectionModeCardImageAndNumber
            ? "DetectNumber"
            : (self.detectionMode == CardIODetectionModeCardImageOnly
               ? "DetectImage"
               : "DetectAuto"))
          ];
}

#pragma mark - Manual property implementations (passthrough to config)

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

CONFIG_PASSTHROUGH_READWRITE(NSString *, languageOrLocale, LanguageOrLocale)
CONFIG_PASSTHROUGH_READWRITE(BOOL, useCardIOLogo, UseCardIOLogo)
CONFIG_PASSTHROUGH_READWRITE(BOOL, hideCardIOLogo, HideCardIOLogo)
CONFIG_PASSTHROUGH_READWRITE(UIColor *, guideColor, GuideColor)
CONFIG_PASSTHROUGH_READWRITE(CGFloat, scannedImageDuration, ScannedImageDuration)
CONFIG_PASSTHROUGH_READWRITE(BOOL, allowFreelyRotatingCardGuide, AllowFreelyRotatingCardGuide)

CONFIG_PASSTHROUGH_READWRITE(NSString *, scanInstructions, ScanInstructions)
CONFIG_PASSTHROUGH_READWRITE(BOOL, scanExpiry, ScanExpiry)
CONFIG_PASSTHROUGH_READWRITE(UIView *, scanOverlayView, ScanOverlayView)

CONFIG_PASSTHROUGH_READWRITE(CardIODetectionMode, detectionMode, DetectionMode)

@end

#else // USE_CAMERA || SIMULATE_CAMERA

#import "CardIOView.h"

NSString * const CardIOScanningOrientationDidChangeNotification = @"CardIOScanningOrientationDidChangeNotification";
NSString * const CardIOCurrentScanningOrientation = @"CardIOCurrentScanningOrientation";
NSString * const CardIOScanningOrientationAnimationDuration = @"CardIOScanningOrientationAnimationDuration";

@implementation CardIOView

@end

#endif  // USE_CAMERA || SIMULATE_CAMERA