//
//  CardIOCreditCardInfo.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#import "CardIOCreditCardInfo.h"
#import "CardIOBundle.h"
#import "CardIOCreditCardNumber.h"
#import "CardIOLocalizer.h"
#import "CardIOMacros.h"

@implementation CardIOCreditCardInfo

+ (NSString *)displayStringForCardType:(CardIOCreditCardType)cardType usingLanguageOrLocale:(NSString *)languageOrLocale {
  NSString *result = nil;
  switch(cardType) {
    case CardIOCreditCardTypeAmex:
      result = CardIOLocalizedString(@"cardtype_americanexpress", languageOrLocale); // American Express
      break;
    case CardIOCreditCardTypeJCB:
      result = CardIOLocalizedString(@"cardtype_jcb", languageOrLocale); // JCB
      break;
    case CardIOCreditCardTypeVisa:
      result = CardIOLocalizedString(@"cardtype_visa", languageOrLocale); // Visa
      break;
    case CardIOCreditCardTypeMastercard:
      result = CardIOLocalizedString(@"cardtype_mastercard", languageOrLocale); // MasterCard
      break;
    case CardIOCreditCardTypeDiscover:
      result = CardIOLocalizedString(@"cardtype_discover", languageOrLocale); // Discover
      break;
    default:
      result = @"";
      break;
  }
  return result;
}

+ (UIImage *)logoForCardType:(CardIOCreditCardType)cardType {
  UIImage   *logo = nil;
  NSString  *imageName = nil;
  switch (cardType) {
    case CardIOCreditCardTypeAmex:
      imageName = @"icon_amex_large.png";
      break;
    case CardIOCreditCardTypeJCB:
      imageName = @"icon_jcb_large.png";
      break;
    case CardIOCreditCardTypeVisa:
      imageName = @"icon_visa_large.png";
      break;
    case CardIOCreditCardTypeMastercard:
      imageName = @"icon_mastercard_large.png";
      break;
    case CardIOCreditCardTypeDiscover:
      imageName = @"icon_discover.png";
      break;
    default:
      break;
  }
  if ([imageName length]) {
    logo = [[CardIOBundle sharedInstance] imageNamed:[NSString stringWithFormat:@"CreditCardLogos/%@", imageName]];
  }
  return logo;
}

- (NSString *)redactedCardNumber {
  NSUInteger numberLength = [self.cardNumber length];
  if(numberLength < 4) {
    return self.cardNumber;
  }
  NSString *lastFour = [self.cardNumber substringFromIndex:numberLength - 4];
  NSUInteger numStars = numberLength - 4;
  NSString *stars = [@"" stringByPaddingToLength:numStars withString:@"\u2022" startingAtIndex:0];
  NSString *redactedNumber = [stars stringByAppendingString:lastFour];
  return redactedNumber;
}

- (NSString *)description {
  return [NSString stringWithFormat:@"{%@ %@; expiry: %lu/%lu%@%@}",
          [[self class] displayStringForCardType:self.cardType usingLanguageOrLocale:@"en"],
          [self redactedCardNumber],
          (unsigned long)self.expiryMonth,
          (unsigned long)self.expiryYear,
          ([self.cvv length] ? [NSString stringWithFormat:@"; cvv: %@", self.cvv] : @""),
          ([self.postalCode length] ? [NSString stringWithFormat:@"; postal code: %@", self.postalCode] : @"")];
}

- (CardIOCreditCardType)cardType {
  return [CardIOCreditCardNumber cardTypeForCardNumber:self.cardNumber];
}

- (CardIOCreditCardInfo *)copyWithZone:(NSZone *)zone {
  CardIOCreditCardInfo *theCopy = [[CardIOCreditCardInfo allocWithZone:zone] init];
  theCopy.cardNumber = self.cardNumber;
  theCopy.expiryMonth = self.expiryMonth;
  theCopy.expiryYear = self.expiryYear;
  theCopy.cvv = self.cvv;
  theCopy.postalCode = self.postalCode;
  theCopy.scanned = self.scanned;
  theCopy.cardImage = [self.cardImage copy];
  return theCopy;
}


#pragma mark - Overridden accessors

- (void)setExpiryMonth:(NSUInteger)month {
  if(month > 12) {
    month = 12;
  }
  _expiryMonth = month;
}

@end
