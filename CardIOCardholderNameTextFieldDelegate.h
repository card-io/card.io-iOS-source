//
//  CardIOConfigurableTextFieldDelegate.h
//  See the file "LICENSE.md" for the full license governing this code.
//

#import "CardIOConfigurableTextFieldDelegate.h"

@interface CardIOCardholderNameTextFieldDelegate : CardIOConfigurableTextFieldDelegate {
	
}

+(BOOL)isValidCardholderName:(NSString*)cardholderName;

@end
