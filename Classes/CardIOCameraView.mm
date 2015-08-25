//
//  CardIOCameraView.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#if USE_CAMERA || SIMULATE_CAMERA

#import "CardIOAnimation.h"
#import "CardIOBundle.h"
#import "CardIOCameraView.h"
#import "CardIOCardScanner.h"
#import "CardIOCGGeometry.h"
#import "CardIOConfig.h"
#import "CardIOMacros.h"
#import "CardIOOrientation.h"
#import "CardIOPaymentViewControllerContinuation.h"
#import "CardIOReadCardInfo.h"
#import "CardIOResource.h"
#import "CardIOShutterView.h"
#import "CardIOStyles.h"
#import "CardIOVideoFrame.h"
#import "CardIOVideoStream.h"
#import "CardIOLocalizer.h"

#define kLogoAlpha 0.6f
#define kGuideLayerTextAlpha 0.6f

#define kGuideLayerTextColor [UIColor colorWithWhite:1.0f alpha:kGuideLayerTextAlpha]
#define kLabelVisibilityAnimationDuration 0.3f
#define kRotationLabelShowDelay (kRotationAnimationDuration + 0.1f)

#define kStandardInstructionsFontSize 18.0f
#define kMinimumInstructionsFontSize (kStandardInstructionsFontSize / 2)

@interface CardIOCameraView ()

@property(nonatomic, strong, readonly) CardIOGuideLayer *cardGuide;
@property(nonatomic, strong, readwrite) UILabel *guideLayerLabel;
@property(nonatomic, strong, readwrite) CardIOShutterView *shutter;
@property(nonatomic, strong, readwrite) CardIOVideoStream *videoStream;
@property(nonatomic, strong, readwrite) UIButton *lightButton;
@property(nonatomic, strong, readwrite) UIImageView *logoView;
@property(nonatomic, assign, readwrite) UIDeviceOrientation deviceOrientation;
@property(nonatomic, assign, readwrite) BOOL rotatingInterface;
@property(nonatomic, assign, readwrite) BOOL videoStreamSessionWasRunningBeforeRotation;
@property(nonatomic, strong, readwrite) CardIOConfig *config;
@property(nonatomic, assign, readwrite) BOOL hasLaidoutCameraButtons;

#if CARDIO_DEBUG
@property(nonatomic, strong, readwrite) UITextField *debugTextField;
#endif

@end

#pragma mark -

@implementation CardIOCameraView

+ (CGRect)previewRectWithinSize:(CGSize)size landscape:(BOOL)landscape {
  CGSize contents;
  if(landscape) {
    contents = CGSizeMake(kLandscapeSampleWidth, kLandscapeSampleHeight);
  } else {
    contents = CGSizeMake(kPortraitSampleWidth, kPortraitSampleHeight);
  }
  CGRect contentsRect = aspectFit(contents, size);
  return CGRectFlooredToNearestPixel(contentsRect);
}

- (id)initWithFrame:(CGRect)frame {
  [NSException raise:@"Wrong initializer" format:@"CardIOCameraView's designated initializer is initWithFrame:delegate:config:"];
  return nil;
}

- (id)initWithFrame:(CGRect)frame delegate:(id<CardIOVideoStreamDelegate>)delegate config:(CardIOConfig *)config {
  self = [super initWithFrame:frame];
  if(self) {
    _deviceOrientation = UIDeviceOrientationUnknown;

    self.autoresizingMask = UIViewAutoresizingNone;
    self.backgroundColor = [UIColor clearColor];
    self.clipsToBounds = YES;

    _delegate = delegate;
    _config = config;

    _videoStream = [[CardIOVideoStream alloc] init];
    self.videoStream.config = config;
    self.videoStream.delegate = self;
    self.videoStream.previewLayer.needsDisplayOnBoundsChange = YES;
    self.videoStream.previewLayer.contentsGravity = kCAGravityResizeAspect;
#if USE_CAMERA
    self.videoStream.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
#endif
    
    // These settings are helpful when debugging rotation/bounds/rendering issues:
    // self.videoStream.previewLayer.backgroundColor = [UIColor yellowColor].CGColor;

    // Preview of the camera image
    [self.layer addSublayer:self.videoStream.previewLayer];

    // Guide layer shows card guide edges and other progress feedback directly related to the camera contents
    _cardGuide = [[CardIOGuideLayer alloc] initWithDelegate:self];
    self.cardGuide.contentsGravity = kCAGravityResizeAspect;
    self.cardGuide.needsDisplayOnBoundsChange = YES;
    self.cardGuide.animationDuration = kRotationAnimationDuration;
    self.cardGuide.deviceOrientation = self.deviceOrientation;
    self.cardGuide.guideColor = config.guideColor;
    [self.layer addSublayer:self.cardGuide];

    NSString *scanInstructions = nil;
    scanInstructions = config.scanInstructions;
    if(!scanInstructions) {
      scanInstructions = CardIOLocalizedString(@"scan_guide", config.languageOrLocale); // Hold credit card here.\nIt will scan automatically.
    }
    _guideLayerLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.guideLayerLabel.text = scanInstructions;
    self.guideLayerLabel.textAlignment = NSTextAlignmentCenter;
    self.guideLayerLabel.backgroundColor = [UIColor clearColor];
    self.guideLayerLabel.textColor = kGuideLayerTextColor;
    self.guideLayerLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:kStandardInstructionsFontSize];
    self.guideLayerLabel.numberOfLines = 0;
    [self addSubview:self.guideLayerLabel];

    // Shutter view for shutter-open animation
    _shutter = [[CardIOShutterView alloc] initWithFrame:CGRectZero];
    [self.shutter setOpen:NO animated:NO duration:0];
    [self addSubview:self.shutter];

    // Tap-to-refocus support
    if([self.videoStream hasAutofocus]) {
      UITapGestureRecognizer *touch = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(refocus)];
      [self addGestureRecognizer:touch];
    }

    // Set up the light button
    if([self.videoStream hasTorch] && ![self.videoStream canSetTorchLevel]) {
      _lightButton = [CardIOResource lightButton];
      self.lightButton.accessibilityLabel = CardIOLocalizedString(@"activate_flash", config.languageOrLocale); // Turn flash on.
      [self.lightButton addTarget:self action:@selector(toggleTorch:) forControlEvents:UIControlEventTouchUpInside];
      [self addSubview:self.lightButton];
    }

    // Set up logo
    NSString *logoImageName = config.useCardIOLogo ? @"card_io_logo.png" : @"paypal_logo.png";
    _logoView = [[UIImageView alloc] initWithImage:[[CardIOBundle sharedInstance] imageNamed:logoImageName]];
    self.logoView.alpha = kLogoAlpha;
    self.logoView.isAccessibilityElement = YES;
    self.logoView.accessibilityLabel = (config.useCardIOLogo
                                        ? CardIOLocalizedString(@"card_io_logo",config.languageOrLocale) // card.io
                                        : CardIOLocalizedString(@"paypal_logo", config.languageOrLocale)); // PayPal
    [self addSubview:self.logoView];
    
#if CARDIO_DEBUG
// This can be useful for debugging dynamic changes, such as brightness, torch setting, etc.
//    _debugTextField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 300, 20)];
//    _debugTextField.textColor = [UIColor greenColor];
//    _debugTextField.font = [UIFont fontWithName:@"Helvetica-Bold" size:14.0f];
//    _debugTextField.backgroundColor = [UIColor clearColor];
//    [self addSubview:_debugTextField];
#endif

    if(config.hideCardIOLogo) {
      [self.logoView removeFromSuperview]; // merely setting .hidden requires that we maintain this during rotations, etc. :(
    }

    UIView *scanOverlayView = config.scanOverlayView;
    if(scanOverlayView) {
      [self addSubview:scanOverlayView];
    }
  }
  return self;
}

- (void)startVideoStreamSession {
  [self.videoStream startSession];

  // If we don't do this, then when the torch was on, and the card read failed,
  // it still shows as on when this view is re-displayed, even though the ending
  // of the session turned it off.
  [self updateLightButtonState];
}

- (void)stopVideoStreamSession {
  [self.videoStream stopSession];
  [self.shutter setOpen:NO animated:NO duration:0.0f];
}

- (void)refocus {
  [self.videoStream refocus];
}

- (CardIOCardScanner *)scanner {
  return self.videoStream.scanner;
}

- (void)setSuppressFauxCardLayer:(BOOL)suppressFauxCardLayer {
  if(suppressFauxCardLayer) {
    self.cardGuide.fauxCardLayer.hidden = YES;
  }
  _suppressFauxCardLayer = suppressFauxCardLayer;
}


- (CGRect)guideFrame {
  return [self.cardGuide guideFrame];
}

- (CGRect)cameraPreviewFrame {
  CGRect cameraPreviewFrame = [[self class] previewRectWithinSize:self.bounds.size
                                                        landscape:UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)];
  return cameraPreviewFrame;
}

- (void)layoutSubviews {
  [self updateCameraOrientation];

  CGRect cameraPreviewFrame = [self cameraPreviewFrame];

  SuppressCAAnimation(^{
    if (!CGRectEqualToRect(self.videoStream.previewLayer.frame, cameraPreviewFrame)) {
      self.videoStream.previewLayer.frame = cameraPreviewFrame;
    }
    self.shutter.frame = cameraPreviewFrame;

    [self layoutCameraButtons];

    self.cardGuide.frame = cameraPreviewFrame;
  });
}


- (void)toggleTorch:(UIButton *)theButton {
  CardIOLog(@"Manual torch change");
  BOOL torchWasOn = [self.videoStream torchIsOn];
  BOOL success = [self.videoStream setTorchOn:!torchWasOn];
  if (success) {
    [self updateLightButtonState];
  }
}

- (void)updateLightButtonState {
  if (self.lightButton) {
    BOOL torchIsOn = [self.videoStream torchIsOn];
    [self.lightButton setImage:[CardIOResource boltImageForTorchOn:torchIsOn] forState:UIControlStateNormal];
    self.lightButton.accessibilityLabel = torchIsOn ?
            CardIOLocalizedString(@"deactivate_flash", self.config.languageOrLocale) : // Turn flash off.
            CardIOLocalizedString(@"activate_flash", self.config.languageOrLocale); // Turn flash on.
  }
}

- (void)layoutCameraButtons {
  self.hasLaidoutCameraButtons = YES;
  
  CGRect cameraPreviewFrame = [self cameraPreviewFrame];

  // Hide the buttons when the view is really, really small
#define kButtonGreekingThreshold 200
  SuppressCAAnimation(^{
    if (cameraPreviewFrame.size.width < kButtonGreekingThreshold || self.rotatingInterface) {
      self.logoView.hidden = YES;
      self.lightButton.hidden = YES;
#if CARDIO_DEBUG
      _debugTextField.hidden = YES;
#endif
    } else {
      self.logoView.hidden = NO;
      self.lightButton.hidden = NO;
#if CARDIO_DEBUG
      _debugTextField.hidden = NO;
#endif
    }
  });

  self.logoView.frame = CGRectWithXYAndSize(cameraPreviewFrame.size.width + cameraPreviewFrame.origin.x - self.logoView.frame.size.width - 10.0f,
                                              cameraPreviewFrame.origin.y + 10.0f,
                                              self.logoView.frame.size);
  
  self.lightButton.frame = CGRectWithXYAndSize(cameraPreviewFrame.origin.x + 10.0f,
                                               cameraPreviewFrame.origin.y + 10.0f,
                                               self.lightButton.frame.size);


  InterfaceToDeviceOrientationDelta delta = orientationDelta([UIApplication sharedApplication].statusBarOrientation, self.deviceOrientation);
  CGFloat rotation = -rotationForOrientationDelta(delta); // undo the orientation delta
  CGAffineTransform r = CGAffineTransformMakeRotation(rotation);
  self.logoView.transform = r;
  self.lightButton.transform = r;
  
#if CARDIO_DEBUG
  _debugTextField.frame = CGRectWithXYAndSize(cameraPreviewFrame.origin.x + 10.0f,
                                              cameraPreviewFrame.origin.y + cameraPreviewFrame.size.height - _debugTextField.frame.size.height - 10.0f,
                                              _debugTextField.frame.size);

  switch (delta) {
    case InterfaceToDeviceOrientationSame: {
      _debugTextField.transform = CGAffineTransformTranslate(r, 70.0f, 64.0f);
      _debugTextField.textAlignment = NSTextAlignmentLeft;
      break;
    }
    case InterfaceToDeviceOrientationRotatedClockwise: {
      _debugTextField.transform = CGAffineTransformTranslate(r, -20.0f, 24.0f);
      _debugTextField.textAlignment = NSTextAlignmentRight;
      break;
    }
    case InterfaceToDeviceOrientationUpsideDown: {
      _debugTextField.transform = CGAffineTransformTranslate(r, 70.0f, 64.0f);
      _debugTextField.textAlignment = NSTextAlignmentRight;
      break;
    }
    case InterfaceToDeviceOrientationRotatedCounterclockwise: {
      _debugTextField.transform = CGAffineTransformTranslate(r, 20.0f, -24.0f);
      _debugTextField.textAlignment = NSTextAlignmentLeft;
      break;
    }
    default: {
      break;
    }
  }
#endif
}

- (void)showGuideLabel {
  // If we are rotating, let it stay hidden; the interface rotation cleanup code will re-show it
  if(!self.rotatingInterface) {
    self.guideLayerLabel.hidden = NO;
  }
}

- (void)orientGuideLayerLabel {
  InterfaceToDeviceOrientationDelta delta = orientationDelta([UIApplication sharedApplication].statusBarOrientation, self.deviceOrientation);
  CGFloat rotation = -rotationForOrientationDelta(delta); // undo the orientation delta
  self.guideLayerLabel.transform = CGAffineTransformMakeRotation(rotation);
}

#pragma mark - Orientation

- (void)willAppear {
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(didReceiveDeviceOrientationNotification:)
                                               name:UIDeviceOrientationDidChangeNotification
                                             object:[UIDevice currentDevice]];
  [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];

  self.deviceOrientation = UIDeviceOrientationUnknown;
  [self didReceiveDeviceOrientationNotification:nil];

  [self.videoStream willAppear];
  [self becomeFirstResponder];
}

- (void)willDisappear {
  [self.videoStream willDisappear];
  [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveDeviceOrientationNotification:(NSNotification *)notification {
  UIDeviceOrientation newDeviceOrientation;
  switch ([UIDevice currentDevice].orientation) {
    case UIDeviceOrientationPortrait:
      newDeviceOrientation = UIDeviceOrientationPortrait;
      break;
    case UIDeviceOrientationPortraitUpsideDown:
      newDeviceOrientation = UIDeviceOrientationPortraitUpsideDown;
      break;
    case UIDeviceOrientationLandscapeLeft:
      newDeviceOrientation = UIDeviceOrientationLandscapeLeft;
      break;
    case UIDeviceOrientationLandscapeRight:
      newDeviceOrientation = UIDeviceOrientationLandscapeRight;
      break;
    default:
      if (self.deviceOrientation == UIDeviceOrientationUnknown) {
        CardIOPaymentViewController *vc = [CardIOPaymentViewController cardIOPaymentViewControllerForResponder:self];
        if (vc) {
          newDeviceOrientation = (UIDeviceOrientation)vc.initialInterfaceOrientationForViewcontroller;
        }
        else {
          newDeviceOrientation = UIDeviceOrientationPortrait;
        }
      }
      else {
        newDeviceOrientation = self.deviceOrientation;
      }
      break;
  }

  if (![self isSupportedOverlayOrientation:(UIInterfaceOrientation)newDeviceOrientation]) {
    if ([self isSupportedOverlayOrientation:(UIInterfaceOrientation)self.deviceOrientation]) {
      newDeviceOrientation = self.deviceOrientation;
    }
    else {
      UIInterfaceOrientation orientation = [self defaultSupportedOverlayOrientation];
      if (orientation != UIDeviceOrientationUnknown) {
        newDeviceOrientation = (UIDeviceOrientation)orientation;
      }
    }
  }

  if(newDeviceOrientation != self.deviceOrientation) {
    self.deviceOrientation = newDeviceOrientation;
    [self.cardGuide didRotateToDeviceOrientation:self.deviceOrientation];
    if (self.hasLaidoutCameraButtons) {
      [UIView animateWithDuration:kRotationAnimationDuration animations:^{[self layoutCameraButtons];}];
    }
    else {
      [self layoutCameraButtons];
    }

    self.guideLayerLabel.hidden = YES;
    [self performSelector:@selector(showGuideLabel) withObject:nil afterDelay:kRotationLabelShowDelay];
    
    [self setNeedsLayout];

    if(self.config.scanOverlayView && !self.rotatingInterface) {
      NSDictionary *info = @{CardIOCurrentScanningOrientation: @(newDeviceOrientation),
                             CardIOScanningOrientationAnimationDuration: @(kRotationAnimationDuration)};
      [[NSNotificationCenter defaultCenter] postNotificationName:CardIOScanningOrientationDidChangeNotification
                                                          object:self
                                                        userInfo:info];
    }
  }
}

- (void)updateCameraOrientation {
  // We want the camera to appear natural. That means that the camera preview should match reality, orientationwise.
  // If the interfaceOrientation isn't portrait, then we need to rotate the preview precisely OPPOSITE the interface.
  CGFloat rotation = -orientationToRotation([UIApplication sharedApplication].statusBarOrientation);
  CATransform3D transform = CATransform3DIdentity;
  transform = CATransform3DRotate(transform, rotation, 0, 0, 1);
  //  NSLog(@"Updating camera orientation for interface orientation %@, device orientation %@: Rotation %f",
  //        INTERFACE_LANDSCAPE_OR_PORTRAIT([UIApplication sharedApplication].statusBarOrientation),
  //        DEVICE_LANDSCAPE_OR_PORTRAIT(self.deviceOrientation),
  //        rotation * 180 / M_PI);

  SuppressCAAnimation(^{
    self.videoStream.previewLayer.transform = transform;
  });
}

#if SIMULATE_CAMERA
#pragma mark - Shake gesture for simulated camera view

- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
  if (event.subtype == UIEventSubtypeMotionShake) {
    [self.videoStream considerItScanned];
  }
  if ([super respondsToSelector:@selector(motionEnded:withEvent:)]) {
    [super motionEnded:motion withEvent:event];
  }
}

- (BOOL)canBecomeFirstResponder {
  return YES;
}
#endif

#pragma mark - CardIOGuideLayerDelegate method

- (void)guideLayerDidLayout:(CGRect)internalGuideFrame {
  CGFloat width = MAX(internalGuideFrame.size.width, internalGuideFrame.size.height);
  CGFloat height = MIN(internalGuideFrame.size.width, internalGuideFrame.size.height);
  
  CGRect internalGuideRect = CGRectZeroWithSize(CGSizeMake(width, height));

  self.guideLayerLabel.bounds = internalGuideRect;
  [self.guideLayerLabel sizeToFit];

  CGRect cameraPreviewFrame = [self cameraPreviewFrame];
  self.guideLayerLabel.center = CGPointMake(CGRectGetMidX(cameraPreviewFrame), CGRectGetMidY(cameraPreviewFrame));
  
  internalGuideRect.size.height = 9999.9f;
  CGRect textRect = [self.guideLayerLabel textRectForBounds:internalGuideRect limitedToNumberOfLines:0];
  while (textRect.size.height > height && self.guideLayerLabel.font.pointSize > kMinimumInstructionsFontSize) {
    self.guideLayerLabel.font = [UIFont fontWithName:self.guideLayerLabel.font.fontName size:self.guideLayerLabel.font.pointSize - 1];
    textRect = [self.guideLayerLabel textRectForBounds:internalGuideRect limitedToNumberOfLines:0];
  }

  [self orientGuideLayerLabel];
}

#pragma mark - CardIOVideoStreamDelegate methods

- (void)videoStream:(CardIOVideoStream *)stream didProcessFrame:(CardIOVideoFrame *)processedFrame {
  [self.shutter setOpen:YES animated:YES duration:0.5f];

  // Hide instructions once we start to find edges
  if (processedFrame.numEdgesFound < 0.05f) {
    [UIView animateWithDuration:kLabelVisibilityAnimationDuration animations:^{self.guideLayerLabel.alpha = 1.0f;}];
  } else if (processedFrame.numEdgesFound > 2.1f) {
    [UIView animateWithDuration:kLabelVisibilityAnimationDuration animations:^{self.guideLayerLabel.alpha = 0.0f;}];
  }

  // Pass the video frame to the cardGuide so that it can update the edges
  self.cardGuide.videoFrame = processedFrame;

#if CARDIO_DEBUG
  static NSTimeInterval lastUpdated = 0;
  NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
  if (now - lastUpdated > 0.25) {
    lastUpdated = now;
    if (![processedFrame.debugString isEqualToString:_debugTextField.text]) {
      _debugTextField.text = processedFrame.debugString;
    }
  }
#endif
  
  [self.delegate videoStream:stream didProcessFrame:processedFrame];
}

// Overlay orientation has the same constraints as the view controller,
// unless self.config.allowFreelyRotatingCardGuide == YES.

- (UIInterfaceOrientationMask)supportedOverlayOrientationsMask {
  UIInterfaceOrientationMask supportedOverlayOrientationsMask = UIInterfaceOrientationMaskAll;
  CardIOPaymentViewController *vc = [CardIOPaymentViewController cardIOPaymentViewControllerForResponder:[self nextResponder]];
  if (vc) {
    supportedOverlayOrientationsMask = [vc supportedOverlayOrientationsMask];
  }
  else if (!self.config.allowFreelyRotatingCardGuide) {
    // We must be inside a raw CardIOView, without a CardIOPaymentViewController.
    UIResponder *responder = [self nextResponder];
    while (responder && ![responder isKindOfClass:[UIViewController class]]) {
      responder = [responder nextResponder];
    }
    if (responder) {
      supportedOverlayOrientationsMask = [((UIViewController *)responder) supportedInterfaceOrientations];
    }
  }
  return supportedOverlayOrientationsMask;
}

- (BOOL)isSupportedOverlayOrientation:(UIInterfaceOrientation)orientation {
  return (([self supportedOverlayOrientationsMask] & (1 << orientation)) != 0);
}

- (UIInterfaceOrientation)defaultSupportedOverlayOrientation {
  if (self.config.allowFreelyRotatingCardGuide) {
    return UIInterfaceOrientationPortrait;
  }
  else {
    UIInterfaceOrientation defaultOrientation = UIInterfaceOrientationUnknown;
    UIInterfaceOrientationMask supportedOverlayOrientationsMask = [self supportedOverlayOrientationsMask];
    for (NSInteger orientation = UIInterfaceOrientationPortrait;
         orientation <= UIInterfaceOrientationLandscapeRight;
         orientation++) {
      if ((supportedOverlayOrientationsMask & (1 << orientation)) != 0) {
        defaultOrientation = (UIInterfaceOrientation)orientation;
        break;
      }
    }
    return defaultOrientation;
  }
}

#pragma mark - Manual property implementations

- (UIFont *)instructionsFont {
  return self.guideLayerLabel.font;
}

- (void)setInstructionsFont:(UIFont *)instructionsFont {
  self.guideLayerLabel.font = instructionsFont;
}

@end

#endif