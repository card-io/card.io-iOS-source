//
//  CardIOString.h
//  See the file "LICENSE.md" for the full license governing this code.
//

#import <Foundation/Foundation.h>


@interface CardIOString : NSObject

+ (NSString *)md5:(NSString *)stringToHash;
+ (NSString *)stringByURLEncodingAllCharactersInString:(NSString *)aString; // including &, %, ?, =, and other url "safe" characters
+ (NSString *)queryStringWithDictionary:(NSDictionary *)dict; // handles dictionary values as strings, dicts, arrays; for all else, it uses -description

+ (NSString *)stringByBase64EncodingData:(NSData *)data;
+ (NSString *)stringByBase64EncodingData:(NSData *)data lineLength:(NSUInteger)lineLength;

+ (NSData *)decodeBase64WithString:(NSString *)strBase64;

@end
