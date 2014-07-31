//
//  CardIOAnimation.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#if USE_CAMERA || SIMULATE_CAMERA

#import "CardIOAnimation.h"

void SuppressCAAnimation(BareBlock block) {
  [CATransaction begin];
  [CATransaction setDisableActions:YES];
  block();
  [CATransaction commit];
}


//@implementation CardIOAnimation
//
//@end

#endif