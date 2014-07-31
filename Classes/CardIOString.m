//
//  CardIOString.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#import "CardIOString.h"
#import "CardIOMacros.h"
#import <CommonCrypto/CommonDigest.h>

static const short _base64DecodingTable[256] = {
	-2, -2, -2, -2, -2, -2, -2, -2, -2, -1, -1, -2, -1, -1, -2, -2,
	-2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,
	-1, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, 62, -2, -2, -2, 63,
	52, 53, 54, 55, 56, 57, 58, 59, 60, 61, -2, -2, -2, -2, -2, -2,
	-2,  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14,
	15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, -2, -2, -2, -2, -2,
	-2, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
	41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, -2, -2, -2, -2, -2,
	-2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,
	-2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,
	-2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,
	-2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,
	-2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,
	-2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,
	-2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2,
	-2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2, -2
};

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


+ (NSString *)stringByURLEncodingAllCharactersInString:(NSString *)aString {
  NSString *encodedString = (NSString *)CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL,
                                                                                                  (CFStringRef)aString,
                                                                                                  NULL,
                                                                                                  (CFStringRef)@"&()<>@,;:\\\"/[]?=+$|^~`{}",
                                                                                                  kCFStringEncodingUTF8));
  return encodedString;
}

+ (NSString *)queryStringWithDictionary:(NSDictionary *)dict{
  NSMutableString *queryString = [NSMutableString string];
  for(id key in dict) {
    NSString *encodedKey = [self stringByURLEncodingAllCharactersInString:[key description]];
    id value = dict[key];
    if([value isKindOfClass:[NSArray class]]) {
      for(id obj in value) {
        [queryString appendFormat:@"%@=%@&",
         encodedKey,
         [self stringByURLEncodingAllCharactersInString:[obj description]]
         ];
      }
    } else if([value isKindOfClass:[NSDictionary class]]) {
      for(id subkey in value) {
        [queryString appendFormat:@"%@%%5B%@%%5D=%@&",
         encodedKey,
         [self stringByURLEncodingAllCharactersInString:[subkey description]],
         [self stringByURLEncodingAllCharactersInString:[value[subkey] description]]
         ];
      }
    } else if([value isKindOfClass:[NSNull class]]) {
      [queryString appendFormat:@"%@=&", encodedKey];
    } else {
      [queryString appendFormat:@"%@=%@&",
       encodedKey,
       [self stringByURLEncodingAllCharactersInString:[value description]]
       ];
    }
  }
  if([queryString length] > 0) {
    [queryString deleteCharactersInRange:NSMakeRange([queryString length] - 1, 1)]; // remove trailing &    
  }
  return queryString;
}

// This base 64 encoding adapted from Colloquy's BSD-licensed Chat Core library

static char base64encodingTable[64] = {
  'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P',
  'Q','R','S','T','U','V','W','X','Y','Z','a','b','c','d','e','f',
  'g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v',
  'w','x','y','z','0','1','2','3','4','5','6','7','8','9','+','/'
};

+ (NSString *)stringByBase64EncodingData:(NSData *)data {
	return [self stringByBase64EncodingData:data lineLength:0];
}

+ (NSString *)stringByBase64EncodingData:(NSData *)data lineLength:(NSUInteger)lineLength {
	const unsigned char	*bytes = data.bytes;
	NSMutableString *result = [NSMutableString stringWithCapacity:data.length];
	unsigned long ixtext = 0;
	unsigned long lentext = data.length;
	long ctremaining = 0;
	unsigned char inbuf[3], outbuf[4];
	unsigned short i = 0;
	unsigned short charsonline = 0, ctcopy = 0;
	unsigned long ix = 0;
  
	while( YES ) {
		ctremaining = lentext - ixtext;
		if( ctremaining <= 0 ) break;
    
		for( i = 0; i < 3; i++ ) {
			ix = ixtext + i;
			if( ix < lentext ) inbuf[i] = bytes[ix];
			else inbuf [i] = 0;
		}
    
		outbuf [0] = (unsigned char)((inbuf [0] & 0xFC) >> 2);
		outbuf [1] = (unsigned char)(((inbuf [0] & 0x03) << 4) | ((inbuf [1] & 0xF0) >> 4));
		outbuf [2] = (unsigned char)(((inbuf [1] & 0x0F) << 2) | ((inbuf [2] & 0xC0) >> 6));
		outbuf [3] = (unsigned char)(inbuf [2] & 0x3F);
		ctcopy = 4;
    
		switch( ctremaining ) {
      case 1:
        ctcopy = 2;
        break;
      case 2:
        ctcopy = 3;
        break;
		}
    
		for( i = 0; i < ctcopy; i++ )
			[result appendFormat:@"%c", base64encodingTable[outbuf[i]]];
    
		for( i = ctcopy; i < 4; i++ )
			[result appendString:@"="];
    
		ixtext += 3;
		charsonline += 4;
    
		if( lineLength > 0 ) {
			if( charsonline >= lineLength ) {
				charsonline = 0;
				[result appendString:@"\n"];
			}
		}
	}
  
	return [NSString stringWithString:result];
}


+ (NSData *)decodeBase64WithString:(NSString *)strBase64 {
	const char * objPointer = [strBase64 cStringUsingEncoding:NSASCIIStringEncoding];
	if (objPointer == NULL)  return nil;
	size_t intLength = strlen(objPointer);
	int intCurrent;
	int i = 0, j = 0, k;
  
	unsigned char * objResult;
	objResult = calloc(intLength, sizeof(unsigned char));
  
	// Run through the whole string, converting as we go
	while ( ((intCurrent = *objPointer++) != '\0') && (intLength-- > 0) ) {
		if (intCurrent == '=') {
			if (*objPointer != '=' && ((i % 4) == 1)) {// || (intLength > 0)) {
				// the padding character is invalid at this point -- so this entire string is invalid
				free(objResult);
				return nil;
			}
			continue;
		}
    
		intCurrent = _base64DecodingTable[intCurrent];
		if (intCurrent == -1) {
			// we're at a whitespace -- simply skip over
			continue;
		} else if (intCurrent == -2) {
			// we're at an invalid character
			free(objResult);
			return nil;
		}
    
		switch (i % 4) {
			case 0:
				objResult[j] = (unsigned char)(intCurrent << 2);
				break;
        
			case 1:
				objResult[j++] |= (unsigned char)(intCurrent >> 4);
				objResult[j] = (unsigned char)((intCurrent & 0x0f) << 4);
				break;
        
			case 2:
				objResult[j++] |= (unsigned char)(intCurrent >>2);
				objResult[j] = (unsigned char)((intCurrent & 0x03) << 6);
				break;
        
			case 3:
				objResult[j++] |= (unsigned char)intCurrent;
				break;
		}
		i++;
	}
  
	// mop things up if we ended on a boundary
	k = j;
	if (intCurrent == '=') {
		switch (i % 4) {
			case 1:
				// Invalid state
				free(objResult);
				return nil;
        
			case 2:
				k++;
				// flow through
			case 3:
				objResult[k] = (unsigned char)0;
		}
	}
  
	// Cleanup and setup the return NSData
	return [[NSData alloc] initWithBytesNoCopy:objResult length:j freeWhenDone:YES];
}


@end
