//
//  CardIOModalActivityIndicator.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#import "CardIOModalActivityIndicator.h"
#import "CardIOCGGeometry.h"

#define kModalSize 160.0f
#define kCornerRadius 20.0f
#define kLabelHeight 30.0f
#define kLabelFont [UIFont boldSystemFontOfSize:15.0f]
#define kModalColor [UIColor colorWithWhite:0.3f alpha:0.8f]
#define kStartingScale 1.8f
#define kAnimationDuration 0.35f

#pragma mark -

@interface CardIOModalActivityIndicator ()

@property(nonatomic, strong, readwrite) UIActivityIndicatorView *spinner;

@end


#pragma mark -

@implementation CardIOModalActivityIndicator

@synthesize spinner;

- (id)initWithText:(NSString *)text {
  if((self = [super initWithFrame:CGRectZero])) {
    CGSize keyWindowSize = [UIScreen mainScreen].bounds.size;
    CGPoint keyWindowCenter = CGPointMake(keyWindowSize.width / 2.0f, keyWindowSize.height / 2.0f);
    
    self.bounds = CGRectZeroWithSize(keyWindowSize);
    self.backgroundColor = [UIColor clearColor];
    
    CALayer *backgroundLayer = [CALayer layer];
    backgroundLayer.cornerRadius = kCornerRadius;
    backgroundLayer.masksToBounds = YES;
    backgroundLayer.bounds = CGRectMake(0.0f, 0.0f, kModalSize, kModalSize);
    backgroundLayer.position = keyWindowCenter;
    backgroundLayer.backgroundColor = kModalColor.CGColor;
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(keyWindowCenter.x - kModalSize / 2.0f,
                                                                keyWindowCenter.y + kModalSize / 2.0f - kLabelHeight - 5,
                                                                kModalSize,
                                                                kLabelHeight)];
    label.text = text;
    label.textColor = [UIColor whiteColor];
    label.backgroundColor = [UIColor clearColor];
    label.font = kLabelFont;
    label.textAlignment = NSTextAlignmentCenter;
    self.spinner = [[UIActivityIndicatorView alloc] initWithFrame:CGRectZero];
    self.spinner.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
    [self.spinner sizeToFit];
    self.spinner.hidesWhenStopped = NO;
    
    self.spinner.center = CGPointMake(self.bounds.size.width/2, self.bounds.size.height/2);
    
    [self.layer addSublayer:backgroundLayer];
    [self addSubview:label];
    [self addSubview:self.spinner];    
    
    self.transform = CGAffineTransformMakeScale(kStartingScale, kStartingScale);
  }
  return self;
}

- (void)animationDidStop:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context {
  [self.spinner startAnimating];
}

- (void)show {
  [self showInView:[[UIApplication sharedApplication] keyWindow]];
}

- (void)showInView:(UIView*) view {
  
  CGRect screenBounds = [[UIScreen mainScreen] bounds];
  CGPoint screenCenter = CGPointMake(screenBounds.size.width/2, screenBounds.size.height/2);
  self.center = [view convertPoint:screenCenter fromView:nil];
  
  [view addSubview:self];
  [UIView beginAnimations:@"modalSpinner" context:NULL];
  self.transform = CGAffineTransformIdentity;
  [UIView setAnimationDuration:kAnimationDuration];
  [UIView setAnimationDelegate:self];
  [UIView setAnimationDidStopSelector:@selector(animationDidStop:finished:context:)];
  [UIView commitAnimations];
  [[UIApplication sharedApplication] beginIgnoringInteractionEvents];
}

- (void)dismiss {
  [[UIApplication sharedApplication] endIgnoringInteractionEvents];
  [self removeFromSuperview];
}


@end
