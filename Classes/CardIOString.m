//
//  CardIOString.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#import "CardIOString.h"
#import "CardIOMacros.h"
#import <CommonCrypto/CommonDigest.h>

@implementation CardIOString

// Adapted from Three20
+ (NSString *)md5:(NSString *)stringToHash {
  const char *str = [stringToHash UTF8String];
  unsigned char result[CC_MD5_DIGEST_LENGTH] = {0};
  CC_MD5(str, (CC_LONG)strlen(str), result);
  
  return [NSString stringWithFormat:
          @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
          result[0], result[1], result[2], result[3],
          result[4], result[5], result[6], result[7],
          result[8], result[9], result[10], result[11],
          result[12], result[13], result[14], result[15]
          ];
}

@end
