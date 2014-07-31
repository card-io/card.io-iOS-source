//
//  CardIOConfigurableTextFieldDelegate.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#import "CardIOConfigurableTextFieldDelegate.h"
#import <AudioToolbox/AudioToolbox.h>

#define kOutsetForScrolling 10

@implementation CardIOConfigurableTextFieldDelegate

@synthesize numbersOnly;
@synthesize maxLength;

+ (NSInteger)lengthOfString:(NSString *)originalText afterChangingCharactersInRange:(NSRange)range replacementString:(NSString *)string {
  return [originalText length] + [string length] - range.length;
}

+ (BOOL)containsNumbersOnly:(NSString *)newText {
  NSUInteger newTextLength = [newText length];
  for(NSUInteger index = 0; index < newTextLength; index++) {
    unichar charAtIndex = [newText characterAtIndex:index];
    if(charAtIndex < '0' || charAtIndex > '9') {
      return NO;
    }
  }
  return YES;
}

+ (NSInteger)nonDigitsInTextField:(UITextField *)textField beforeOffset:(NSInteger)offset {
  NSInteger nonDigits = 0;
  NSString *text = textField.text;
  for (NSUInteger index = 0; index < offset; index++) {
    unichar charAtIndex = [text characterAtIndex:index];
    if (charAtIndex < '0' || charAtIndex > '9') {
      nonDigits++;
    }
  }
  return nonDigits;
}

+ (UITextPosition *)positionInTextField:(UITextField *)textField after:(NSInteger)numberOfDigits {
  NSString *text = textField.text;
  NSUInteger digits = 0;
  NSUInteger position = 0;
  while (digits < numberOfDigits && position < [text length]) {
    unichar charAtIndex = [text characterAtIndex:position];
    if (charAtIndex >= '0' && charAtIndex <= '9') {
      digits++;
    }
    position++;
  }
  return [textField positionFromPosition:[textField beginningOfDocument] offset:position];
}

+ (void)getSelectionInTextField:(UITextField *)textField
          withSelectedTextRange:(UITextRange *)selectedTextRange
                       forStart:(NSInteger *)startSelectionOffset
                         forEnd:(NSInteger *)endSelectionOffset {
  if (selectedTextRange) {
    *startSelectionOffset = [textField offsetFromPosition:[textField beginningOfDocument] toPosition:selectedTextRange.start];
    *startSelectionOffset -= [CardIOConfigurableTextFieldDelegate nonDigitsInTextField:textField beforeOffset:*startSelectionOffset];
    *endSelectionOffset = [textField offsetFromPosition:[textField beginningOfDocument] toPosition:selectedTextRange.end];
    *endSelectionOffset -= [CardIOConfigurableTextFieldDelegate nonDigitsInTextField:textField beforeOffset:*endSelectionOffset];
  }
}

+ (void)vibrate {
  AudioServicesPlayAlertSound(kSystemSoundID_Vibrate);
}

#pragma mark - UITextFieldDelegate methods

- (void)textFieldDidBeginEditing:(UITextField *)textField {
  // In iOS 7, there is now apparently a UITableViewCellScrollView within a table view cell!
  // So here we'll look for the first UIScrollView we find at the tableView level or above.
  UIView *superView = textField.superview;
  UIView *textFieldCell = nil;
  UIView *tableView = nil;
  while (superView) {
    if (!textFieldCell && [superView isKindOfClass:[UITableViewCell class]]) {
      textFieldCell = superView;
    }
    else {
      if (!tableView && [superView isKindOfClass:[UITableView class]]) {
        tableView = superView;
      }
      
      if (tableView != nil && [superView isKindOfClass:[UIScrollView class]] && ((UIScrollView*)superView).scrollEnabled) {
        UIScrollView *scrollView = (UIScrollView *)superView;
        CGRect contentRectInScroller = [scrollView convertRect:textFieldCell.bounds fromView:textFieldCell];
        contentRectInScroller = CGRectInset(contentRectInScroller, 0, -kOutsetForScrolling);
        [scrollView scrollRectToVisible:contentRectInScroller animated:YES];
        break;
      }
    }
    superView = superView.superview;
  }
}

- (BOOL)textField:(UITextField *)aTextField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)newText {
  if(self.numbersOnly &&
     ![[self class] containsNumbersOnly:newText]) {
    [CardIOConfigurableTextFieldDelegate vibrate];
    return NO;
  }
  if(self.maxLength > 0 &&
     self.maxLength < ([[self class] lengthOfString:aTextField.text afterChangingCharactersInRange:range replacementString:newText])) {
    [CardIOConfigurableTextFieldDelegate vibrate];
    return NO;
  }
  return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)aTextField {
  [aTextField resignFirstResponder];
  return YES;
}

@end
