//
//  CardIOVideoStream.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#if USE_CAMERA || SIMULATE_CAMERA

#import "CardIOVideoStream.h"
#import "CardIODevice.h"
#import "CardIOVideoFrame.h"
#import "CardIOMacros.h"
#import "CardIOCardScanner.h"
#import "CardIOConfig.h"
#import "CardIOOrientation.h"
#import "CardIOPaymentViewControllerContinuation.h"

#define kCaptureSessionDefaultPresetResolution AVCaptureSessionPreset640x480
#define kVideoQueueName "io.card.ios.videostream"

#define kMinTimeIntervalForAutoFocusOnce 2

#define kIsoThatSuggestsMoreTorchlightThanWeReallyNeed 250
#define kRidiculouslyHighIsoSpeed 10000
#define kMinimalTorchLevel 0.05f
#define kCoupleOfHours 10000

#define kMinNumberOfFramesScannedToDeclareUnscannable 100

#pragma mark - SimulatedCameraLayer

#if SIMULATE_CAMERA

#import "CardIOBundle.h"
#import "CardIOCGGeometry.h"

@interface SimulatedCameraLayer : CALayer {
  NSInteger _imageIndex;
}
@end

@implementation SimulatedCameraLayer

- (id)init {
  if ((self = [super init])) {
    self.backgroundColor = [UIColor colorWithRed:1 green:0.7f blue:0.0f alpha:0.5f].CGColor;
    self.contentsScale = [UIScreen mainScreen].scale;
    self.contentsGravity = kCAGravityResizeAspect;
    self.needsDisplayOnBoundsChange = YES;
    _imageIndex = -1;
  }
  return self;
}

- (void)updateOrientation {
  UIInterfaceOrientation  imageOrientation;
  UIDeviceOrientation     deviceOrientation = [UIDevice currentDevice].orientation;
  switch (deviceOrientation) {
    case UIDeviceOrientationPortrait:
    case UIDeviceOrientationPortraitUpsideDown:
    case UIDeviceOrientationLandscapeLeft:
    case UIDeviceOrientationLandscapeRight:
      imageOrientation = (UIInterfaceOrientation) deviceOrientation;
      break;
    default:
      imageOrientation = (UIInterfaceOrientation) [UIApplication sharedApplication].statusBarOrientation;
      break;
  }

  UIImage *   image = [UIImage imageNamed:[NSString stringWithFormat:@"simulated_camera_%ld.png", (long)_imageIndex]];
  if (image == nil) {
    if (_imageIndex > 0) {
      _imageIndex = 0;
      image = [UIImage imageNamed:[NSString stringWithFormat:@"simulated_camera_%ld.png", (long)_imageIndex]];
    }
    if (image == nil) {
      image = [[CardIOBundle sharedInstance] imageNamed:@"paypal_logo.png"];
    }
  }
  
  if (imageOrientation == UIInterfaceOrientationPortrait) {
    self.contents = (id) image.CGImage;
  }
  else {
    CGAffineTransform transform = CGAffineTransformIdentity;
    switch (imageOrientation) {
      case UIInterfaceOrientationPortraitUpsideDown:
        transform = CGAffineTransformTranslate(transform, image.size.width, image.size.height);
        transform = CGAffineTransformRotate(transform, (CGFloat)M_PI);
        break;
      case UIInterfaceOrientationLandscapeLeft:
        transform = CGAffineTransformTranslate(transform, image.size.height, 0);
        transform = CGAffineTransformRotate(transform, (CGFloat)M_PI_2);
        break;
      case UIInterfaceOrientationLandscapeRight:
        transform = CGAffineTransformTranslate(transform, 0, image.size.width);
        transform = CGAffineTransformRotate(transform, (CGFloat)-M_PI_2);
        break;
    }
    
    CGFloat newWidth;
    CGFloat newHeight;

    if (UIInterfaceOrientationIsLandscape(imageOrientation)) {
      newWidth = image.size.height;
      newHeight = image.size.width;
    }
    else {
      newWidth = image.size.width;
      newHeight = image.size.height;
    }
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    if (colorSpace) {
      CGContextRef ctx = CGBitmapContextCreate(NULL, (size_t)newWidth, (size_t)newHeight, 8, 0, colorSpace, kCGImageAlphaPremultipliedFirst);
      if (ctx) {
        CGContextConcatCTM(ctx, transform);
        CGContextDrawImage(ctx, CGRectMake(0, 0, image.size.width, image.size.height), image.CGImage);
        self.contents = (id) CFBridgingRelease(CGBitmapContextCreateImage(ctx));
        CGContextRelease(ctx);
      }
      CGColorSpaceRelease(colorSpace);
    }
  }
}

- (void)nextImage {
  _imageIndex++;
  [self updateOrientation];
}

- (void)display {
  // Empirically, this `flush` is sometimes necessary to get this layer rendered,
  // particularly when we are are being shown inside a just-rotated modal form.
  [CATransaction flush];
}
@end

#endif  // SIMULATE_CAMERA

#pragma mark - CardIOVideoStream

@interface CardIOVideoStream ()
@property(nonatomic, assign, readwrite) BOOL running;
@property(nonatomic, assign, readwrite) BOOL wasRunningBeforeBeingBackgrounded;
@property(nonatomic, assign, readwrite) BOOL didEndGeneratingDeviceOrientationNotifications;
@property(assign, readwrite) UIInterfaceOrientation interfaceOrientation; // intentionally atomic -- video frames are processed on a different thread
@property(nonatomic, strong, readwrite) AVCaptureVideoPreviewLayer *previewLayer;
@property(nonatomic, strong, readwrite) AVCaptureSession *captureSession;
@property(nonatomic, strong, readwrite) AVCaptureDevice *camera;
@property(nonatomic, strong, readwrite) AVCaptureDeviceInput *cameraInput;
@property(nonatomic, strong, readwrite) AVCaptureVideoDataOutput *videoOutput;

@property (nonatomic, assign, readwrite) NSTimeInterval lastAutoFocusOnceTime;
@property (nonatomic, assign, readwrite) BOOL           currentlyAdjustingFocus;
@property (nonatomic, assign, readwrite) BOOL           currentlyAdjustingExposure;
@property (nonatomic, assign, readwrite) NSTimeInterval lastChangeSignal;
@property (nonatomic, assign, readwrite) BOOL           lastChangeTorchStateToOFF;

// This semaphore is intended to prevent a crash which was recorded with this exception message:
// "AVCaptureSession can't stopRunning between calls to beginConfiguration / commitConfiguration"
@property(nonatomic, strong, readwrite) dispatch_semaphore_t cameraConfigurationSemaphore;

#if LOG_FPS
@property(nonatomic, strong, readwrite) NSDate *start;
@property(nonatomic, assign, readwrite) NSUInteger numFrames;
#endif

#if SIMULATE_CAMERA
@property(nonatomic, strong, readwrite) NSTimer *simulatedCameraTimer;
#endif

@end

#pragma mark -

@implementation CardIOVideoStream

- (id)init {
  if((self = [super init])) {
    _interfaceOrientation = (UIInterfaceOrientation)UIDeviceOrientationUnknown;
    _scanner = [[CardIOCardScanner alloc] init];
    _cameraConfigurationSemaphore = dispatch_semaphore_create(1); // parameter of `1` implies "allow access to only one thread at a time"
#if USE_CAMERA
    _captureSession = [[AVCaptureSession alloc] init];
    _camera = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    _previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
    dmz = dmz_context_create();
#elif SIMULATE_CAMERA
    _previewLayer = [SimulatedCameraLayer layer];
#endif
  }

  return self;
}

- (void)dealloc {
  [self stopSession]; // just to be safe
  
  if (!self.didEndGeneratingDeviceOrientationNotifications) {
    [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
  }

  [[NSNotificationCenter defaultCenter] removeObserver:self];

#if USE_CAMERA
  dmz_context_destroy(dmz), dmz = NULL;
#endif
}

#pragma mark - Orientation

- (void)willAppear {
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(didReceiveBackgroundingNotification:)
                                               name:UIApplicationWillResignActiveNotification
                                             object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(didReceiveForegroundingNotification:)
                                               name:UIApplicationDidBecomeActiveNotification
                                             object:nil];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(didReceiveDeviceOrientationNotification:)
                                               name:UIDeviceOrientationDidChangeNotification
                                             object:[UIDevice currentDevice]];
  [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
  [self didReceiveDeviceOrientationNotification:nil];

// If we ever want to use higher resolution images, this is a good place to do that.
//    if ([self.captureSession canSetSessionPreset:AVCaptureSessionPreset1920x1080]) {
//      self.captureSession.sessionPreset = AVCaptureSessionPreset1920x1080;
//    }
//    else
//    if ([self.captureSession canSetSessionPreset:AVCaptureSessionPreset1280x720]) {
//      self.captureSession.sessionPreset = AVCaptureSessionPreset1280x720;
//    }
//  }
}

- (void)willDisappear {
  self.didEndGeneratingDeviceOrientationNotifications = true;
  [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveDeviceOrientationNotification:(NSNotification *)notification {
  UIInterfaceOrientation newInterfaceOrientation;
  switch([UIDevice currentDevice].orientation) {
    case UIDeviceOrientationPortrait:
      newInterfaceOrientation = UIInterfaceOrientationPortrait;
      break;
    case UIDeviceOrientationPortraitUpsideDown:
      newInterfaceOrientation = UIInterfaceOrientationPortraitUpsideDown;
      break;
    case UIDeviceOrientationLandscapeLeft:
      newInterfaceOrientation = UIInterfaceOrientationLandscapeRight;
      break;
    case UIDeviceOrientationLandscapeRight:
      newInterfaceOrientation = UIInterfaceOrientationLandscapeLeft;
      break;
    default:
      if (self.interfaceOrientation == (UIInterfaceOrientation)UIDeviceOrientationUnknown) {
        CardIOPaymentViewController *vc = [CardIOPaymentViewController cardIOPaymentViewControllerForResponder:self.delegate];
        if (vc) {
          newInterfaceOrientation = vc.initialInterfaceOrientationForViewcontroller;
        }
        else {
          newInterfaceOrientation = UIInterfaceOrientationPortrait;
        }
      }
      else {
        newInterfaceOrientation = self.interfaceOrientation;
      }
      break;
  }
  
  if ([self.delegate respondsToSelector:@selector(isSupportedOverlayOrientation:)] &&
      [self.delegate respondsToSelector:@selector(defaultSupportedOverlayOrientation)]) {
    if (![self.delegate isSupportedOverlayOrientation:newInterfaceOrientation]) {
      if ([self.delegate isSupportedOverlayOrientation:self.interfaceOrientation]) {
        newInterfaceOrientation = self.interfaceOrientation;
      }
      else {
        UIInterfaceOrientation orientation = [self.delegate defaultSupportedOverlayOrientation];
        if (orientation != (UIInterfaceOrientation)UIDeviceOrientationUnknown) {
          newInterfaceOrientation = orientation;
        }
      }
    }
  }
  
  if (newInterfaceOrientation != self.interfaceOrientation) {
    self.interfaceOrientation = newInterfaceOrientation;
    
#if SIMULATE_CAMERA
    [(SimulatedCameraLayer *)self.previewLayer updateOrientation];
    [self captureOutput:nil didOutputSampleBuffer:nil fromConnection:nil];
#endif
  }
}

#pragma mark - Camera configuration changing

- (BOOL)changeCameraConfiguration:(void(^)())changeBlock
#if CARDIO_DEBUG
                 withErrorMessage:(NSString *)errorMessage
#endif
{
  dispatch_semaphore_wait(self.cameraConfigurationSemaphore, DISPATCH_TIME_FOREVER);
  
  BOOL success = NO;
  NSError *lockError = nil;
  [self.captureSession beginConfiguration];
  [self.camera lockForConfiguration:&lockError];
  if(!lockError) {
    changeBlock();
    [self.camera unlockForConfiguration];
    success = YES;
  }
#if CARDIO_DEBUG
  else {
    CardIOLog(errorMessage, lockError);
  }
#endif
  
  [self.captureSession commitConfiguration];
  
  dispatch_semaphore_signal(self.cameraConfigurationSemaphore);
  
  return success;
}

#pragma mark - Torch

- (BOOL)hasTorch {
  return [self.camera hasTorch] &&
  [self.camera isTorchModeSupported:AVCaptureTorchModeOn] &&
  [self.camera isTorchModeSupported:AVCaptureTorchModeOff] &&
  self.camera.torchAvailable;
}

- (BOOL)canSetTorchLevel {
  return [self.camera hasTorch] && [self.camera respondsToSelector:@selector(setTorchModeOnWithLevel:error:)];
}

- (BOOL)torchIsOn {
  return self.camera.torchMode == AVCaptureTorchModeOn;
}

- (BOOL)setTorchOn:(BOOL)torchShouldBeOn {
  return [self changeCameraConfiguration:^{
    AVCaptureTorchMode newTorchMode = torchShouldBeOn ? AVCaptureTorchModeOn : AVCaptureTorchModeOff;
    [self.camera setTorchMode:newTorchMode];
  }
#if CARDIO_DEBUG
  withErrorMessage:@"CardIO couldn't lock for configuration to turn on/off torch: %@"
#endif
  ];
}

- (BOOL)setTorchModeOnWithLevel:(float)torchLevel {
  __block BOOL torchSuccess = NO;
  BOOL success = [self changeCameraConfiguration:^{
    NSError *error;
    torchSuccess = [self.camera setTorchModeOnWithLevel:torchLevel error:&error];
  }
#if CARDIO_DEBUG
  withErrorMessage:@"CardIO couldn't lock for configuration to turn on/off torch with level: %@"
#endif
  ];

  return success && torchSuccess;
}

#pragma mark - Focus

- (BOOL)hasAutofocus {
  return [self.camera isFocusModeSupported:AVCaptureFocusModeAutoFocus];
}

- (void)refocus {
  CardIOLog(@"Manual refocusing");
  [self autofocusOnce];
  [self performSelector:@selector(resumeContinuousAutofocusing) withObject:nil afterDelay:0.1f];
}

- (void)autofocusOnce {
  [self changeCameraConfiguration:^{
    if([self.camera isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
      [self.camera setFocusMode:AVCaptureFocusModeAutoFocus];
    }
  }
#if CARDIO_DEBUG
  withErrorMessage:@"CardIO couldn't lock for configuration to autofocusOnce: %@"
#endif
   ];
}

- (void)resumeContinuousAutofocusing {
  [self changeCameraConfiguration:^{
    if([self.camera isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
      [self.camera setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
    }
  }
#if CARDIO_DEBUG
  withErrorMessage:@"CardIO couldn't lock for configuration to resumeContinuousAutofocusing: %@"
#endif
   ];
}

#pragma mark - Session

// Consistent with <https://devforums.apple.com/message/887783#887783>, under iOS 7 it
// appears that our captureSession's input and output linger in memory even after the
// captureSession itself is dealloc'ed, unless we explicitly call removeInput: and
// removeOutput:.
//
// Moreover, it can be a long time from when we are fully released until we are finally dealloc'ed.
//
// The result is that if a user triggers a series of camera sessions, especially without long pauses
// in between, we start clogging up memory with our cameraInput and videoOutput objects.
//
// So I've now moved the creation and adding of input and output objects from [self init] to
// [self startSession]. And in [self stopSession] I'm now removing those objects.
// This seems to have solved the problem (for now, anyways).

- (BOOL)addInputAndOutput {
#if USE_CAMERA
  NSError *sessionError = nil;
  _cameraInput = [AVCaptureDeviceInput deviceInputWithDevice:self.camera error:&sessionError];
  if(sessionError || !self.cameraInput) {
    CardIOLog(@"CardIO camera input error: %@", sessionError);
    return NO;
  }
  
  [self.captureSession addInput:self.cameraInput];
  self.captureSession.sessionPreset = kCaptureSessionDefaultPresetResolution;
  
  _videoOutput = [[AVCaptureVideoDataOutput alloc] init];
  if([CardIODevice shouldSetPixelFormat]) {
    NSDictionary *videoOutputSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedInteger:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange]
                                                                    forKey:(NSString *)kCVPixelBufferPixelFormatTypeKey];
    [self.videoOutput setVideoSettings:videoOutputSettings];
  }
  self.videoOutput.alwaysDiscardsLateVideoFrames = YES;
  // NB: DO NOT USE minFrameDuration. minFrameDuration causes focusing to
  // slow down dramatically, which causes significant ux pain.
  dispatch_queue_t queue = dispatch_queue_create(kVideoQueueName, NULL);
  [self.videoOutput setSampleBufferDelegate:self queue:queue];
  
  [self.captureSession addOutput:self.videoOutput];
#endif
  
  return YES;
}

- (void)removeInputAndOutput {
#if USE_CAMERA
  [self.captureSession removeInput:self.cameraInput];
  [self.videoOutput setSampleBufferDelegate:nil queue:NULL];
  [self.captureSession removeOutput:self.videoOutput];
#endif
}

- (void)startSession {
#if USE_CAMERA
  if ([self addInputAndOutput]) {
    [self.camera addObserver:self forKeyPath:@"adjustingFocus" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial) context:nil];
    [self.camera addObserver:self forKeyPath:@"adjustingExposure" options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionInitial) context:nil];
    [self.captureSession startRunning];

    [self changeCameraConfiguration:^{
      if ([self.camera respondsToSelector:@selector(isAutoFocusRangeRestrictionSupported)]) {
        if(self.camera.autoFocusRangeRestrictionSupported) {
          self.camera.autoFocusRangeRestriction = AVCaptureAutoFocusRangeRestrictionNear;
        }
      }
      if ([self.camera respondsToSelector:@selector(isFocusPointOfInterestSupported)]) {
        if(self.camera.focusPointOfInterestSupported) {
          self.camera.focusPointOfInterest = CGPointMake(0.5, 0.5);
        }
      }
    }
 #if CARDIO_DEBUG
                   withErrorMessage:@"CardIO couldn't lock for configuration within startSession"
 #endif
     ];
    self.running = YES;
  }
#elif SIMULATE_CAMERA
  self.simulatedCameraTimer = [NSTimer scheduledTimerWithTimeInterval:2 target:self selector:@selector(simulateNewFrame) userInfo:nil repeats:YES];
  [self simulateNewFrame]; // grab the first frame right away
  self.running = YES;
#endif
}

- (void)stopSession {
  if (self.running) {
#if USE_CAMERA
    [self changeCameraConfiguration:^{
      // restore default focus range
      if ([self.camera respondsToSelector:@selector(isAutoFocusRangeRestrictionSupported)]) {
        if(self.camera.autoFocusRangeRestrictionSupported) {
          self.camera.autoFocusRangeRestriction = AVCaptureAutoFocusRangeRestrictionNone;
        }
      }
    }
 #if CARDIO_DEBUG
                   withErrorMessage:@"CardIO couldn't lock for configuration within stopSession"
 #endif
     ];
#endif
    
    dispatch_semaphore_wait(self.cameraConfigurationSemaphore, DISPATCH_TIME_FOREVER);
    
#if USE_CAMERA
    [self.camera removeObserver:self forKeyPath:@"adjustingExposure"];
    [self.camera removeObserver:self forKeyPath:@"adjustingFocus"];
    [self.captureSession stopRunning];
    [self removeInputAndOutput];
#elif SIMULATE_CAMERA
    [self.simulatedCameraTimer invalidate];
    self.simulatedCameraTimer = nil;
#endif

    self.running = NO;
    
    dispatch_semaphore_signal(self.cameraConfigurationSemaphore);
  }
}

- (void)sendFrameToDelegate:(CardIOVideoFrame *)frame {
  // Due to threading, we can receive frames after we've stopped running.
  // Clean this up for our delegate.
  if(self.running) {
    [self.delegate videoStream:self didProcessFrame:frame];
  }
  else {
    CardIOLog(@"STRAY FRAME!!! wasted processing. we are sad.");
  }
}

#if SIMULATE_CAMERA
- (void)simulateNewFrame {
  [(SimulatedCameraLayer *)self.previewLayer nextImage];
  [self captureOutput:nil didOutputSampleBuffer:nil fromConnection:nil];
}

- (void)considerItScanned {
  self.scanner.considerItScanned = YES;
}
#endif

#pragma mark - Key-Value Observing

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
  if ([keyPath isEqualToString:@"adjustingFocus"]) {
    self.currentlyAdjustingFocus = [change[NSKeyValueChangeNewKey] boolValue];
  }
  else if ([keyPath isEqualToString:@"adjustingExposure"]) {
    self.currentlyAdjustingExposure = [change[NSKeyValueChangeNewKey] boolValue];
  }
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate methods

#ifdef __IPHONE_6_0 // Compile-time check for the time being, so our code still compiles with the fully released toolchain
- (void)captureOutput:(AVCaptureOutput *)captureOutput didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
}
#endif

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection {
  @autoreleasepool {
#if LOG_FPS
    static double fps = 0;
#endif
#if SIMULATE_CAMERA
    CardIOVideoFrame *frame = [[CardIOVideoFrame alloc] initWithSampleBuffer:nil interfaceOrientation:self.interfaceOrientation];
    frame.scanner = self.scanner;
    frame.cardInfo = self.scanner.cardInfo;
#else
    CardIOVideoFrame *frame = [[CardIOVideoFrame alloc] initWithSampleBuffer:sampleBuffer interfaceOrientation:self.interfaceOrientation];
    frame.scanner = self.scanner;
    frame.dmz = dmz;
    
  #if LOG_FPS
    if(!self.start) {
      self.start = [NSDate date];
    } else {
      self.numFrames++;
      if(self.numFrames % 20 == 0) {
        NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:self.start];
        fps = self.numFrames / elapsed;
        CardIOLog(@"Elapsed: %0.1f. Frames: %lu. FPS: %0.2f", elapsed, (unsigned long)self.numFrames, fps);
        self.numFrames = 0;
        self.start = [NSDate date];
      }
    }
  #endif
#endif

    frame.scanExpiry = self.config.scanExpiry;
    frame.detectionMode = self.config.detectionMode;

    if (self.running) {
#if USE_CAMERA
      if (!self.currentlyAdjustingFocus) {
        if ([self canSetTorchLevel]) {
          frame.calculateBrightness = YES;
          frame.torchIsOn = [self torchIsOn];
        }
        
        NSDictionary *exifDict = (__bridge NSDictionary *)((CFDictionaryRef)CMGetAttachment(sampleBuffer, (CFStringRef)@"{Exif}", NULL));
        if (exifDict != nil) {
          frame.isoSpeed = [exifDict[@"ISOSpeedRatings"][0] integerValue];
          frame.shutterSpeed = [exifDict[@"ShutterSpeedValue"] floatValue];
        }
        else {
          frame.isoSpeed = kRidiculouslyHighIsoSpeed;
          frame.shutterSpeed = 0;
        }
        
        [frame process];

        if (frame.cardY && self.config.detectionMode == CardIODetectionModeAutomatic) {
          if (self.scanner.scanSessionAnalytics->num_frames_scanned > kMinNumberOfFramesScannedToDeclareUnscannable) {
            self.config.detectionMode = CardIODetectionModeCardImageOnly;
            frame.detectionMode = CardIODetectionModeCardImageOnly;
            [frame process];
          }
        }
      }
#endif
      
#if CARDIO_DEBUG
      // If you're going to modify the frame.debugString returned from [frame process], do it right here.
      frame.debugString = [NSString stringWithFormat:
                           @"Br: %.1f %@ %ld/%.1f",
                           frame.brightnessScore,
                           [self torchIsOn] ? @"ON" : @"OFF",
                           (long)frame.isoSpeed,
                           frame.shutterSpeed];
  #if LOG_FPS
      CGSize imageSize = (frame.debugCardImage ? frame.debugCardImage.size : CGSizeMake(kCreditCardTargetWidth, kCreditCardTargetHeight));
      UIFont *font = [UIFont boldSystemFontOfSize:48];
      UIGraphicsBeginImageContext(imageSize);
      [frame.debugCardImage drawInRect:CGRectMake(0, 0, imageSize.width, imageSize.height)];
      CGRect rect = CGRectMake(10, 10, imageSize.width, imageSize.height);
      [[UIColor yellowColor] set];
      [[NSString stringWithFormat:@"%0.2f", fps] drawInRect:CGRectIntegral(rect) withFont:font];
      frame.debugCardImage = UIGraphicsGetImageFromCurrentImageContext();
      UIGraphicsEndImageContext();
  #endif
#endif

      [self performSelectorOnMainThread:@selector(sendFrameToDelegate:) withObject:frame waitUntilDone:NO];
      
      // Autofocus
      BOOL didAutoFocus = NO;
      if (!self.currentlyAdjustingFocus && frame.focusSucks && [self hasAutofocus]) {
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        if (now - self.lastAutoFocusOnceTime > kMinTimeIntervalForAutoFocusOnce) {
          self.lastAutoFocusOnceTime = now;
          CardIOLog(@"Auto-triggered focusing");
          [self autofocusOnce];
          [self performSelector:@selector(resumeContinuousAutofocusing) withObject:nil afterDelay:0.1f];
          didAutoFocus = YES;
        }
      }

      // Auto-torch
      if (!self.currentlyAdjustingFocus && !didAutoFocus && !self.currentlyAdjustingExposure && [self canSetTorchLevel]) {
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        BOOL changeTorchState = NO;
        BOOL changeTorchStateToOFF = NO;
        if (frame.brightnessHigh) {
          if ([self torchIsOn]) {
            changeTorchState = YES;
            changeTorchStateToOFF = YES;
          }
        }
        else {
          if (frame.brightnessLow) {
            if (![self torchIsOn] && frame.isoSpeed > kIsoThatSuggestsMoreTorchlightThanWeReallyNeed) {
              changeTorchState = YES;
              changeTorchStateToOFF = NO;
            }
          }
          else if ([self torchIsOn]) {
            if (frame.isoSpeed < kIsoThatSuggestsMoreTorchlightThanWeReallyNeed) {
              changeTorchState = YES;
              changeTorchStateToOFF = YES;
            }
          }
        }
        
        // Require at least two consecutive change signals in the same direction, over at least one second.

        // Note: if self.lastChangeSignal == 0.0, then we've just entered camera view.
        // In that case, lastChangeTorchStateToOFF == NO, and so turning ON the torch won't wait that second.
        
        if (changeTorchState) {
          if (changeTorchStateToOFF == self.lastChangeTorchStateToOFF) {
            if (now - self.lastChangeSignal > 1) {
              CardIOLog(@"Automatic torch change");
              if (changeTorchStateToOFF) {
                [self setTorchOn:NO];
              }
              else {
                [self setTorchModeOnWithLevel:kMinimalTorchLevel];
              }
              self.lastChangeSignal = now + kCoupleOfHours;
            }
            else {
              self.lastChangeSignal = MIN(self.lastChangeSignal, now);
            }
          }
          else {
            self.lastChangeSignal = now;
            self.lastChangeTorchStateToOFF = changeTorchStateToOFF;
          }
        }
        else {
          self.lastChangeSignal = now + kCoupleOfHours;
        }
      }
    }
  }
}

#pragma mark - Suspend/Resume when app is backgrounded/foregrounded

- (void)didReceiveBackgroundingNotification:(NSNotification *)notification {
  self.wasRunningBeforeBeingBackgrounded = self.running;
  [self stopSession];
#if USE_CAMERA
  dmz_prepare_for_backgrounding(dmz);
#endif
}

- (void)didReceiveForegroundingNotification:(NSNotification *)notification {
  if (self.wasRunningBeforeBeingBackgrounded) {
    [self startSession];
  }
}

@end

#endif // USE_CAMERA || SIMULATE_CAMERA
