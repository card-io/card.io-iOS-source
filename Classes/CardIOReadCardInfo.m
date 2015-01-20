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

#if CARDIO_DEBUG
@property(nonatomic, strong, readwrite) NSArray *expiryGroupedRects;
@property(nonatomic, strong, readwrite) NSArray *nameGroupedRects;
#endif

@end


#pragma mark -

@implementation CardIOReadCardInfo

+ (CardIOReadCardInfo *)cardInfoWithNumber:(NSString *)cardNumber
                                  xOffsets:(NSArray *)xOffsets
                                   yOffset:(NSUInteger)yOffset
                                expiryMonth:(NSUInteger)expiryMonth
                                expiryYear:(NSUInteger)expiryYear
#if CARDIO_DEBUG
                        expiryGroupedRects:(NSArray *)expiryGroupedRects
                          nameGroupedRects:(NSArray *)nameGroupedRects
#endif
{
CardIOReadCardInfo *cardInfo = [[self alloc] init];
cardInfo.numbers = cardNumber;
cardInfo.xOffsets = xOffsets;
cardInfo.yOffset = yOffset;
  cardInfo.expiryMonth = expiryMonth;
  cardInfo.expiryYear = expiryYear;
#if CARDIO_DEBUG
  cardInfo.expiryGroupedRects = expiryGroupedRects;
  cardInfo.nameGroupedRects = nameGroupedRects;
#endif
  return cardInfo;
}

@end
