//
//  CardIOCardScanner.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#if USE_CAMERA

#import "CardIOCardScanner.h"
#import "CardIOIplImage.h"
#import "CardIOMacros.h"
#import "CardIOReadCardInfo.h"

@interface CardIOCardScanner ()

// intentionally atomic -- card scanners get passed around between threads
@property(assign, readwrite) ScannerState scannerState;
@property(strong, readwrite) CardIOReadCardInfo *cardInfoCache;
@property(assign, readwrite) BOOL cardInfoCacheDirty;
@property(strong, readwrite) NSArray *xOffsets;
@property(assign, readwrite) uint16_t yOffset;
@property(assign, readwrite) BOOL lastFrameWasUsable;
@property(assign, readwrite) BOOL lastFrameWasUpsideDown;
@property(assign, readwrite) BOOL scanIsComplete;

- (void)markCachesDirty;

@end

@implementation CardIOCardScanner

- (void)markCachesDirty {
  self.cardInfoCacheDirty = YES;
}

- (id)init {
  if((self = [super init])) {
    scanner_initialize(&_scannerState);
    [self markCachesDirty];
  }
  return self;
}

- (void)reset {
  scanner_reset(&_scannerState);
  [self markCachesDirty];
}

- (void)addFrame:(CardIOIplImage *)y
      focusScore:(float)focusScore
 brightnessScore:(float)brightnessScore
        isoSpeed:(NSInteger)isoSpeed
    shutterSpeed:(float)shutterSpeed
       torchIsOn:(BOOL)torchIsOn
     markFlipped:(BOOL)flipped {

  if (self.scanIsComplete) {
    return;
  }
  
  FrameScanResult result;
  
  // A little bit of a hack, but we prepopulate focusScore and brightness information
  result.focus_score = focusScore;
  result.brightness_score = brightnessScore;
  result.iso_speed = (uint16_t)isoSpeed;
  result.shutter_speed = shutterSpeed;
  result.torch_is_on = torchIsOn;
  
  result.flipped = flipped;
  scanner_add_frame(&_scannerState, y.image, &result);
  self.lastFrameWasUsable = result.usable;
  if(result.usable) {
    NSMutableArray *x = [NSMutableArray arrayWithCapacity:result.hseg.n_offsets];
    for(uint8_t i = 0; i < result.hseg.n_offsets; i++) {
      NSNumber *xOffset = [NSNumber numberWithUnsignedShort:result.hseg.offsets[i]];
      [x addObject:xOffset];
    }
    self.xOffsets = x;
    self.yOffset = result.vseg.y_offset;
  } else {
    self.lastFrameWasUpsideDown = result.upside_down;
    self.xOffsets = nil;
    self.yOffset = 0;
  }
  [self markCachesDirty];
}

- (BOOL)complete {
  return (self.cardInfo != nil);
}

- (CardIOReadCardInfo *)cardInfo {
  if (self.scanIsComplete) {
    return self.cardInfoCache;
  }
  
  if(!self.lastFrameWasUsable) {
    return nil;
  }

  if(self.cardInfoCacheDirty) {
    ScannerResult result;
    scanner_result(&_scannerState, &result);
    if(result.complete) {
      self.scanIsComplete = YES;
      NSMutableArray *numbers = [NSMutableArray arrayWithCapacity:result.n_numbers];
      for(uint8_t i = 0; i < result.n_numbers; i++) {
        NSNumber *predictionNumber = [NSNumber numberWithInt:(int)result.predictions(i)];
        [numbers addObject:predictionNumber];
      }
      NSString *cardNumber = [numbers componentsJoinedByString:@""];
      self.cardInfoCache = [CardIOReadCardInfo cardInfoWithNumber:cardNumber xOffsets:self.xOffsets yOffset:self.yOffset];
    }
    else {
      self.cardInfoCache = nil;
    }

    self.cardInfoCacheDirty = NO;
  }

  return self.cardInfoCache;
}

- (ScanSessionAnalytics *)scanSessionAnalytics {
  return &_scannerState.session_analytics;
}

- (void)dealloc {
  scanner_destroy(&_scannerState);
}

@end

#elif SIMULATE_CAMERA

#import "CardIOCardScanner.h"
#import "CardIOReadCardInfo.h"
@implementation CardIOCardScanner
@synthesize lastFrameWasUpsideDown;

- (void)reset {}
- (void)addFrame:(CardIOIplImage *)y
      focusScore:(float)focusScore
 brightnessScore:(float)brightnessScore
        isoSpeed:(NSInteger)isoSpeed
    shutterSpeed:(float)shutterSpeed
       torchIsOn:(BOOL)torchIsOn
     markFlipped:(BOOL)flipped {}

- (BOOL)complete {
  return (self.cardInfo != nil);
}

- (CardIOReadCardInfo *)cardInfo {
  if (_considerItScanned) {
    return [CardIOReadCardInfo cardInfoWithNumber:@"4567891234567898"
                                         xOffsets:[NSArray arrayWithObjects:@40,@60,@80,@100, @130,@150,@170,@190, @220,@240,@260,@280, @310,@330,@350,@370, nil]
                                          yOffset:100];
  }
  else {
    return nil;
  }
}

@end

#endif