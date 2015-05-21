//
//  CardIOAnalytics.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#import "CardIOAnalytics.h"
#import "CardIOMacros.h"
#import "CardIODevice.h"
#import "CardIOContext.h"

#if USE_CAMERA
  #import "CardIOCardScanner.h"
  #import "scan.h"
  #import "scan_analytics.h"
  #import "CardIOCardScanner.h"
#endif

@implementation CardIOAnalytics

- (id)initWithContext:(CardIOContext *)aContext {
  self = [super init];
  if(self) {
    self.context = aContext;
  }
  return self;
}

#pragma mark Scan events

#if USE_CAMERA

- (void)reportEventWithLabel:(NSString *)reportLabel withScanner:(CardIOCardScanner *)cardScanner {
  if (cardScanner) {
    NSDictionary *params = [self scanParams:cardScanner];
    [self reportEvent:reportLabel data:params];
  }
}

- (void)reportEvent:(NSString *)eventName data:(NSDictionary *)data {
  // Add code here to log the data, or to send it to your server.
}

#pragma mark Scan data

// The basic scan analytics parameters
- (NSDictionary *)scanBaseParams:(ScanSessionAnalytics *)sessionAnalytics {
  NSDictionary *params = [NSMutableDictionary dictionary];
  // Add any basic information, such as app-identifying information, version number, etc.
  return params;
}

// Additional scan parameters used for all reports in which frames have been accumulated
- (NSDictionary *)scanParams:(CardIOCardScanner *)cardScanner {
  ScanSessionAnalytics *sessionAnalytics = cardScanner.scanSessionAnalytics;
  NSMutableDictionary *params = [NSMutableDictionary dictionaryWithCapacity:30];
  [params addEntriesFromDictionary:[self scanBaseParams:sessionAnalytics]];

  params[@"num_frames_scanned"] = @(sessionAnalytics->num_frames_scanned);
  // Add any other session-specific information, such as number of frames out of focus, or whatever
  
  int numFrames = MIN(sessionAnalytics->num_frames_scanned, kScanSessionNumFramesStored);
  if (numFrames > 0) {
    NSMutableArray *frames = [NSMutableArray arrayWithCapacity:numFrames];
    params[@"recent_frames"] = frames;
    
    for (int i = sessionAnalytics->frames_ring_start; i < numFrames + sessionAnalytics->frames_ring_start; i++) {
      ScanFrameAnalytics *f = &(sessionAnalytics->frames_ring[i % numFrames]);
      NSMutableDictionary *frameFields = [NSMutableDictionary dictionaryWithCapacity:f->frame_values.size() + 1];

      frameFields[@"frame_index"] = [NSNumber numberWithUnsignedLong:f->frame_index];

      for(std::map<std::string, std::string>::iterator iter = f->frame_values.begin(); iter != f->frame_values.end(); ++iter) {
        NSString *fieldName = [NSString stringWithUTF8String:iter->first.c_str()];
        NSString *fieldValue = [NSString stringWithUTF8String:iter->second.c_str()];
        frameFields[fieldName] = fieldValue;
      }
      
      [frames addObject:frameFields];
    }
  }

  return params;
}

#elif SIMULATE_CAMERA

- (void)reportEventWithLabel:(NSString *)reportLabel withScanner:(CardIOCardScanner *)cardScanner {}

#endif // USE_CAMERA

@end
