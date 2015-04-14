//
//  CardIOCreditCardExpiryFormatter.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#import "CardIOCreditCardExpiryFormatter.h"
#import "CardIOCreditCardInfo.h"
#import "CardIOCreditCardNumber.h"

@implementation CardIOCreditCardExpiryFormatter

- (BOOL)getObjectValue:(id __autoreleasing *)obj forString:(NSString *)string errorDescription:(NSString **)error {
  
  // try to be somewhat robust
  NSArray *values = [string componentsSeparatedByString:@"/"];
  NSInteger month = 0;
  NSInteger year = 0;
  
  if (values.count > 0) {
    month = [[CardIOCreditCardNumber stringByRemovingNonNumbers:values[0]] integerValue];
  }
  if (values.count > 1) {
    year = [[CardIOCreditCardNumber stringByRemovingNonNumbers:values[1]] integerValue];
    if (year < 2000) {
      year = 2000 + (year % 100);
    }
  }

  if ([*obj isKindOfClass:[CardIOCreditCardInfo class]]) {
    [*obj setExpiryMonth:month];
    [*obj setExpiryYear:year];
  } else {
    *error = @"Unknown object type";
    return NO;
  }

  return YES;
}

- (NSString *)stringForObjectValue:(id)obj {
  if (![obj isKindOfClass:[CardIOCreditCardInfo class]]) {
    return nil;
  }
  return [NSString stringWithFormat:@"%02lu / %02lu", (unsigned long)[obj expiryMonth], (unsigned long)[obj expiryYear] % 100];
}

@end
