//
//  CardIOCardholderNameTextFieldDelegate.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#import "CardIOCardholderNameTextFieldDelegate.h"

@implementation CardIOCardholderNameTextFieldDelegate

-(id) init {
  if ((self = [super init])) {
    // Globalization: alphanumeric, space, hyphen are all definitely okay;
    // there's no compelling reason for us to get fussy here.
    self.numbersOnly = NO;
    self.maxLength = 175;  // PayPal REST APIs accept max of 175 chars for cardholder name
  }
  return self;
}

+(BOOL)isValidCardholderName:(NSString*)cardholderName {
  return [cardholderName length] > 0;
}

@end
