//
//  CardIOCardOverlay.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#if USE_CAMERA || SIMULATE_CAMERA

#import "CardIOCardOverlay.h"
#import "CardIOVideoFrame.h"
#import "CardIOCGGeometry.h"
#import "CardIOReadCardInfo.h"
#import "CardIOMacros.h"
#import "dmz_constants.h"

#if CARDIO_DEBUG && !SIMULATE_CAMERA
#import "CardIOIplImage.h"
#endif

#define kNumberBottomMargin 8
#define kImageScale 2.0f

@implementation CardIOCardOverlay

+ (UIImage *)cardImage:(UIImage *)cardImage withDisplayInfo:(CardIOReadCardInfo *)cardInfo annotated:(BOOL)shouldAnnotate {
  if(!cardInfo) {
    return cardImage;
  }
  
  if(cardInfo.isFlipped) {
    cardImage = [UIImage imageWithCGImage:cardImage.CGImage scale:1.0 orientation:UIImageOrientationDown];
  }

  CGSize contextSize = CGSizeByScaling(cardImage.size, kImageScale);
  UIGraphicsBeginImageContext(contextSize);
  CGContextRef context = UIGraphicsGetCurrentContext();

  CGContextScaleCTM(context, kImageScale, kImageScale);
  
  [cardImage drawAtPoint:CGPointZero];
  
  [[UIColor blackColor] setStroke];
  [[UIColor whiteColor] setFill];
  
  CGFloat centerX = cardImage.size.width / 2.0f;
  CGFloat centerY = cardImage.size.height / 2.0f;
  CGContextTranslateCTM(context, centerX, centerY);
  
  CGFloat scaleX = cardImage.size.width / kCreditCardTargetWidth;
  CGFloat scaleY = cardImage.size.height / kCreditCardTargetHeight;
  CGContextScaleCTM(context, scaleX, scaleY);
  CGContextTranslateCTM(context, -kCreditCardTargetWidth / 2.0, -kCreditCardTargetHeight / 2.0);
  
  if (shouldAnnotate) {

    UIFont *font = [UIFont boldSystemFontOfSize:28.0f];

    CGContextSetTextDrawingMode(context, kCGTextFillStroke);
    CGContextSetLineWidth(context, 0.5f);

    CGFloat y_offset = (CGFloat)cardInfo.yOffset - kNumberBottomMargin;
    NSUInteger numberLength = [cardInfo.numbers length];
    for(int i = 0; i < numberLength; i++) {
      CGFloat x_offset = [cardInfo.xOffsets[i] floatValue];
      NSString *number = [cardInfo.numbers substringWithRange:NSMakeRange(i, 1)];
      CGRect numberRect = CGRectMake(x_offset, y_offset - kNumberHeight, kNumberWidth, kNumberHeight);
      [number drawInRect:numberRect withFont:font lineBreakMode:NSLineBreakByTruncatingTail alignment:NSTextAlignmentCenter];
    }
  }
  
#if CARDIO_DEBUG && !SIMULATE_CAMERA
  CGContextSetLineWidth(context, 1);

  CGFloat recentlySeenMax = 0;
  for (NSDictionary *group in cardInfo.expiryGroupedRects) {
    recentlySeenMax = MAX(recentlySeenMax, (CGFloat)MIN(10.0f, ((NSNumber *)group[@"recentlySeenCount"]).floatValue));
  }

  NSArray *expiryGroupedRects = [cardInfo.expiryGroupedRects sortedArrayUsingComparator:
                                 ^NSComparisonResult(NSDictionary *group1, NSDictionary *group2) {
                                   if ([group1[@"characterRects"] count]  > [group2[@"characterRects"] count]) {
                                     return (NSComparisonResult)NSOrderedDescending;
                                   }
                                   if ([group1[@"characterRects"] count]  < [group2[@"characterRects"] count]) {
                                     return (NSComparisonResult)NSOrderedAscending;
                                   }
                                   return (NSComparisonResult)NSOrderedSame;
                                 }];

  for (NSDictionary *group in expiryGroupedRects) {
    CGFloat alpha = (CGFloat)MIN(10.0, ((NSNumber *)group[@"recentlySeenCount"]).floatValue) / recentlySeenMax;
    CGContextSetAlpha(context, alpha);

    [[UIColor redColor] setStroke];
    CGRect displayRect = CGRectMake(((NSNumber *)group[@"left"]).floatValue - 1, ((NSNumber *)group[@"top"]).floatValue - 1, ((NSNumber *)group[@"width"]).floatValue + 2, ((NSNumber *)group[@"height"]).floatValue + 2);
    CGContextStrokeRect(context, displayRect);

    [[UIColor yellowColor] setStroke];
    NSArray *characterRects = (NSArray *)group[@"characterRects"];
    for (NSDictionary *characterRect in characterRects) {
      displayRect = CGRectMake(((NSNumber *)characterRect[@"left"]).floatValue, ((NSNumber *)characterRect[@"top"]).floatValue, 9, 15); // 9, 15 == kSmallCharacterWidth, kSmallCharacterHeight
      CGContextStrokeRect(context, displayRect);
    }
  }
  
  CGContextSetAlpha(context, 1.0);
  [[UIColor blueColor] setStroke];
  for (NSDictionary *group in cardInfo.nameGroupedRects) {
    CGRect displayRect = CGRectMake(((NSNumber *)group[@"left"]).floatValue - 2, ((NSNumber *)group[@"top"]).floatValue - 2, ((NSNumber *)group[@"width"]).floatValue + 4, ((NSNumber *)group[@"height"]).floatValue + 4);
    CGContextStrokeRect(context, displayRect);
  }
#endif
  
  UIImage *renderedImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  
  return renderedImage;
}

@end

#endif
