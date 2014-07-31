//
//  CardIODevice.m
//  See the file "LICENSE.md" for the full license governing this code.
//

// Some of the platform identification code adapted from:
// Erica Sadun, http://ericasadun.com
// iPhone Developer's Cookbook, 3.0 Edition
// BSD License, Use at your own risk

#import "CardIODevice.h"
#import <MobileCoreServices/UTCoreTypes.h>
#import <sys/sysctl.h>
#import "CardIOString.h"
#import "CardIOMacros.h"
#import <sys/mman.h>
#import <unistd.h>
#import <fcntl.h>
#import "CardIOPaymentViewController.h"
#import <mach/mach_init.h>
#import <mach/vm_map.h>
#import "CardIOKeychain.h"


#include <sys/socket.h> // Per msqr
#include <sys/sysctl.h>
#include <net/if.h>
#include <net/if_dl.h>

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

+ (CGFloat)imageScaleForCurrentDevice {
  CGFloat scale = 1.0;
  if([UIScreen instancesRespondToSelector:@selector(scale)]) {
		scale = [[UIScreen mainScreen] scale];
	}
  return scale;
}

+ (BOOL)deviceUses2x {
  return ([self imageScaleForCurrentDevice] > 1.0);
}

@end