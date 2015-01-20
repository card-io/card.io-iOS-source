//
//  CardGuideOverlayView.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#if USE_CAMERA || SIMULATE_CAMERA

#import "CardIOGuideLayer.h"
#import "CardIOViewController.h"
#import "CardIOCGGeometry.h"
#import "CardIOVideoFrame.h"
#import "CardIODmzBridge.h"
#import "CardIOMacros.h"
#import "CardIOAnimation.h"
#import "CardIOOrientation.h"
#import "CardIOCGGeometry.h"

#pragma mark - Colors

#define kStandardMinimumBoundsWidth 300.0f
#define kStandardLineWidth 12.0f
#define kStandardCornerSize 50.0f
#define kAdjustFudge 0.2f  // Because without this, we see a mini gap between edge path and corner path.

#define kEdgeDecay 0.5f
#define kEdgeOnThreshold 0.7f
#define kEdgeOffThreshold 0.3f

#define kAllEdgesFoundScoreDecay 0.5f
#define kNumEdgesFoundScoreDecay 0.5f

#pragma mark - Types

typedef enum { 
  kTopLeft,
  kTopRight,
  kBottomLeft,
  kBottomRight,
} CornerPositionType;

#pragma mark - Interface

@interface CardIOGuideLayer ()

@property(nonatomic, weak, readwrite) id<CardIOGuideLayerDelegate> guideLayerDelegate;
@property(nonatomic, strong, readwrite) CAShapeLayer *backgroundOverlay;
@property(nonatomic, strong, readwrite) CAShapeLayer *topLayer;
@property(nonatomic, strong, readwrite) CAShapeLayer *bottomLayer;
@property(nonatomic, strong, readwrite) CAShapeLayer *leftLayer;
@property(nonatomic, strong, readwrite) CAShapeLayer *rightLayer;
@property(nonatomic, strong, readwrite) CAShapeLayer *topLeftLayer;
@property(nonatomic, strong, readwrite) CAShapeLayer *topRightLayer;
@property(nonatomic, strong, readwrite) CAShapeLayer *bottomLeftLayer;
@property(nonatomic, strong, readwrite) CAShapeLayer *bottomRightLayer;
@property(nonatomic, assign, readwrite) BOOL guidesLockedOn;
@property(nonatomic, assign, readwrite) float edgeScoreTop;
@property(nonatomic, assign, readwrite) float edgeScoreRight;
@property(nonatomic, assign, readwrite) float edgeScoreBottom;
@property(nonatomic, assign, readwrite) float edgeScoreLeft;
@property(nonatomic, assign, readwrite) float allEdgesFoundDecayedScore;
@property(nonatomic, assign, readwrite) float numEdgesFoundDecayedScore;

#if CARDIO_DEBUG
@property(nonatomic, strong, readwrite) CALayer *debugOverlay;
#endif
@end


#pragma mark - Implementation

@implementation CardIOGuideLayer

- (id)initWithDelegate:(id<CardIOGuideLayerDelegate>)guideLayerDelegate {
  if((self = [super init])) {
    _guideLayerDelegate = guideLayerDelegate;
    
    _deviceOrientation = UIDeviceOrientationPortrait;

    _guidesLockedOn = NO;
    _edgeScoreTop = 0.0f;
    _edgeScoreRight = 0.0f;
    _edgeScoreBottom = 0.0f;
    _edgeScoreLeft = 0.0f;

    _allEdgesFoundDecayedScore = 0.0f;
    _numEdgesFoundDecayedScore = 0.0f;

    _fauxCardLayer = [CAGradientLayer layer];
    _topLayer = [CAShapeLayer layer];
    _bottomLayer = [CAShapeLayer layer];
    _leftLayer = [CAShapeLayer layer];
    _rightLayer = [CAShapeLayer layer];
    
    _topLeftLayer = [CAShapeLayer layer];
    _topRightLayer = [CAShapeLayer layer];
    _bottomLeftLayer = [CAShapeLayer layer];
    _bottomRightLayer = [CAShapeLayer layer];
    
    _fauxCardLayer.cornerRadius = 0.0f;
    _fauxCardLayer.masksToBounds = YES;
    _fauxCardLayer.borderWidth = 0.0f;
    
    _fauxCardLayer.startPoint = CGPointMake(0.5f, 0.0f); // top center
    _fauxCardLayer.endPoint = CGPointMake(0.5f, 1.0f); // bottom center
    _fauxCardLayer.locations = [NSArray arrayWithObjects:
                                [NSNumber numberWithFloat:0.0f],
                                [NSNumber numberWithFloat:1.0f],
                                nil];
    _fauxCardLayer.colors = [NSArray arrayWithObjects:
                             (id)[UIColor colorWithWhite:1.0f alpha:0.2f].CGColor,
                             (id)[UIColor colorWithWhite:0.0f alpha:0.2f].CGColor,
                             nil];
    [self addSublayer:_fauxCardLayer];

    _backgroundOverlay = [CAShapeLayer layer];
    _backgroundOverlay.cornerRadius = 0.0f;
    _backgroundOverlay.masksToBounds = YES;
    _backgroundOverlay.borderWidth = 0.0f;
    _backgroundOverlay.fillColor = [UIColor colorWithWhite:0.0f alpha:0.7f].CGColor;
    [self addSublayer:_backgroundOverlay];

#if CARDIO_DEBUG
    _debugOverlay = [CALayer layer];
    _debugOverlay.cornerRadius = 0.0f;
    _debugOverlay.masksToBounds = YES;
    _debugOverlay.borderWidth = 0.0f;
    [self addSublayer:_debugOverlay];
#endif
    
    NSArray *edgeLayers = [NSArray arrayWithObjects:
                           _topLayer,
                           _bottomLayer,
                           _leftLayer,
                           _rightLayer,
                           _topLeftLayer,
                           _topRightLayer,
                           _bottomLeftLayer,
                           _bottomRightLayer,
                           nil];
    
    for(CAShapeLayer *layer in edgeLayers) {
      layer.frame = CGRectZeroWithSize(self.bounds.size);
      layer.lineCap = kCALineCapButt;
      layer.lineWidth = [self lineWidth];
      layer.fillColor = [UIColor clearColor].CGColor;
      layer.strokeColor = kDefaultGuideColor.CGColor;
      
      [self addSublayer:layer];
    }
    
    // setting the capture frame here serves to initialize the remaining shapelayer properties
    _videoFrame = nil;

    [self setNeedsLayout];
  }
  return self;
}

+ (CGPathRef)newPathFromPoint:(CGPoint)firstPoint toPoint:(CGPoint)secondPoint {
  CGMutablePathRef path = CGPathCreateMutable();
  CGPathMoveToPoint(path, NULL, firstPoint.x, firstPoint.y);
  CGPathAddLineToPoint(path, NULL, secondPoint.x, secondPoint.y);
  return path;
}

+ (CGPathRef)newCornerPathFromPoint:(CGPoint)point size:(CGFloat)size positionType:(CornerPositionType)posType {
#if __LP64__
  size = fabs(size);
#else
  size = fabsf(size);
#endif
  CGMutablePathRef path = CGPathCreateMutable();
  CGPoint pStart = point, 
          pEnd = point;
  
  // All this assumes phone is turned horizontally, to widescreen mode
  switch (posType) {
    case kTopLeft:
      pStart.x -= size;
      pEnd.y += size;
      break;
    case kTopRight:
      pStart.x -= size;
      pEnd.y -= size;
      break;
    case kBottomLeft:
      pStart.x += size;
      pEnd.y += size;
      break;
    case kBottomRight:
      pStart.x += size;
      pEnd.y -= size;
      break;
    default:
      break;
  }
  CGPathMoveToPoint(path, NULL, pStart.x, pStart.y);
  CGPathAddLineToPoint(path, NULL, point.x, point.y);
  CGPathAddLineToPoint(path, NULL, pEnd.x, pEnd.y);
  return path;
}

- (CGPathRef)newMaskPathForGuideFrame:(CGRect)guideFrame outerFrame:(CGRect)frame {

  CGMutablePathRef path = CGPathCreateMutable();

  CGPathMoveToPoint(path, NULL, frame.origin.x, frame.origin.y);
  CGPathAddLineToPoint(path, NULL, frame.origin.x + frame.size.width, frame.origin.y);
  CGPathAddLineToPoint(path, NULL, frame.origin.x + frame.size.width, frame.origin.y + frame.size.height);
  CGPathAddLineToPoint(path, NULL, frame.origin.x, frame.origin.y + frame.size.height);

  CGPathMoveToPoint(path, NULL, guideFrame.origin.x, guideFrame.origin.y);
  CGPathAddLineToPoint(path, NULL, guideFrame.origin.x, guideFrame.origin.y + guideFrame.size.height);
  CGPathAddLineToPoint(path, NULL, guideFrame.origin.x + guideFrame.size.width, guideFrame.origin.y + guideFrame.size.height);
  CGPathAddLineToPoint(path, NULL, guideFrame.origin.x + guideFrame.size.width, guideFrame.origin.y);

  return path;
}

- (CGFloat)sizeForBounds:(CGFloat)standardSize {
  if (self.bounds.size.width == 0 || self.bounds.size.width >= kStandardMinimumBoundsWidth) {
    return standardSize;
  }
  else {
#if __LP64__
    return ceil(standardSize * self.bounds.size.width / kStandardMinimumBoundsWidth);
#else
    return ceilf(standardSize * self.bounds.size.width / kStandardMinimumBoundsWidth);
#endif
  }
}

- (CGFloat)lineWidth {
  return [self sizeForBounds:kStandardLineWidth];
}

- (CGFloat)cornerSize {
  return [self sizeForBounds:kStandardCornerSize];
}

- (CGPoint)landscapeVEdgeAdj {
  return CGPointMake([self cornerSize] - kAdjustFudge, 0.0f);
}

- (CGPoint)landscapeHEdgeAdj {
  return CGPointMake(0.0f, [self cornerSize] - kAdjustFudge);
}

// Animate edge layer
- (void)animateEdgeLayer:(CAShapeLayer *)layer 
         toPathFromPoint:(CGPoint)firstPoint 
                 toPoint:(CGPoint)secondPoint 
         adjustedBy:(CGPoint)adjPoint {
  layer.lineWidth = [self lineWidth];
  
  firstPoint = CGPointMake(firstPoint.x + adjPoint.x, firstPoint.y + adjPoint.y);
  secondPoint = CGPointMake(secondPoint.x - adjPoint.x, secondPoint.y - adjPoint.y); 
  CGPathRef newPath = [[self class] newPathFromPoint:firstPoint toPoint:secondPoint];
  [self animateLayer:layer toNewPath:newPath];

  // I used to see occasional crashes stemming from this CGPathRelease. I'm restoring it,
  // since I can no longer reproduce the crashes, and it is a memory leak otherwise. :)
  CGPathRelease(newPath);
}

- (void)animateCornerLayer:(CAShapeLayer *)layer atPoint:(CGPoint)point withPositionType:(CornerPositionType)posType {
  layer.lineWidth = [self lineWidth];
  
  CGPathRef newPath = [[self class] newCornerPathFromPoint:point size:[self cornerSize] positionType:posType];
  [self animateLayer:layer toNewPath:newPath];

  // See above comment on crashes. Same probably applies here. - BPF
  CGPathRelease(newPath);
}

// Animate the layer to a new path.
- (void)animateLayer:(CAShapeLayer *)layer toNewPath:(CGPathRef)newPath {
  if(layer.path) {
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"path"];
    animation.fromValue = (id)layer.path;
    animation.toValue = (__bridge id)newPath;
    animation.duration = self.animationDuration;
    [layer addAnimation:animation forKey:@"animatePath"];
    layer.path = newPath;
  } else {
    SuppressCAAnimation(^{
      layer.path = newPath;
    });
  }
}

- (void)animateFauxCardLayerToFrame:(CGRect)guideFrame {
  // TODO: Use CAAnimationGroup?
  if(CGRectIsEmpty(self.fauxCardLayer.frame)) {
    SuppressCAAnimation(^{
      self.fauxCardLayer.frame = guideFrame;
    });
  } else {
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"frame"];
    self.fauxCardLayer.frame = guideFrame;
    animation.fromValue = (id)[NSValue valueWithCGRect:self.fauxCardLayer.frame];
    animation.toValue = (id)[NSValue valueWithCGRect:guideFrame];
    animation.duration = self.animationDuration;
    [self.fauxCardLayer addAnimation:animation forKey:@"animateFrame"];
    self.fauxCardLayer.frame = guideFrame;
  }
  
  CGPoint gradientStart = CGPointZero;
  CGPoint gradientEnd = CGPointZero;
  switch (self.deviceOrientation) {
    case UIDeviceOrientationPortrait:
      gradientStart = CGPointMake(0.5f, 0.0f); // top center
      gradientEnd = CGPointMake(0.5f, 1.0f); // bottom center
      break;
    case UIDeviceOrientationPortraitUpsideDown:
      gradientStart = CGPointMake(0.5f, 1.0f); // bottom center
      gradientEnd = CGPointMake(0.5f, 0.0f); // top center
      break;
    case UIDeviceOrientationLandscapeLeft:
      gradientStart = CGPointMake(1.0f, 0.5f);
      gradientEnd = CGPointMake(0.0f, 0.5f);
      break;
    case UIDeviceOrientationLandscapeRight:
      gradientStart = CGPointMake(0.0f, 0.5f);
      gradientEnd = CGPointMake(1.0f, 0.5f);
      break;
    default:
      break;
  }
  self.fauxCardLayer.startPoint = gradientStart;
  self.fauxCardLayer.endPoint = gradientEnd;
}

- (void)animateCardMask:(CGRect)guideFrame {
  SuppressCAAnimation(^{
    self.backgroundOverlay.frame = self.bounds;
  });
  CGPathRef path = [self newMaskPathForGuideFrame:guideFrame outerFrame:self.bounds];
  [self animateLayer:self.backgroundOverlay toNewPath:path];
  CGPathRelease(path);
}

- (void)setLayerPaths {
  CGRect guideFrame = [self guideFrame];
  if(CGRectIsEmpty(guideFrame)) {
    // don't set an empty guide frame -- this helps keep the animations clean, so that
    // we never animate to or from an empty frame, which looks odd.
    return;
  }
  
  CGPoint portraitTopLeft = CGPointMake(CGRectGetMinX(guideFrame), CGRectGetMinY(guideFrame));
  CGPoint portraitTopRight = CGPointMake(CGRectGetMaxX(guideFrame), CGRectGetMinY(guideFrame));
  CGPoint portraitBottomLeft = CGPointMake(CGRectGetMinX(guideFrame), CGRectGetMaxY(guideFrame));
  CGPoint portraitBottomRight = CGPointMake(CGRectGetMaxX(guideFrame), CGRectGetMaxY(guideFrame));
  
  // All following code assumes a permanent UIInterfaceOrientationLandscapeRight -- adjust from
  // UIInterfaceOrientationPortrait, which is easiest to think about.
  
  CGPoint topLeft = portraitTopRight;
  CGPoint topRight = portraitBottomRight;
  CGPoint bottomLeft = portraitTopLeft;
  CGPoint bottomRight = portraitBottomLeft;
  
  [self animateEdgeLayer:self.topLayer toPathFromPoint:topLeft toPoint:topRight adjustedBy:[self landscapeHEdgeAdj]];
  [self animateEdgeLayer:self.bottomLayer toPathFromPoint:bottomLeft toPoint:bottomRight adjustedBy:[self landscapeHEdgeAdj]];
  [self animateEdgeLayer:self.leftLayer toPathFromPoint:bottomLeft toPoint:topLeft adjustedBy:[self landscapeVEdgeAdj]];
  [self animateEdgeLayer:self.rightLayer toPathFromPoint:bottomRight toPoint:topRight adjustedBy:[self landscapeVEdgeAdj]];
  
  [self animateCornerLayer:self.topLeftLayer atPoint:topLeft withPositionType:kTopLeft];
  [self animateCornerLayer:self.topRightLayer atPoint:topRight withPositionType:kTopRight];
  [self animateCornerLayer:self.bottomLeftLayer atPoint:bottomLeft withPositionType:kBottomLeft];
  [self animateCornerLayer:self.bottomRightLayer atPoint:bottomRight withPositionType:kBottomRight];
  
  [self animateCardMask:guideFrame];
}

+ (CGRect)guideFrameForDeviceOrientation:(UIDeviceOrientation)deviceOrientation inViewWithSize:(CGSize)size {
  // Cases whose combinations must be considered when touching this code:
  // 1. card.io running full-screen vs. modal sheet (either Page Sheet or Form Sheet)
  // 2. Device orientation when card.io was launched.
  // 3. Current device orientation.
  // 4. Device orientation-locking: none, portrait, landscape.
  // 5. App constraints in info.plist via UISupportedInterfaceOrientations.
  // Also, when testing, remember there are 2 portrait and 2 landscape orientations.
  
  FrameOrientation       frameOrientation = frameOrientationWithInterfaceOrientation((UIInterfaceOrientation)deviceOrientation);
  UIInterfaceOrientation interfaceOrientation = [UIApplication sharedApplication].statusBarOrientation;
  if (UIInterfaceOrientationIsPortrait(interfaceOrientation)) {
    dmz_rect guideFrame = dmz_guide_frame(frameOrientation, (float)size.width, (float)size.height);
    return CGRectWithDmzRect(guideFrame);
  }
  else {
    dmz_rect guideFrame = dmz_guide_frame(frameOrientation, (float)size.height, (float)size.width);
    return CGRectWithRotatedDmzRect(guideFrame);
  }
}

- (CGRect)guideFrame {
  return [[self class] guideFrameForDeviceOrientation:self.deviceOrientation inViewWithSize:self.bounds.size];
}

- (void)updateStrokes {
  if (self.guidesLockedOn) {
    self.topLayer.hidden = NO;
    self.rightLayer.hidden = NO;
    self.bottomLayer.hidden = NO;
    self.leftLayer.hidden = NO;
  } else {
    if (self.edgeScoreTop > kEdgeOnThreshold) {
      self.topLayer.hidden = NO;
    } else if(self.edgeScoreTop < kEdgeOffThreshold) {
      self.topLayer.hidden = YES;
    }
    if (self.edgeScoreRight > kEdgeOnThreshold) {
      self.rightLayer.hidden = NO;
    } else if(self.edgeScoreRight < kEdgeOffThreshold) {
      self.rightLayer.hidden = YES;
    }
    if (self.edgeScoreBottom > kEdgeOnThreshold) {
      self.bottomLayer.hidden = NO;
    } else if(self.edgeScoreBottom < kEdgeOffThreshold) {
      self.bottomLayer.hidden = YES;
    }
    if (self.edgeScoreLeft > kEdgeOnThreshold) {
      self.leftLayer.hidden = NO;
    } else if(self.edgeScoreLeft < kEdgeOffThreshold) {
      self.leftLayer.hidden = YES;
    }
  }
}

- (void)didRotateToDeviceOrientation:(UIDeviceOrientation)deviceOrientation {
  [self setNeedsLayout];

  if (deviceOrientation != self.deviceOrientation) {
    self.deviceOrientation = deviceOrientation;
    [self animateFauxCardLayerToFrame:self.guideFrame];
#if CARDIO_DEBUG
    [self rotateDebugOverlay];
#endif
  }
}

#if CARDIO_DEBUG
- (void)rotateDebugOverlay {
  self.debugOverlay.frame = self.guideFrame;
  
  //  InterfaceToDeviceOrientationDelta delta = orientationDelta(self.interfaceOrientation, self.deviceOrientation);
  //  CGFloat rotation = -rotationForOrientationDelta(delta); // undo the orientation delta
  //  self.debugOverlay.transform = CATransform3DMakeRotation(rotation, 0, 0, 1);
}
#endif

- (void)setVideoFrame:(CardIOVideoFrame *)newFrame {
  _videoFrame = newFrame;
  
  self.edgeScoreTop = kEdgeDecay * self.edgeScoreTop + (1 - kEdgeDecay) * (newFrame.foundTopEdge ? 1.0f : -1.0f);
  self.edgeScoreRight = kEdgeDecay * self.edgeScoreRight + (1 - kEdgeDecay) * (newFrame.foundRightEdge ? 1.0f : -1.0f);
  self.edgeScoreBottom = kEdgeDecay * self.edgeScoreBottom + (1 - kEdgeDecay) * (newFrame.foundBottomEdge ? 1.0f : -1.0f);
  self.edgeScoreLeft = kEdgeDecay * self.edgeScoreLeft + (1 - kEdgeDecay) * (newFrame.foundLeftEdge ? 1.0f : -1.0f);

  [self updateStrokes];

  // Update the scores with our decay factor
  float allEdgesFoundScore = (newFrame.foundAllEdges ? 1.0f : 0.0f);
  self.allEdgesFoundDecayedScore = kAllEdgesFoundScoreDecay * self.allEdgesFoundDecayedScore + (1.0f - kAllEdgesFoundScoreDecay) * allEdgesFoundScore;
  self.numEdgesFoundDecayedScore = kNumEdgesFoundScoreDecay * self.numEdgesFoundDecayedScore + (1.0f - kNumEdgesFoundScoreDecay) * newFrame.numEdgesFound;

  if (self.allEdgesFoundDecayedScore >= 0.7f) {
    [self showCardFound:YES];
  } else if (self.allEdgesFoundDecayedScore <= 0.1f){
    [self showCardFound:NO];
  }
  
#if CARDIO_DEBUG
  self.debugOverlay.contents = (id)self.videoFrame.debugCardImage.CGImage;
#endif
}

- (void)setGuideColor:(UIColor *)newGuideColor {
  if(!newGuideColor) {
    [self setGuideColor:kDefaultGuideColor];
    return;
  }

  _guideColor = newGuideColor;
  
  NSArray *edgeLayers = [NSArray arrayWithObjects:
                         self.topLayer,
                         self.bottomLayer,
                         self.leftLayer,
                         self.rightLayer,
                         self.topLeftLayer,
                         self.topRightLayer,
                         self.bottomLeftLayer,
                         self.bottomRightLayer,
                         nil];

  SuppressCAAnimation(^{
    for(CAShapeLayer *layer in edgeLayers) {
      layer.strokeColor = self.guideColor.CGColor;
    }
  });
}

- (void)layoutSublayers {
  SuppressCAAnimation(^{
    [self setLayerPaths];
    [self animateFauxCardLayerToFrame:self.guideFrame];
    
    CGRect guideFrame = [self guideFrame];
    CGFloat left = CGRectGetMinX(guideFrame);
    CGFloat top = CGRectGetMinY(guideFrame);
    CGFloat right = CGRectGetMaxX(guideFrame);
    CGFloat bottom = CGRectGetMaxY(guideFrame);
    CGRect rotatedGuideFrame = CGRectMake(left, top, right - left, bottom - top);
    CGFloat inset = [self lineWidth] / 2;
    rotatedGuideFrame = CGRectInset(rotatedGuideFrame, inset, inset);
    [self.guideLayerDelegate guideLayerDidLayout:rotatedGuideFrame];
    
#if CARDIO_DEBUG
  [self rotateDebugOverlay];
#endif
  });
}

- (void)showCardFound:(BOOL)found {
  self.guidesLockedOn = found;
  if (found) {
    self.backgroundOverlay.fillColor = [UIColor colorWithWhite:0.0f alpha:0.8f].CGColor;
  } else {
    self.backgroundOverlay.fillColor = [UIColor colorWithWhite:0.0f alpha:0.0f].CGColor;
  }
  [self updateStrokes];
}

@end

#endif
