//
//  CardIOTransitionView.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#if USE_CAMERA || SIMULATE_CAMERA

#import "CardIOTransitionView.h"
#import "CardIOCGGeometry.h"
#import "CardIOStyles.h"
#import "CardIODataEntryViewController.h"


#define kFlashDuration 0.5f

@interface CardIOTransitionView () 

@property(nonatomic, strong, readwrite) UIImageView *cardView;
@property(nonatomic, strong, readwrite) UIView *whiteView;

@end


#pragma mark -

@implementation CardIOTransitionView

- (id)initWithFrame:(CGRect)frame cardImage:(UIImage *)cardImage transform:(CGAffineTransform)transform {
  self = [super initWithFrame:frame];
  if(self) {
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.backgroundColor = [UIColor blackColor];

    _cardView = [[UIImageView alloc] initWithImage:cardImage];
    _cardView.contentMode = UIViewContentModeScaleAspectFit;
    _cardView.backgroundColor = kColorViewBackground;

    _cardView.layer.masksToBounds = YES;
    _cardView.layer.borderColor = [UIColor grayColor].CGColor;
    _cardView.layer.borderWidth = 2.0f;
    _cardView.transform = transform;
    [self addSubview:_cardView];

    _whiteView = [[UIView alloc] init];
    _whiteView.backgroundColor = [UIColor whiteColor];
    _whiteView.alpha = 0.0f;
    [self addSubview:_whiteView];

    [self setNeedsLayout];
  }
  return self;
}

- (void)layoutSubviews {
  [super layoutSubviews];
  self.whiteView.frame = CGRectZeroWithSize(self.bounds.size);
  self.cardView.center = CGPointMake(self.bounds.size.width / 2.0f, self.bounds.size.height / 2.0f);
  
  CGFloat cardScale;
  if (UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)) {
    cardScale = MAX(self.bounds.size.width, self.bounds.size.height) * kLandscapeZoomedInCardImageSizePercent / self.cardView.image.size.width;
  }
  else {
    cardScale = self.bounds.size.width * kPortraitZoomedInCardImageSizePercent / self.cardView.image.size.width;
  }
  
  self.cardView.transform = CGAffineTransformScale(self.cardView.transform, cardScale, cardScale);
  self.cardView.layer.cornerRadius = ((CGFloat) 9.0f) * (self.cardView.bounds.size.width / ((CGFloat) 300.0f)); // matches the card, adjusted for view size. (view is ~300 px wide on phone.)
}

- (void)animateWithCompletion:(BareBlock)completionBlock {
  self.whiteView.alpha = 1.0f;
  [UIView animateWithDuration:kFlashDuration
                   animations:^{
                     self.whiteView.alpha = 0.0f;
                   }
                   completion:^(BOOL finished) {
                     completionBlock();
                   }];
}

@end

#endif
