//
//  CardIOCreditCardNumberFormatter.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#import "CardIOCreditCardNumberFormatter.h"
#import "CardIOCreditCardInfo.h"
#import "CardIOCreditCardNumber.h"

@implementation CardIOCreditCardNumberFormatter


- (BOOL)getObjectValue:(id __autoreleasing *)obj forString:(NSString *)string errorDescription:(NSString **)error {
  NSString *numberString = [CardIOCreditCardNumber stringByRemovingNonNumbers:string];
  
  if ([*obj isKindOfClass:[CardIOCreditCardInfo class]]) {
    [*obj setCardNumber:numberString];
  } else if (obj) {
    *obj = numberString;
  } else {
    *error = @"Unknown object type";
    return NO;
  }
  return YES;
}

- (NSString *)stringForObjectValue:(id)obj {
  
  NSString *inString = nil;
  if ([obj isKindOfClass:[CardIOCreditCardInfo class]]) {
    inString = [obj cardNumber];
  } else if ([obj isKindOfClass:[NSString class]]) {
    inString = obj;
  } else {
    return nil;
  }

  CardIOCreditCardType cardType = [CardIOCreditCardNumber cardTypeForCardNumber:inString];
  NSMutableString *numbersWithSpaces = [inString mutableCopy];
  [numbersWithSpaces replaceOccurrencesOfString:@" " withString:@"" options:0 range:NSMakeRange(0, numbersWithSpaces.length)];
  
  NSUInteger correctLength = [CardIOCreditCardNumber numberLengthForCardNumber:numbersWithSpaces];
  if (numbersWithSpaces.length > correctLength) {
    [numbersWithSpaces deleteCharactersInRange:NSMakeRange(correctLength, numbersWithSpaces.length - correctLength)];
  }
  
  switch(cardType) {
    case CardIOCreditCardTypeAmex:
      // work back to front to make index calculations easier
      if (numbersWithSpaces.length > 10) {
        [numbersWithSpaces insertString:@" " atIndex:10];
      }
      if (numbersWithSpaces.length > 4) {
        [numbersWithSpaces insertString:@" " atIndex:4];
      }
      break;
    case CardIOCreditCardTypeJCB:
    case CardIOCreditCardTypeVisa:
    case CardIOCreditCardTypeMastercard:
    case CardIOCreditCardTypeDiscover:
      // work back to front to make index calculations easier
      if (numbersWithSpaces.length > 12) {
        [numbersWithSpaces insertString:@" " atIndex:12];
      }
      if (numbersWithSpaces.length > 8) {
        [numbersWithSpaces insertString:@" " atIndex:8];
      }
      if (numbersWithSpaces.length > 4) {
        [numbersWithSpaces insertString:@" " atIndex:4];
      }
      break;
    default:
      break;
  }

  return numbersWithSpaces;
}

@end
