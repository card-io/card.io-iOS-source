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
  
  UIImage *renderedImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  
  return renderedImage;
}

@end

#endif
