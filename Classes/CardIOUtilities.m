//
//  CardIOUtilities.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#import "CardIOUtilities.h"
#import "CardIODevice.h"
#import "CardIOGPUGaussianBlurFilter.h"
#import "CardIOIccVersion.h"
#import "CardIOLocalizer.h"
#import "CardIOMacros.h"
#import "CardIOView.h"

#import <AVFoundation/AVFoundation.h>

@implementation CardIOUtilities

#pragma mark - Library version, for bug reporting etc.

+ (NSString *)libraryVersion {
  NSString *dateString = [[[NSString stringWithUTF8String:__DATE__] stringByReplacingOccurrencesOfString:@" " withString:@"."] stringByReplacingOccurrencesOfString:@".." withString:@"."];
  NSString *timeHash = [NSString stringWithUTF8String:__TIME__];
  NSMutableString *libraryVersion = [NSMutableString stringWithFormat:@"%@-%@", dateString, timeHash];
  
  // make the compile time options visible for sanity checking, and so we don't ship the wrong thing.
#if CARDIO_DEBUG
  [libraryVersion appendString:@"-CARDIO_DEBUG"];
#endif
  
  return [NSString stringWithFormat:@"%@ [%@]", CardIOIccVersion(), libraryVersion];
}

#pragma mark - Confirm presence of usable camera

typedef NS_ENUM(NSInteger, ScanAvailabilityStatus) {
  ScanAvailabilityUnknown = 0,
  ScanAvailabilityNever = 1,
  ScanAvailabilityAlways = 2
};

static ScanAvailabilityStatus cachedScanAvailabilityStatus = ScanAvailabilityUnknown;

+ (BOOL)canReadCardWithCamera {
  if(cachedScanAvailabilityStatus == ScanAvailabilityNever) {
    return NO;
  }
  
  if(cachedScanAvailabilityStatus == ScanAvailabilityUnknown) {
#if !USE_CAMERA && !SIMULATE_CAMERA
    NSLog(@"card.io: Camera support only available on armv7(s) architecture -- can't use camera");
    cachedScanAvailabilityStatus = ScanAvailabilityNever;
    return NO;
#endif
    
#if USE_CAMERA
    // Check that AVFoundation is present (excludes OS 3.x and below)
    if(!NSClassFromString(@"AVCaptureSession")) {
      NSLog(@"card.io: AVFoundation not present -- can't use camera");
      cachedScanAvailabilityStatus = ScanAvailabilityNever;
      return NO;
    }
    
    // Check for video camera. This serves as a de facto CPU speed
    // and RAM availability check as well -- only recent devices have a
    // hardware h264 encoder, but only recent devices have beefy enough
    // CPU and RAM. This is not really exactly the right thing to check for,
    // but it is well correlated, and happens to work out correctly for existing devices.
    // In particular, this rules out the iPhone 3G but lets in the 3GS, which
    // we know to be the iPhone cutoff. This lets through iPod touch 4, which
    // is the only iPod touch generation to have a camera (see http://en.wikipedia.org/wiki/IPod_Touch).
    if(![CardIODevice hasVideoCamera]) {
      NSLog(@"card.io: Video camera not present -- can't use camera");
      cachedScanAvailabilityStatus = ScanAvailabilityNever;
      return NO;
    }
    
    if (iOS_7_PLUS) {
      // Check for video permission.
      // But don't set cachedScanAvailabilityStatus here, as the user can change this permission at any time.
      // (Actually, should the user go to Settings and change this permission for this app, apparently the system
      // will immediately SIGKILL (force restart) this app. But let's not depend on this semi-documented behavior.)
      AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
      if (authStatus == AVAuthorizationStatusDenied || authStatus == AVAuthorizationStatusRestricted){
        return NO;
      }
      else {
        // Either the user has already granted permission, or else the user has not yet been asked.
        //
        // For the latter case, while we could ask now, unfortunately the necessary
        // [AVCaptureDevice requestAccessForMediaType:completionHandler:] method returns the user's choice
        // to us asynchronously, which doesn't mix well with canReadCardWithCamera being synchronous.
        //
        // Rather than making a backward-incompatible change to canReadCardWithCamera, let's simply allow things
        // to proceed. When the camera view is finally presented, then the user will be prompted to authorize
        // or deny the video permission. If they choose "deny", then they'll probably understand why they're
        // looking at a black screen.
        return YES;
      }
    }
#endif
    
    cachedScanAvailabilityStatus = ScanAvailabilityAlways;
  }
  
  return YES;
}

#pragma mark - Preload resources for faster launch of card.io

+ (void)preload {
  [CardIOLocalizer preload];
}

#pragma mark - Screen obfuscation on backgrounding

+ (UIImageView *)blurredScreenImageView {
  UIWindow    *keyWindow = [UIApplication sharedApplication].keyWindow;
  UIImageView *blurredScreenImageView = [[UIImageView alloc] initWithFrame:keyWindow.bounds];
  
  UIGraphicsBeginImageContext(keyWindow.bounds.size);
  [keyWindow.layer renderInContext:UIGraphicsGetCurrentContext()];
  UIImage *viewImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  
  CardIOGPUGaussianBlurFilter *filter = [[CardIOGPUGaussianBlurFilter alloc] initWithSize:keyWindow.bounds.size];
  blurredScreenImageView.image = [filter processUIImage:viewImage toSize:keyWindow.bounds.size];
  
  return blurredScreenImageView;
}

@end
