//
//  CardIOReadCardInfo.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#import "CardIOReadCardInfo.h"
#import "CardIOMacros.h"

@interface CardIOReadCardInfo ()

@property(nonatomic, strong, readwrite) NSString *numbers;
@property(nonatomic, strong, readwrite) NSArray *xOffsets;
@property(nonatomic, assign, readwrite) NSUInteger yOffset;
@property(nonatomic, assign, readwrite) NSUInteger expiryYear;
@property(nonatomic, assign, readwrite) NSUInteger expiryMonth;
@property(nonatomic, assign, readwrite) BOOL isFlipped;

@end


#pragma mark -

@implementation CardIOReadCardInfo

+ (CardIOReadCardInfo *)cardInfoWithNumber:(NSString *)cardNumber xOffsets:(NSArray *)xOffsets yOffset:(NSUInteger)yOffset {
  CardIOReadCardInfo *cardInfo = [[self alloc] init];
  cardInfo.numbers = cardNumber;
  cardInfo.xOffsets = xOffsets;
  cardInfo.yOffset = yOffset;
  return cardInfo;
}

@end
