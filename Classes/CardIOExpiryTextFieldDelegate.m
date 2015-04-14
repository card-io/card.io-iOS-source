//
//  CardIOExpiryTextFieldDelegate.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#import "CardIOExpiryTextFieldDelegate.h"
#import "CardIOCreditCardInfo.h"
#import "CardIOCreditCardNumber.h"

@interface CardIOExpiryTextFieldDelegate ()

@property(nonatomic, strong, readwrite) CardIOCreditCardExpiryFormatter *formatter;
@property(nonatomic, assign, readwrite) BOOL backspacing;

@end

@implementation CardIOExpiryTextFieldDelegate

- (id)init {
  if((self = [super init])) {
    self.numbersOnly = YES;
    _formatter = [[CardIOCreditCardExpiryFormatter alloc] init];
  }
  return self;
}

- (BOOL)cleanupTextField:(UITextField *)textField {
  if (self.backspacing) {
    self.backspacing = NO;
    return NO;
  }
  
  UITextRange *selectedTextRange = textField.selectedTextRange;
  NSInteger startSelectionOffset = 0;
  NSInteger endSelectionOffset = 0;
  [CardIOConfigurableTextFieldDelegate getSelectionInTextField:textField withSelectedTextRange:selectedTextRange forStart:&startSelectionOffset forEnd:&endSelectionOffset];
  
  NSMutableString *correctedText = [[CardIOCreditCardNumber stringByRemovingNonNumbers:textField.text] mutableCopy];
  
  if(correctedText.length > 0 && [correctedText characterAtIndex:0] > '1' && [correctedText characterAtIndex:0] <= '9') {
    if (startSelectionOffset > 0) {
      startSelectionOffset++;
    }
    if (endSelectionOffset > 0) {
      endSelectionOffset++;
    }
    [correctedText insertString:@"0" atIndex:0];
  }
  
  if(correctedText.length >= 2) {
    if (startSelectionOffset >= 2) {
      startSelectionOffset += 3;
    }
    if (endSelectionOffset >= 2) {
      endSelectionOffset += 3;
    }
    [correctedText replaceCharactersInRange:NSMakeRange(2, 0) withString:@" / "];
  }
  
  if (![correctedText isEqualToString:textField.text]) {
    textField.text = correctedText;
    
    if (selectedTextRange) {
      UITextPosition *startSelectionPosition = [textField positionFromPosition:[textField beginningOfDocument] offset:startSelectionOffset];
      UITextPosition *endSelectionPosition = [textField positionFromPosition:[textField beginningOfDocument] offset:endSelectionOffset];
      textField.selectedTextRange = [textField textRangeFromPosition:startSelectionPosition toPosition:endSelectionPosition];
    }
  }
  
  return YES;
}

#pragma mark - UITextFieldDelegate methods

- (void)textFieldDidEndEditing:(UITextField *)textField {
  self.backspacing = NO;
  [self cleanupTextField:textField];
  
  if(textField.text.length > 0) {
    CardIOCreditCardInfo *info = [[CardIOCreditCardInfo alloc] init];
    if([self.formatter getObjectValue:&info forString:textField.text errorDescription:nil]) {
      textField.text = [self.formatter stringForObjectValue:info];
    }
  }

  [[NSNotificationCenter defaultCenter] postNotificationName:UITextFieldTextDidChangeNotification object:textField];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)newText {
  if(range.location < textField.text.length && newText.length == 0) {
    self.backspacing = YES;
    return YES;
  }
  
  NSString *numericNewText = [CardIOCreditCardNumber stringByRemovingNonNumbers:newText];
  NSString *updatedText = [textField.text stringByReplacingCharactersInRange:range withString:numericNewText];
  if(updatedText.length > 7) {
    // 7 characters: "MM_/_YY"
    [CardIOConfigurableTextFieldDelegate vibrate];
    return NO;
  }
  
  NSString *updatedNumberText = [CardIOCreditCardNumber stringByRemovingNonNumbers:updatedText];
  
  NSString *monthStr = [updatedNumberText substringToIndex:MIN(2, updatedNumberText.length)];
  if(monthStr.length > 0) {
    NSInteger month = [monthStr integerValue];
    if(month < 0 || month > 12) {
      [CardIOConfigurableTextFieldDelegate vibrate];
      return NO;
    }
    if(monthStr.length >= 2 && month == 0) {
      [CardIOConfigurableTextFieldDelegate vibrate];
      return NO;
    }
  }
  
  return YES;
}

@end
