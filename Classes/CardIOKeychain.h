// adapted from https://raw.github.com/rackspace/rackspace-ios/master/Classes/Keychain.h

//
//  CardIOKeychain.h
//  OpenStack
//
//  Based on KeychainWrapper in BadassVNC by Dylan Barrie
//
//  Created by Mike Mayo on 10/1/10.
//  The OpenStack project is provided under the Apache 2.0 license.
//

#import <Foundation/Foundation.h>

// This wrapper helps us deal with Keychain-related things 
// such as storing API keys and passwords

@interface CardIOKeychain : NSObject {
}

+ (BOOL)setData:(NSData *)data forKey:(NSString *)key;
+ (NSData *)dataForKey:(NSString *)key;

@end