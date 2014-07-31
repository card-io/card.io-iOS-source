//
//  CardIOPostalCodeTextFieldDelegate.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#import "CardIOPostalCodeTextFieldDelegate.h"


@implementation CardIOPostalCodeTextFieldDelegate

-(id) init {
  if ((self = [super init])) {
    // Globalization: alphanumeric, space, hyphen are all definitely okay;
    // there's no compelling reason for us to get fussy here.
    self.numbersOnly = NO;
    self.maxLength = 20;  // limit set by REST API
  }
  return self;
}

+(BOOL)isValidPostalCode:(NSString *)postalCode {
  return [postalCode length] > 0;
}

@end
