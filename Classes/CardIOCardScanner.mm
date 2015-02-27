//
//  CardIOCardScanner.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#if USE_CAMERA

#import "CardIOCardScanner.h"
#import "CardIOIplImage.h"
#import "CardIOMacros.h"
#import "CardIOReadCardInfo.h"

#include "sobel.h"

#include "opencv2/imgproc/imgproc_c.h"
#include "morph.h"
#include <vector>

#define SCAN_FOREVER 0  // useful for debugging expiry

@interface CardIOCardScanner ()

// intentionally atomic -- card scanners get passed around between threads
@property(assign, readwrite) ScannerState scannerState;
@property(strong, readwrite) CardIOReadCardInfo *cardInfoCache;
@property(assign, readwrite) BOOL cardInfoCacheDirty;
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
     markFlipped:(BOOL)flipped
      scanExpiry:(BOOL)scanExpiry {

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
  scanner_add_frame_with_expiry(&_scannerState, y.image, scanExpiry, &result);
  self.lastFrameWasUsable = result.usable;
  if(!result.usable) {
    self.lastFrameWasUpsideDown = result.upside_down;
  }
  [self markCachesDirty];
}

- (BOOL)complete {
#if SCAN_FOREVER
  return false;
#endif
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
      NSString *cardNumber = nil;
      self.scanIsComplete = YES;
      NSMutableArray *numbers = [NSMutableArray arrayWithCapacity:result.n_numbers];
      for(uint8_t i = 0; i < result.n_numbers; i++) {
        NSNumber *predictionNumber = [NSNumber numberWithInt:(int)result.predictions(i)];
        [numbers addObject:predictionNumber];
      }
      cardNumber = [numbers componentsJoinedByString:@""];

#if CARDIO_DEBUG
      NSMutableArray *expiryGroupedRects = [[NSMutableArray alloc] init];
      for (GroupedRectsListIterator group = result.expiry_groups.begin(); group != result.expiry_groups.end(); ++group) {
        NSMutableArray *rects = [[NSMutableArray alloc] init];
        for (CharacterRectListIterator rect = group->character_rects.begin(); rect != group->character_rects.end(); ++rect) {
          [rects addObject:@{@"left" : @(rect->left), @"top" : @(rect->top), @"finalImage" : [NSValue valueWithPointer:rect->final_image]}];
        }
        [expiryGroupedRects addObject:@{@"left" : @(group->left),
                                        @"top" : @(group->top),
                                        @"width" : @(group->width),
                                        @"height" : @(group->height),
                                        @"characterRects" : rects,
                                        @"recentlySeenCount" : @(group->recently_seen_count)
         }];
      }

      NSMutableArray *nameGroupedRects = [[NSMutableArray alloc] init];
      for (GroupedRectsListIterator group = result.name_groups.begin(); group != result.name_groups.end(); ++group) {
        NSMutableArray *rects = [[NSMutableArray alloc] init];
        for (CharacterRectListIterator rect = group->character_rects.begin(); rect != group->character_rects.end(); ++rect) {
          [rects addObject:@{@"left" : @(rect->left), @"top" : @(rect->top)}];
        }
        [nameGroupedRects addObject:@{@"left" : @(group->left),
         @"top" : @(group->top),
         @"width" : @(group->width),
         @"height" : @(group->height),
         @"characterRects" : rects}];
      }
#endif

      NSMutableArray *xOffsets = [NSMutableArray arrayWithCapacity:result.hseg.n_offsets];
      for(uint8_t i = 0; i < result.hseg.n_offsets; i++) {
        NSNumber *xOffset = [NSNumber numberWithUnsignedShort:result.hseg.offsets[i]];
        [xOffsets addObject:xOffset];
      }

      self.cardInfoCache = [CardIOReadCardInfo cardInfoWithNumber:cardNumber
                                                         xOffsets:xOffsets
                                                          yOffset:result.vseg.y_offset
                                                      expiryMonth:result.expiry_month
                                                       expiryYear:result.expiry_year
#if CARDIO_DEBUG
                                               expiryGroupedRects:expiryGroupedRects
                                                 nameGroupedRects:nameGroupedRects
#endif
                            ];
    } else {
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
     markFlipped:(BOOL)flipped
      scanExpiry:(BOOL)scanExpiry {}

- (BOOL)complete {
  return (self.cardInfo != nil);
}

- (CardIOReadCardInfo *)cardInfo {
  if (_considerItScanned) {
    return [CardIOReadCardInfo cardInfoWithNumber:@"4567891234567898"
                                         xOffsets:[NSArray arrayWithObjects:@40,@60,@80,@100, @130,@150,@170,@190, @220,@240,@260,@280, @310,@330,@350,@370, nil]
                                          yOffset:100
                                      expiryMonth:0
                                       expiryYear:0
#if CARDIO_DEBUG
                               expiryGroupedRects:nil
                                 nameGroupedRects:nil
#endif
            ];
  }
  else {
    return nil;
  }
}

@end

#endif