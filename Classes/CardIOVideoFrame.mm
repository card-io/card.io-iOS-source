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
#include "stripes.h"
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
#if 0
      if (self.scanner.cardInfo != nil) {
        UIImage *cardImage = [self.cardY UIImage];
        self.debugCardImage = [CardIOCardOverlay cardImage:cardImage withDisplayInfo:self.scanner.cardInfo annotated:NO];
      }
#else
      if (!self.flipped) {
        static NSDate *lastUpdated = [NSDate dateWithTimeIntervalSince1970:0];

        static CardIOIplImage *sobelImage = [CardIOIplImage imageWithSize:self.cardY.cvSize depth:IPL_DEPTH_8U channels:1];
        static CardIOIplImage *sobelImage16 = [CardIOIplImage imageWithSize:self.cardY.cvSize depth:IPL_DEPTH_16S channels:1];
        
        if (fabs([lastUpdated timeIntervalSinceNow]) >= 1.0) {
          int card_height = self.cardY.cvSize.height;

          cvCopy(self.cardY.image, sobelImage.image);
          cvConvertScale(sobelImage.image, sobelImage16.image);
          
          CvRect relevant_rect = cvRect(0,
                                        (int)(card_height / 2),
                                        (int)(self.cardY.cvSize.width),
                                        (int)(card_height / 2));
          cvSetImageROI(self.cardY.image, relevant_rect);
          cvSetImageROI(sobelImage16.image, relevant_rect);
          
          llcv_scharr3_dx_abs(self.cardY.image, sobelImage16.image);
          
          cvConvertScale(sobelImage16.image, sobelImage16.image, 0.3);
          
          cvResetImageROI(self.cardY.image);
          cvResetImageROI(sobelImage16.image);
          
          std::vector<StripeSum> stripe_sums = sorted_stripes(sobelImage16.image,
                                                              (uint16_t)(card_height / 2),
                                                              kSmallCharacterHeight,
                                                              kNumberHeight,
                                                              10);
          
          // Display line-sum indicators along the right margin:
          {
            long line_sum[card_height];
            long min_line_sum = LONG_MAX;
            long max_line_sum = 0;
            long line_sum_range;
            
            int left_edge = kSmallCharacterWidth * 3;  // there aren't usually any actual characters this far to the left
            int right_edge = (self.cardY.cvSize.width * 2) / 3;  // beyond here lie logos
            
            for (int row = card_height / 2; row < card_height; row++) {
              cvSetImageROI(sobelImage16.image, cvRect(left_edge, row, right_edge - left_edge, 1));
              line_sum[row] = (long)cvSum(sobelImage16.image).val[0];
              min_line_sum = MIN(min_line_sum, line_sum[row]);
              max_line_sum = MAX(max_line_sum, line_sum[row]);
            }
            cvResetImageROI(sobelImage16.image);
            
            line_sum_range = max_line_sum - min_line_sum;
            
            for (int row = card_height / 2; row < card_height; row++) {
              CvRect line_sum_rect = cvRect(self.cardY.cvSize.width - 50,
                                            row,
                                            50,
                                            1);
              double score = line_sum_range > 0.001 ? ((double)(line_sum[row] - min_line_sum)) / line_sum_range : 0.0;
              double dimmest_display = 50.0;
              cvRectangleR(sobelImage16.image, line_sum_rect, cvScalar((255.0 - dimmest_display) * score + dimmest_display, 0, 0, 0), CV_FILLED);
            }
          }
          
          // Display stripe indicators along the left margin:
          for (size_t index = 0; index < stripe_sums.size(); index++) {
            StripeSum stripe_sum = stripe_sums[index];
            CvRect stripe_rect = cvRect((int) (25 * index),
                                        stripe_sum.base_row,
                                        50,
                                        stripe_sum.height);
            cvRectangleR(sobelImage16.image, stripe_rect, cvScalar(255.0 * pow(0.8, index), 0, 0, 0), CV_FILLED);
          }
          
          cvConvertScale(sobelImage16.image, sobelImage.image);
          
          lastUpdated = [NSDate date];
        }
      
        UIImage *cardImage = [sobelImage UIImage];
        self.debugCardImage = [CardIOCardOverlay cardImage:cardImage withDisplayInfo:self.scanner.cardInfo annotated:NO];
      }
#endif
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
