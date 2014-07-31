//
//  CardIOUtilities.h
//  See the file "LICENSE.md" for the full license governing this code.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface CardIOUtilities : NSObject

/// Please send the output of this method with any technical support requests.
/// @return Human-readable version of this library.
+ (NSString *)libraryVersion;

/// Determine whether this device supports camera-based card scanning, considering
/// factors such as hardware support and OS version.
///
/// card.io automatically provides manual entry of cards as a fallback,
/// so it is not typically necessary for your app to check this.
///
/// @return YES iff the user's device supports camera-based card scanning.
+ (BOOL)canReadCardWithCamera;

/// Returns a doubly Gaussian-blurred screenshot, intended for screenshots when backgrounding.
/// @return Blurred screenshot.
+ (UIImageView *)blurredScreenImageView;

@end
