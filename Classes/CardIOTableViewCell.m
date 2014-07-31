//
//  CardIOTableViewCell.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#import "CardIOTableViewCell.h"
#import "CardIOMacros.h"

@implementation CardIOTableViewCell

+ (UIFont *)defaultTextLabelFontForCellStyle:(UITableViewCellStyle)cellStyle {
  CGFloat fontSize = [self defaultTextLabelFontSizeForCellStyle:cellStyle];
  return [self defaultTextLabelFontForCellStyle:cellStyle fontSize:fontSize];
}

+ (UIFont *)defaultTextLabelFontForCellStyle:(UITableViewCellStyle)cellStyle fontSize:(CGFloat)fontSize {
  return (iOS_7_PLUS
          ? [UIFont preferredFontForTextStyle:@"UICTFontTextStyleBody"/*UIFontTextStyleBody*/]
          : [UIFont systemFontOfSize:fontSize]);
}

+ (UIFont *)defaultDetailTextLabelFontForCellStyle:(UITableViewCellStyle)cellStyle {
  CGFloat fontSize = [self defaultDetailTextLabelFontSizeForCellStyle:cellStyle];
  return [self defaultDetailTextLabelFontForCellStyle:cellStyle fontSize:fontSize];
}

+ (UIFont *)defaultDetailTextLabelFontForCellStyle:(UITableViewCellStyle)cellStyle fontSize:(CGFloat)fontSize {
  return (iOS_7_PLUS
          ? [UIFont preferredFontForTextStyle:@"UICTFontTextStyleBody"/*UIFontTextStyleBody*/]
          : [UIFont systemFontOfSize:fontSize]);
}

+ (CGFloat)defaultTextLabelFontSizeForCellStyle:(UITableViewCellStyle)cellStyle {
  CGFloat fontSize = 0.0f;
  switch(cellStyle) {
    case UITableViewCellStyleDefault:
      fontSize = 20.0f;
      break;
    case UITableViewCellStyleSubtitle:
      fontSize = 18.0f;
      break;
    case UITableViewCellStyleValue1:
      fontSize = 18.0f;
      break;
    case UITableViewCellStyleValue2:
      fontSize = 12.0f;
      break;
    default:
      fontSize = 0.0f;
      break;
  }
  return fontSize;  
}

+ (CGFloat)defaultDetailTextLabelFontSizeForCellStyle:(UITableViewCellStyle)cellStyle {
  CGFloat fontSize = 0.0f;
  switch(cellStyle) {
    case UITableViewCellStyleDefault:
      fontSize = 0.0f;
      break;
    case UITableViewCellStyleSubtitle:
      fontSize = 14.0f;
      break;
    case UITableViewCellStyleValue1:
      fontSize = 18.0f;
      break;
    case UITableViewCellStyleValue2:
      fontSize = 18.0f;
      break;
    default:
      fontSize = 0.0f;
      break;
  }

  return fontSize;
}

+ (UIColor *)defaultTextLabelColorForCellStyle:(UITableViewCellStyle)cellStyle {
  UIColor *defaultColor = nil;
  switch(cellStyle) {
    case UITableViewCellStyleDefault:
      defaultColor = [UIColor colorWithWhite:0.0f alpha:1.0f];
      break;
    case UITableViewCellStyleSubtitle:
      defaultColor = [UIColor colorWithWhite:0.0f alpha:1.0f];
      break;
    case UITableViewCellStyleValue1:
      defaultColor = [UIColor colorWithWhite:0.0f alpha:1.0f];
      break;
//    case UITableViewCellStyleValue2:
////      defaultColor = [UIColor colorWithRed:0.22f green:0.33f blue:0.53f alpha:1.0f];
//      defaultColor = [UIColor darkGrayColor];
//      break;
    default:
      defaultColor = [UIColor darkGrayColor];
      break;
  }
  return defaultColor;
}

+ (UIColor *)defaultDetailTextLabelColorForCellStyle:(UITableViewCellStyle)cellStyle {
  UIColor *defaultColor = nil;
  switch(cellStyle) {
//    case UITableViewCellStyleDefault:
//      defaultColor = nil;
//      break;
    case UITableViewCellStyleSubtitle:
      defaultColor = [UIColor colorWithRed:0.5f green:0.5f blue:0.5f alpha:1.0f];
      break;
    case UITableViewCellStyleValue1:
      defaultColor = [UIColor colorWithRed:0.22f green:0.33f blue:0.53f alpha:1.0f];
      break;
    case UITableViewCellStyleValue2:
      defaultColor = [UIColor colorWithWhite:0.0f alpha:1.0f];
      break;
    default:
      defaultColor = [UIColor darkTextColor];
      break;
  }
  return defaultColor;
}

+ (UITableViewCellStyle) defaultCellStyle {
  return UITableViewCellStyleValue2;
}

@end
