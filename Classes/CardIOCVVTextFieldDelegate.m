//
//  CardIOCVVTextFieldDelegate.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#import "CardIOCVVTextFieldDelegate.h"
#import "CardIOCreditCardNumber.h"

@implementation CardIOCVVTextFieldDelegate

- (id)init {
  if ((self = [super init])) {
    self.numbersOnly = YES;
    self.maxLength = 4;
  }
  return self;
}

- (void)setMaxLength:(NSInteger)maxLength {
  if (maxLength <= 0 || 4 < maxLength) super.maxLength = 4;
  else super.maxLength = maxLength;
}

+ (BOOL)isValidCVV:(NSString *)cvv forNumber:(NSString *)number {
  CardIOCreditCardType cardType = [CardIOCreditCardNumber cardTypeForCardNumber:number];
  if (cardType == CardIOCreditCardTypeUnrecognized || cardType == CardIOCreditCardTypeAmbiguous) {
    return ([cvv length] >= 3); // no need to get overly fussy here...it's someone else's problem
  }
  NSInteger cvvLength = [CardIOCreditCardNumber cvvLengthForCardType:cardType];
  if (cvvLength != [cvv length]) {
    return NO;
  }
  return YES;
}

@end
