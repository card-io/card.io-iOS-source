//
//  CardIOResource.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#import "CardIOMacros.h"
#import "CardIOResource.h"
#import "CardIOCGGeometry.h"

#import "CardIODevice.h"

#define kBoltDefaultWidth 13.0f
#define kBoltDefaultHeight 20.0f
#define kChevronDefaultWidth 30.0f
#define kChevronDefaultHeight 20.0f
#define kImageScale 2.0f

@interface CardIOResource ()

+ (UIImage *)lightningBoltImageWithHeight:(CGFloat)height fillColor:(UIColor *)fillColor;

@end

@implementation CardIOResource

// Create a lightButton

+ (UIButton *) lightButton {
  UIButton *lightButton = [UIButton buttonWithType:UIButtonTypeCustom];
  lightButton.layer.cornerRadius = 4.0f;
  lightButton.layer.masksToBounds = YES;
  lightButton.layer.borderWidth = 1.0f;
  lightButton.layer.borderColor = [UIColor colorWithWhite:0.0f alpha:0.8f].CGColor;

  lightButton.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.3f];
  lightButton.showsTouchWhenHighlighted = YES;
  lightButton.adjustsImageWhenHighlighted = NO;
  lightButton.contentEdgeInsets = UIEdgeInsetsMake(3.0f, 16.0f, 3.0f, 16.0f);
  
  [lightButton setImage:[self boltImageForTorchOn:NO] forState:UIControlStateNormal];
  [lightButton sizeToFit];

  return lightButton;
}

// Create a lightning bolt image as "on" or "off".

+ (UIImage *)boltImageForTorchOn:(BOOL)torchIsOn {
  UIColor *torchColor = torchIsOn ? [UIColor whiteColor] : [UIColor colorWithWhite:0.0f alpha:1.0f];
  return [self lightningBoltImageWithHeight:30.0f fillColor:torchColor];
}

// Create a lightning bolt image

+ (UIImage *)lightningBoltImageWithHeight:(CGFloat)height fillColor:(UIColor *)fillColor {
  CGFloat width = kImageScale * height * (kBoltDefaultWidth / kBoltDefaultHeight);
  height *= kImageScale;
  CGSize size = CGSizeMake(width, height);
  
  UIGraphicsBeginImageContext(size);
  CGContextRef context = UIGraphicsGetCurrentContext();
  
  CGContextSetAllowsAntialiasing(context, YES);
  
  CGContextScaleCTM(context, width / kBoltDefaultWidth, height / kBoltDefaultHeight);
  [fillColor setFill];
  
  const CGPoint lightningBoltPoints[] = {
    CGPointMake(10.0f,  0.0f), // top
    CGPointMake( 0.0f, 11.0f), // left
    CGPointMake( 6.0f, 11.0f), // left indent
    CGPointMake( 2.0f, 20.0f), // bottom
    CGPointMake(13.0f,  8.0f), // right
    CGPointMake( 7.0f,  8.0f), // right indent
    CGPointMake(10.0f,  0.0f)  // top
  };
  CGContextAddLines(context, lightningBoltPoints, sizeof(lightningBoltPoints) / sizeof(CGPoint));
  CGContextDrawPath(context, kCGPathFill);
  
  UIImage *renderedImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  
  UIImage *scaledImage = [UIImage imageWithCGImage:renderedImage.CGImage scale:kImageScale orientation:UIImageOrientationUp];
  return scaledImage;
}

@end
