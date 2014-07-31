//
//  CardIOCreditCardNumber.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#import "CardIOCreditCardNumber.h"
#import "dmz.h"

@implementation CardIOCreditCardNumber

+ (void)string:(NSString *)cardNumberString toNumberArray:(uint8_t[])number_array withLength:(uint8_t*)number_length {
  *number_length = (uint8_t)[cardNumberString length];
  for (NSUInteger i = 0; i < *number_length; i++) {
    number_array[i] = (uint8_t)([cardNumberString characterAtIndex:i] - '0');
  }
}

+ (CardIOCreditCardType)cardTypeFromDmzCardType:(CardType)card_type {
  switch (card_type) {
    case CardTypeUnrecognized:
      return CardIOCreditCardTypeUnrecognized;
    case CardTypeAmbiguous:
      return CardIOCreditCardTypeAmbiguous;
    case CardTypeAmex:
      return CardIOCreditCardTypeAmex;
    case CardTypeJCB:
      return CardIOCreditCardTypeJCB;
    case CardTypeVisa:
      return CardIOCreditCardTypeVisa;
    case CardTypeMastercard:
      return CardIOCreditCardTypeMastercard;
    case CardTypeDiscover:
      return CardIOCreditCardTypeDiscover;
    default:
      return CardIOCreditCardTypeUnrecognized;
  }
}

+ (BOOL)passesLuhnChecksum:(NSString *)cardNumber {
  uint8_t number_array[32];
  uint8_t length;
  [CardIOCreditCardNumber string:cardNumber toNumberArray:number_array withLength:&length];
  return dmz_passes_luhn_checksum(number_array, length);
}

+ (CardIOCreditCardType)cardTypeForCardNumber:(NSString *)cardNumber {
  uint8_t number_array[32];
  uint8_t length;
  [CardIOCreditCardNumber string:[CardIOCreditCardNumber stringByRemovingNonNumbers:cardNumber] toNumberArray:number_array withLength:&length];
  dmz_card_info card_info = dmz_card_info_for_prefix_and_length(number_array, length, true);
  return [CardIOCreditCardNumber cardTypeFromDmzCardType:card_info.card_type];
}

+ (NSInteger)numberLengthForCardNumber:(NSString *)cardNumber {
  uint8_t number_array[16];
  uint8_t length;
  [CardIOCreditCardNumber string:[CardIOCreditCardNumber stringByRemovingNonNumbers:cardNumber] toNumberArray:number_array withLength:&length];
  dmz_card_info card_info = dmz_card_info_for_prefix_and_length(number_array, length, true);
  return (NSInteger)card_info.number_length;
}

+ (NSInteger)cvvLengthForCardType:(CardIOCreditCardType)cardType {
  NSInteger cvvLength = -1;
  switch(cardType) {
    case CardIOCreditCardTypeAmex:
      cvvLength = 4;
      break;
    case CardIOCreditCardTypeJCB:
    case CardIOCreditCardTypeVisa:
    case CardIOCreditCardTypeMastercard:
    case CardIOCreditCardTypeDiscover:
      cvvLength = 3;
      break;
    case CardIOCreditCardTypeUnrecognized:
    case CardIOCreditCardTypeAmbiguous:
    default:
      cvvLength = -1;
      break;
  }
  return cvvLength;
}

+ (NSString *)stringByRemovingNonNumbers:(NSString *)stringWithSpaces {

  NSMutableString* result = [NSMutableString stringWithCapacity:stringWithSpaces.length];
  
  NSScanner* scanner = [[NSScanner alloc] initWithString:stringWithSpaces];
  [scanner setCharactersToBeSkipped:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  
  while (![scanner isAtEnd]) {
    NSString* fragment = nil;
    if ([scanner scanCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:&fragment])
      [result appendString:fragment];
    [scanner scanCharactersFromSet:[[NSCharacterSet decimalDigitCharacterSet] invertedSet] intoString:nil];
  }
  
  return result;
}

+ (NSString *)stringbyRemovingSpaces:(NSString *)stringWithSpaces {
  return [stringWithSpaces stringByReplacingOccurrencesOfString:@" " withString:@""];
}

+ (BOOL)isValidNumber:(NSString *)number {
  CardIOCreditCardType cardType = [CardIOCreditCardNumber cardTypeForCardNumber:number];
  if (cardType == CardIOCreditCardTypeAmbiguous) {
    return NO;
  }
  NSString *numberWithoutSpaces = [CardIOCreditCardNumber stringByRemovingNonNumbers:number];
  NSUInteger numberLength = [numberWithoutSpaces length];
  if ((cardType == CardIOCreditCardTypeUnrecognized && numberLength >= 14) ||
      (cardType != CardIOCreditCardTypeUnrecognized && numberLength == [CardIOCreditCardNumber numberLengthForCardNumber:number])) {
    if ([CardIOCreditCardNumber passesLuhnChecksum:numberWithoutSpaces]) {
      return YES;
    }
  }
  return NO;
}

@end
