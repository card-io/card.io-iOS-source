//
//  ShutterView.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#import "CardIOShutterView.h"
#import "CardIOCGGeometry.h"

#define RIGHT_ANGLE ((CGFloat) M_PI_2)


@interface ShutterLayer : CALayer

- (void)rotateToAngle:(CGFloat)angle;

@property(nonatomic, assign, readwrite) CGFloat openAngle;
@property(nonatomic, assign, readwrite) CGFloat closedAngle;

@end

@implementation ShutterLayer

- (id)init {
  if((self = [super init])) {
    self.backgroundColor = [UIColor darkGrayColor].CGColor;
  }
  return self;
}

- (void)rotateToAngle:(CGFloat)angle {
  self.transform = CATransform3DMakeRotation(angle, 0.0f, 0.0f, 1.0f);
}

@end



#pragma mark -

@interface CardIOShutterView ()

@property(nonatomic, strong, readwrite) ShutterLayer *left;
@property(nonatomic, strong, readwrite) ShutterLayer *bottom;
@property(nonatomic, strong, readwrite) ShutterLayer *right;
@property(nonatomic, strong, readwrite) ShutterLayer *top;

@end


#pragma mark -

@implementation CardIOShutterView

- (id)initWithFrame:(CGRect)aFrame {
  if((self = [super initWithFrame:aFrame])) {
    self.layer.masksToBounds = YES;

    _bottom = [ShutterLayer layer];
    _bottom.anchorPoint = CGPointMake(1, 1); // bottom right
    [self.layer addSublayer:_bottom];

    _right = [ShutterLayer layer];
    _right.anchorPoint = CGPointMake(1, 0); // top right
    [self.layer addSublayer:_right];

    _top = [ShutterLayer layer];
    _top.anchorPoint = CGPointMake(0, 0); // top left
    [self.layer addSublayer:_top];
    
    _left = [ShutterLayer layer];
    _left.anchorPoint = CGPointMake(0, 1); // bottom left
    [self.layer addSublayer:_left];

    [self updateTransforms];
    [self adjustShutters];

    self.userInteractionEnabled = NO;
  }
  return self;
}

- (void)layoutSubviews {
  [self updateTransforms];
}

- (void)updateTransforms {
  // In case self.bounds == CGZeroRect (as can happen during initialization),
  // let's generate reasonable initial values (particularly for the angles).
  CGFloat w = MAX(self.bounds.size.width, 1);
  CGFloat h = MAX(self.bounds.size.height, 1);
  
  CGFloat frameDiagonal = (CGFloat)ceil(sqrt(h * h + w * w));
  CGFloat theta = (CGFloat)atan(h / w);

  self.bottom.bounds = CGRectZeroWithSquareSize(frameDiagonal);
  self.bottom.position = CGPointMake(CGRectGetMaxX(self.bounds), CGRectGetMaxY(self.bounds));
  self.bottom.openAngle = -RIGHT_ANGLE;
  self.bottom.closedAngle = -RIGHT_ANGLE + theta;

  self.right.bounds = CGRectZeroWithSquareSize(frameDiagonal);
  self.right.position = CGPointMake(CGRectGetMaxX(self.bounds), CGRectGetMinY(self.bounds));
  self.right.openAngle = -RIGHT_ANGLE;
  self.right.closedAngle = -theta;

  self.top.bounds = CGRectZeroWithSquareSize(frameDiagonal);
  self.top.position = CGPointMake(CGRectGetMinX(self.bounds), CGRectGetMinY(self.bounds));
  self.top.openAngle = -RIGHT_ANGLE;
  self.top.closedAngle = -RIGHT_ANGLE + theta;

  self.left.bounds = CGRectZeroWithSquareSize(frameDiagonal);
  self.left.position = CGPointMake(CGRectGetMinX(self.bounds), CGRectGetMaxY(self.bounds));
  self.left.openAngle = -RIGHT_ANGLE;
  self.left.closedAngle = -theta;
}

- (void)adjustShutters {
  for(ShutterLayer *shutterLayer in @[self.bottom, self.right, self.top, self.left]) {
    CGFloat theta = _open ? shutterLayer.openAngle : shutterLayer.closedAngle;
    [shutterLayer rotateToAngle:theta];
  }
}

- (void)setOpen:(BOOL)shouldBeOpen animated:(BOOL)animated duration:(CFTimeInterval)duration {
  if(self.open != shouldBeOpen) {
    _open = shouldBeOpen;
    [CATransaction begin];
    [CATransaction setAnimationDuration:duration];
    [CATransaction setDisableActions:!animated];
    [self adjustShutters];
    [CATransaction commit];
  }
}

- (void)setOpen:(BOOL)shouldBeOpen {
  [self setOpen:shouldBeOpen animated:NO duration:0];
}

@end
