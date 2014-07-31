//
//  CardIOModalActivityIndicator.h
//  See the file "LICENSE.md" for the full license governing this code.
//

#import <UIKit/UIKit.h>

@interface CardIOModalActivityIndicator : UIView {
@private
  UIActivityIndicatorView *spinner;
}

- (id)initWithText:(NSString *)text;

- (void)show;
- (void)showInView:(UIView*) view;

- (void)dismiss;

@end
