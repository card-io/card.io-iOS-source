//
//  CardIONumbersTextFieldDelegate.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#import "CardIONumbersTextFieldDelegate.h"
#import "CardIOCreditCardNumber.h"
#import "CardIOCreditCardNumberFormatter.h"

@interface CardIONumbersTextFieldDelegate ()
@property(nonatomic, strong, readwrite) CardIOCreditCardNumberFormatter *formatter;
@end


#pragma mark -

@implementation CardIONumbersTextFieldDelegate

- (id)init {
  if((self = [super init])) {
    self.numbersOnly = YES;
    self.maxLength = 16;
    _formatter = [[CardIOCreditCardNumberFormatter alloc] init];
  }
  return self;
}

- (BOOL)cleanupTextField:(UITextField *)textField {
  UITextRange *selectedTextRange = textField.selectedTextRange;
  NSInteger startSelectionOffset = 0;
  NSInteger endSelectionOffset = 0;
  [CardIOConfigurableTextFieldDelegate getSelectionInTextField:textField withSelectedTextRange:selectedTextRange forStart:&startSelectionOffset forEnd:&endSelectionOffset];
  
  NSString *correctedText = [self.formatter stringForObjectValue:[CardIOCreditCardNumber stringByRemovingNonNumbers:textField.text]];
  
  if (![correctedText isEqualToString:textField.text]) {
    textField.text = correctedText;
    
    if (selectedTextRange) {
      UITextPosition *startSelectionPosition = [CardIOConfigurableTextFieldDelegate positionInTextField:textField after:startSelectionOffset];
      UITextPosition *endSelectionPosition = [CardIOConfigurableTextFieldDelegate positionInTextField:textField after:endSelectionOffset];
      textField.selectedTextRange = [textField textRangeFromPosition:startSelectionPosition toPosition:endSelectionPosition];
    }
  }
  
  return YES;
}

#pragma mark - UITextFieldDelegate methods

- (void)textFieldDidEndEditing:(UITextField *)textField {
  [self cleanupTextField:textField];
  
  if(textField.text.length > 0) {
    textField.text = [self.formatter stringForObjectValue:textField.text];
  }
  
  [[NSNotificationCenter defaultCenter] postNotificationName:UITextFieldTextDidChangeNotification object:textField];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)newText {
  NSString *numericNewText = [CardIOCreditCardNumber stringByRemovingNonNumbers:newText];
  NSString* updatedText = [textField.text stringByReplacingCharactersInRange:range withString:numericNewText];

  CardIOCreditCardType cardType = [CardIOCreditCardNumber cardTypeForCardNumber:updatedText];
  if(cardType != CardIOCreditCardTypeUnrecognized && cardType != CardIOCreditCardTypeAmbiguous) {
    self.maxLength = [CardIOCreditCardNumber numberLengthForCardNumber:updatedText];
  }
                             
  if(self.maxLength < 0 || [[CardIOCreditCardNumber stringbyRemovingSpaces:updatedText] length] > self.maxLength) {
    self.maxLength = 16;
    [CardIOConfigurableTextFieldDelegate vibrate];
    return NO;
  }

  return YES;
}


@end
