//
//  CardIOVideoFrame.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#if USE_CAMERA || SIMULATE_CAMERA

#import "CardIOVideoFrame.h"
#import "CardIOIplImage.h"
#import "CardIODmzBridge.h"
#import "CardIOMacros.h"
#import "CardIOCardScanner.h"
#import "CardIOReadCardInfo.h"
#import "dmz_constants.h"
#import "scan_analytics.h"

#import "CardIODetectionMode.h"

#if CARDIO_DEBUG
#import "CardIOCardOverlay.h"
#include "sobel.h"
#endif

#pragma mark - Constants controlling card recognition sensitivity

#define kMinLuma 100
#define kMaxLuma 200
#define kMinFallbackFocusScore 6
#define kMinNonSuckyFocusScore 3

#pragma mark -

@interface CardIOVideoFrame ()

@property (nonatomic, assign, readwrite) CMSampleBufferRef buffer;
@property (nonatomic, assign, readwrite) UIInterfaceOrientation orientation;
#if USE_CAMERA
@property (nonatomic, assign, readwrite) dmz_edges found_edges;
@property (nonatomic, assign, readwrite) dmz_corner_points corner_points;
#endif

- (void)detectCardInSamples;
- (void)detectCardInSamplesWithFlip:(BOOL)shouldFlip;
- (void)transformCbCrWithFrameOrientation:(FrameOrientation)frameOrientation;

@end

#pragma mark -

@implementation CardIOVideoFrame

- (id)initWithSampleBuffer:(CMSampleBufferRef)sampleBuffer interfaceOrientation:(UIInterfaceOrientation)currentOrientation {
  if((self = [super init])) {
    _buffer = sampleBuffer;
    _orientation = currentOrientation; // not using setters/getters, for performance
    _dmz = NULL;  // use NULL b/c non-object pointer
  }
  return self;
}

#if USE_CAMERA

- (void)process {
  BOOL performAllProcessing = NO;

  cvSetErrMode(CV_ErrModeParent);
  
  CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(self.buffer);
  CVPixelBufferLockBaseAddress(imageBuffer, 0);

  self.ySample = [CardIOIplImage imageFromYCbCrBuffer:imageBuffer plane:Y_PLANE];
  
  BOOL useFullImageForFocusScore = NO;
  useFullImageForFocusScore = (self.detectionMode == CardIODetectionModeCardImageOnly); // when detecting, rely more on focus than on contents
  
  self.focusScore = dmz_focus_score(self.ySample.image, useFullImageForFocusScore);
  self.focusOk = self.focusScore > kMinFallbackFocusScore;
  self.focusSucks = self.focusScore < kMinNonSuckyFocusScore;
  
  if (self.calculateBrightness) {
    self.brightnessScore = dmz_brightness_score(self.ySample.image, self.torchIsOn);
    self.brightnessLow = self.brightnessScore < kMinLuma;
    self.brightnessHigh = self.brightnessScore > kMaxLuma;
  }

  if(self.detectionMode == CardIODetectionModeCardImageOnly) {
    performAllProcessing = YES;
  }
  
#if CARDIO_DEBUG
  self.debugCardImage = nil;
#endif

  if(self.focusOk || performAllProcessing) {
    CardIOIplImage *brSample = [CardIOIplImage imageFromYCbCrBuffer:imageBuffer plane:CBCR_PLANE];
    
    NSArray *bAndRSamples = [brSample split];
    self.cbSample = bAndRSamples[0];
    self.crSample = bAndRSamples[1];
    
    [self detectCardInSamples];
  }

  CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
  
#if CARDIO_DEBUG
//  self.debugString = [NSString stringWithFormat:@"Focus: %5.1f", focusScore];
#endif
}

- (void)detectCardInSamples {
  [self detectCardInSamplesWithFlip:NO];
}

- (void)detectCardInSamplesWithFlip:(BOOL)shouldFlip {
  self.flipped = shouldFlip;

  FrameOrientation frameOrientation = frameOrientationWithInterfaceOrientation(self.orientation);
  if (self.flipped) {
    frameOrientation = dmz_opposite_orientation(frameOrientation);
  }

  bool foundCard = dmz_detect_edges(self.ySample.image, self.cbSample.image, self.crSample.image,
                                    frameOrientation, &_found_edges, &_corner_points);

  self.foundTopEdge = (BOOL)self.found_edges.top.found;
  self.foundBottomEdge = (BOOL)self.found_edges.bottom.found;
  self.foundLeftEdge = (BOOL)self.found_edges.left.found;
  self.foundRightEdge = (BOOL)self.found_edges.right.found;

  if(foundCard) {
    IplImage *foundCardY = NULL;
    dmz_transform_card(self.dmz, self.ySample.image, self.corner_points, frameOrientation, false, &foundCardY);
    self.cardY = [CardIOIplImage imageWithIplImage:foundCardY];

    BOOL scanCard = YES;
    scanCard = (self.detectionMode != CardIODetectionModeCardImageOnly);
    if(scanCard) {
      [self.scanner addFrame:self.cardY
                  focusScore:self.focusScore
             brightnessScore:self.brightnessScore
                    isoSpeed:self.isoSpeed
                shutterSpeed:self.shutterSpeed
                   torchIsOn:self.torchIsOn
                 markFlipped:self.flipped
                  scanExpiry:self.scanExpiry];
      
#if CARDIO_DEBUG
      if (self.scanner.cardInfo != nil) {
#if 1
        UIImage *cardImage = [self.cardY UIImage];
#else
        CardIOIplImage *sobelImage16 = [CardIOIplImage imageWithSize:self.cardY.cvSize depth:IPL_DEPTH_16S channels:1];
        cvSetZero(sobelImage16.image);
        
        CvRect belowNumbersRect = cvRect(0, self.scanner.cardInfo.yOffset + kNumberHeight, self.cardY.cvSize.width, self.cardY.cvSize.height - (self.scanner.cardInfo.yOffset + kNumberHeight));
        cvSetImageROI(self.cardY.image, belowNumbersRect);
        cvSetImageROI(sobelImage16.image, belowNumbersRect);
        
        llcv_scharr3_dx_abs(cardY.image, sobelImage16.image);
        
        cvResetImageROI(cardY.image);
        cvResetImageROI(sobelImage16.image);
        
        CardIOIplImage *sobelImage = [CardIOIplImage imageWithSize:self.cardY.cvSize depth:IPL_DEPTH_8U channels:1];
        cvConvertScale(sobelImage16.image, sobelImage.image);
        
        UIImage *cardImage = [sobelImage UIImage];
#endif
        self.debugCardImage = [CardIOCardOverlay cardImage:cardImage withDisplayInfo:self.scanner.cardInfo annotated:NO];
      }
#endif
      
      if(self.scanner.complete) {
        self.cardInfo = self.scanner.cardInfo;
        
        // if the scanning is complete, we need the transformed cb/cr channels for display
        [self transformCbCrWithFrameOrientation:frameOrientation];
      } else if (!self.flipped && self.scanner.lastFrameWasUpsideDown) {
        [self detectCardInSamplesWithFlip:YES];
      }
    } else {
      // we're not scanning, so the transformed cb/cr channels might be needed at any time
      [self transformCbCrWithFrameOrientation:frameOrientation];
    }
  }
}

- (void)transformCbCrWithFrameOrientation:(FrameOrientation)frameOrientation {
  // It's safe to calculate cardCb and cardCr if we've already calculated cardY, since they share
  // the same prerequisites.
  if(self.cardY) {
    IplImage *foundCardCb = NULL;
    dmz_transform_card(self.dmz, self.cbSample.image, self.corner_points, frameOrientation, true, &foundCardCb);
    self.cardCb = [CardIOIplImage imageWithIplImage:foundCardCb];

    IplImage *foundCardCr = NULL;
    dmz_transform_card(self.dmz, self.crSample.image, self.corner_points, frameOrientation, true, &foundCardCr);
    self.cardCr = [CardIOIplImage imageWithIplImage:foundCardCr];
  }
}

- (BOOL)foundAllEdges {
  return self.foundTopEdge && self.foundBottomEdge && self.foundLeftEdge && self.foundRightEdge;
}

- (uint)numEdgesFound {
  return (uint) self.foundTopEdge + (uint) self.foundBottomEdge + (uint) self.foundLeftEdge + (uint) self.foundRightEdge;
}

- (UIImage *)imageWithGrayscale:(BOOL)grayscale {
  return grayscale ? [self.cardY UIImage] : [[CardIOIplImage rgbImageWithY:self.cardY cb:self.cardCb cr:self.cardCr] UIImage];
}

#elif SIMULATE_CAMERA

- (void)process {}
- (BOOL)foundAllEdges {return NO;}
- (uint)numEdgesFound {return 0;}
- (void)detectCardInSamples {}
- (void)detectCardInSamplesWithFlip:(BOOL)shouldFlip {}
- (void)transformCbCrWithFrameOrientation:(FrameOrientation)frameOrientation {}

- (UIImage *)imageWithGrayscale:(BOOL)grayscale {
  UIImage *image = [UIImage imageNamed:@"simulated_camera_0.png"];
  CGSize  cardSize = CGSizeMake(kCreditCardTargetWidth, kCreditCardTargetHeight);
  UIGraphicsBeginImageContextWithOptions(cardSize, NO, 0.0);
  [image drawInRect:CGRectMake(0, 0, cardSize.width, cardSize.height)];
  UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  return newImage;
}

#endif

- (NSData *)encodedImageUsingEncoding:(FrameEncoding)encoding {
  NSData *imageData = nil;
  
  switch(encoding) {
    case FrameEncodingColorPNG: {
      imageData = UIImagePNGRepresentation([self imageWithGrayscale:NO]);
      break;      
    }
    case FrameEncodingGrayPNG: {
      imageData = UIImagePNGRepresentation([self imageWithGrayscale:YES]);
      break;
    }
    default: {
      CardIOLog(@"CardIOVideoFrame encodeWithEncoding called with unrecognized encoding %i", encoding);
      break;
    }
  }
  
  return imageData;
}

+ (NSString *)filenameForImageEncodedUsingEncoding:(FrameEncoding)encoding {
  NSString *imageFilename = nil;
  NSTimeInterval timestamp = [[NSDate date] timeIntervalSinceReferenceDate];
  
  switch(encoding) {
    case FrameEncodingColorPNG:
      imageFilename = [NSString stringWithFormat:@"png_color_cc_%f.png", timestamp];
      break;
    case FrameEncodingGrayPNG:
      imageFilename = [NSString stringWithFormat:@"png_gray_cc_%f.png", timestamp];
      break;
    default:
      CardIOLog(@"CardIOVideoFrame filenameForImageEncodedUsingEncoding called with unrecognized encoding %i", encoding);
      break;
  }
  
  return imageFilename;
}


@end

#endif
