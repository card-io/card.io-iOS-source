//
//  CardIODevice.m
//  See the file "LICENSE.md" for the full license governing this code.
//

// Some of the platform identification code adapted from:
// Erica Sadun, http://ericasadun.com
// iPhone Developer's Cookbook, 3.0 Edition
// BSD License, Use at your own risk

// TODO: When we drop support for iOS 6, then we can remove all of the 3GS-related code in here.

#import "CardIODevice.h"
#import <MobileCoreServices/UTCoreTypes.h>
#import "CardIOMacros.h"
#include <sys/sysctl.h>

#pragma mark -

@interface CardIODevice ()

+ (NSString *)getSysInfoByName:(char *)infoSpecifier;
+ (BOOL)is3GS;

@end

@implementation CardIODevice

+ (NSString *)getSysInfoByName:(char *)infoSpecifier {
	size_t size;
  sysctlbyname(infoSpecifier, NULL, &size, NULL, 0);
  char *answer = malloc(size);
	sysctlbyname(infoSpecifier, answer, &size, NULL, 0);
	NSString *result = [NSString stringWithCString:answer encoding:NSUTF8StringEncoding];
	free(answer);
	return result;
}

+ (NSString *)platformName {
  return [self getSysInfoByName:"hw.machine"];
}

+ (BOOL)is3GS {
  NSString *platformName = [self platformName];
  CardIOLog(@"Platform name is %@", platformName);
  BOOL is3GS = [platformName hasPrefix:@"iPhone2"]; // should this be @"iPhone2,", so we don't pickup the 20th gen iPhone? :)
  return is3GS;
}

+ (BOOL)hasVideoCamera {
  // check for a camera
  if(![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
    return NO;
  }
  
  // check for video support
  NSArray *availableMediaTypes = [UIImagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypeCamera];
  BOOL supportsVideo = [availableMediaTypes containsObject:(NSString *)kUTTypeMovie];
  
  // TODO: Should check AVCaptureDevice's supportsAVCaptureSessionPreset: for our preset.
  
  return supportsVideo;
}

+ (BOOL)shouldSetPixelFormat {
  // The 3GS chokes when you set the pixel format!?
  // Fortunately, the default is the one we want anyway.
  return ![self is3GS];
}

@end