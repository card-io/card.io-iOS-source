//
//  CardIODataEntryViewController.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#import "CardIODataEntryViewController.h"
#import "CardIOContext.h"
#import "CardIOPaymentViewController.h"
#import "CardIOPaymentViewControllerContinuation.h"
#import "CardIONumbersTextFieldDelegate.h"
#import "CardIOCVVTextFieldDelegate.h"
#import "CardIOPostalCodeTextFieldDelegate.h"
#import "CardIOCreditCardNumber.h"
#import "CardIORowBasedTableViewSection.h"
#import "CardIOSectionBasedTableViewDelegate.h"
#import "CardIOCGGeometry.h"
#import "CardIOViewController.h"
#import "CardIOCreditCardInfo.h"
#import "CardIOMultipleFieldTableViewCell.h"
#import "CardIOExpiryTextFieldDelegate.h"
#import "CardIOCreditCardNumberFormatter.h"
#import "CardIOCreditCardExpiryFormatter.h"
#import "CardIOTableViewCell.h"
#import "CardIOStyles.h"
#import "CardIOMacros.h"
#import "CardIOAnalytics.h"
#import "CardIOLocalizer.h"
#import "CardIOOrientation.h"
#import "dmz_constants.h"

#define kStatusBarHeight  20
#define kiOS7TableViewBorderColor 0.78f
#define kMinimumDefaultRowWidth 320.0f

@interface CardIODataEntryViewController ()

- (void)cancel;
- (void)done;
- (BOOL)validate;
- (NSUInteger)cvvLength;
- (NSString *)cvvPlaceholder;

@property(nonatomic, assign, readwrite) BOOL statusBarHidden;
@property(nonatomic, strong, readwrite) UIScrollView *scrollView;
@property(nonatomic, strong, readwrite) UITableView *tableView;
@property(nonatomic, strong, readwrite) NSDictionary *inputViewInfo;
@property(nonatomic, strong, readwrite) NSMutableArray *visibleTextFields;
@property(nonatomic, strong, readwrite) CardIOSectionBasedTableViewDelegate *tableViewDelegate;
@property(nonatomic, strong, readwrite) CardIONumbersTextFieldDelegate *numberRowTextFieldDelegate;
@property(nonatomic, strong, readwrite) CardIOExpiryTextFieldDelegate* expiryTextFieldDelegate;
@property(nonatomic, strong, readwrite) CardIOCVVTextFieldDelegate *cvvRowTextFieldDelegate;
@property(nonatomic, strong, readwrite) CardIOPostalCodeTextFieldDelegate *postalCodeRowTextFieldDelegate;
@property(nonatomic, assign, readwrite) CGSize notificationSize;
@property(nonatomic, strong, readwrite) CardIOContext *context;
@property(nonatomic, assign, readwrite) CardIOCreditCardType cardTypeForLogo;
@property(nonatomic, assign, readwrite) CGRect relevantViewFrame;
@property(nonatomic, assign, readwrite) CGFloat oldHeight;
@property(nonatomic, weak, readwrite) UITextField *activeTextField;
@property(nonatomic, strong, readwrite) UIView *leftTableBorderForIOS7;
@property(nonatomic, strong, readwrite) UIView *rightTableBorderForIOS7;

@end


@implementation CardIODataEntryViewController

- (id)init {
  [NSException raise:@"Wrong initializer" format:@"CardIODataEntryViewController's designated initializer is initWithContext:"];
  return nil;
}

- (id)initWithContext:(CardIOContext *)aContext withStatusBarHidden:(BOOL)statusBarHidden {
  if((self = [super initWithNibName:nil bundle:nil])) {
    _cardInfo = [[CardIOCreditCardInfo alloc] init];
    _notificationSize = CGSizeZero;
    _context = aContext;
    _statusBarHidden = statusBarHidden;

    // set self.title in -viewDidLoad. the title is localized, which requires
    // access to the i18n context, but that is sometimes non-existent at this stage
    // (the developer sometimes hasn't even had the opportunity to tell us yet!).
  }
  return self;
}

- (void)calculateRelevantViewFrame {
  self.relevantViewFrame = self.view.bounds;

  if (!iOS_7_PLUS) {
    // On iOS 7, setting 'edgesForExtendedLayout = UIRectEdgeNone' takes care of the offset
    if (self.navigationController.navigationBar.translucent) {
      CGRect relevantViewFrame = self.view.bounds;
      CGFloat barsHeight = NavigationBarHeightForCurrentOrientation(self.navigationController);
      if (self.navigationController.modalPresentationStyle == UIModalPresentationFullScreen && !self.statusBarHidden) {
        barsHeight += kStatusBarHeight;
      }
      relevantViewFrame.origin.y += barsHeight;
      relevantViewFrame.size.height -= barsHeight;
      self.relevantViewFrame = relevantViewFrame;
    }
  }
}

- (void)viewDidLoad {
  [super viewDidLoad];

  if (iOS_7_PLUS) {
    self.automaticallyAdjustsScrollViewInsets = YES;
    self.edgesForExtendedLayout = UIRectEdgeNone;
  }
  else {
    self.wantsFullScreenLayout = YES;
  }

  [self calculateRelevantViewFrame];

  CardIOPaymentViewController *pvc = (CardIOPaymentViewController *)self.navigationController;
  self.title = CardIOLocalizedString(@"entry_title", self.context.languageOrLocale); // Enter card info

  // Need to set up the navItem here, because the OS calls the accessor before all the info needed to build it is available.

  BOOL showCancelButton = ([self.navigationController.viewControllers count] == 1);
  if(self.cardImage) {
    showCancelButton = YES;
  }

  if(showCancelButton) {
    NSString *cancelText = CardIOLocalizedString(@"cancel", self.context.languageOrLocale); // Cancel
    // show the cancel button if we've gone directly to manual entry.
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:cancelText style:UIBarButtonItemStyleBordered target:self action:@selector(cancel)];
  } else {
    // Show fake "back" button, since real back button takes us back to the animation view, not back to the camera
    NSString *cameraText = CardIOLocalizedString(@"camera", self.context.languageOrLocale); // Camera
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:cameraText style:UIBarButtonItemStyleBordered target:self action:@selector(popToTop)];
  }

  NSString *cardInfoText = CardIOLocalizedString(@"card_info", self.context.languageOrLocale); // Card Info
  self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:cardInfoText style:UIBarButtonItemStyleBordered target:nil action:nil];

  NSString *completionButtonTitle = CardIOLocalizedString(@"done", self.context.languageOrLocale); // Done

  UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithTitle:completionButtonTitle
                                                                 style:UIBarButtonItemStyleDone
                                                                target:self
                                                                action:@selector(done)];
  self.navigationItem.rightBarButtonItem = doneButton;
  self.navigationItem.rightBarButtonItem.enabled = NO;

  self.collectExpiry = pvc.collectExpiry;
  self.collectCVV = pvc.collectCVV;
  self.collectPostalCode = pvc.collectPostalCode;

  self.scrollView = [[UIScrollView alloc] initWithFrame:self.relevantViewFrame];

  if(!self.manualEntry) {
    self.cardView = [[UIImageView alloc] initWithImage:self.cardImage];
    self.cardView.bounds = CGRectZeroWithSize(CGSizeMake((CGFloat)ceil(self.floatingCardView.bounds.size.width),
                                                         (CGFloat)ceil(self.floatingCardView.bounds.size.height)));
    self.cardView.contentMode = UIViewContentModeScaleAspectFit;
    self.cardView.backgroundColor = kColorViewBackground;
    self.cardView.layer.cornerRadius = ((CGFloat) 9.0f) * (self.cardView.bounds.size.width / ((CGFloat) 300.0f)); // matches the card, adjusted for view size. (view is ~300 px wide on phone.)
    self.cardView.layer.masksToBounds = YES;
    self.cardView.layer.borderColor = [UIColor grayColor].CGColor;
    self.cardView.layer.borderWidth = 2.0f;

    self.cardView.hidden = YES;
    [self.scrollView addSubview:self.cardView];
  }

  self.tableView = [[UITableView alloc] initWithFrame:self.scrollView.bounds style:UITableViewStyleGrouped];
  self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
  self.tableView.scrollEnabled = NO;
  self.tableView.hidden = YES;

  // On iOS 7, remove the edge inset from the table for a more consistent appearance
  // when there are multiple inputs in a row.
  if (iOS_7_PLUS) {
    self.tableView.separatorInset = UIEdgeInsetsZero;
  }

  NSMutableArray *sections = [NSMutableArray arrayWithCapacity:1];
  self.visibleTextFields = [NSMutableArray arrayWithCapacity:4];

  NSMutableArray *rows = [NSMutableArray arrayWithCapacity:4];

  if(self.manualEntry) {
    CardIOMultipleFieldTableViewCell *numberRow = [[CardIOMultipleFieldTableViewCell alloc] init];
    numberRow.backgroundColor = kColorDefaultCell;
    numberRow.numberOfFields = 1;
    numberRow.hiddenLabels = YES;
    numberRow.textAlignment = [CardIOLocalizer textAlignmentForLanguageOrLocale:self.context.languageOrLocale];

    NSString* numberText = CardIOLocalizedString(@"entry_number", self.context.languageOrLocale); // Number
    [numberRow.labels addObject:numberText];

    self.numberTextField = [numberRow.textFields lastObject];
    [self.visibleTextFields addObject:self.numberTextField];

    self.numberRowTextFieldDelegate = [[CardIONumbersTextFieldDelegate alloc] init];
    self.numberTextField.delegate = self.numberRowTextFieldDelegate;
    self.numberTextField.placeholder = CardIOLocalizedString(@"entry_card_number", self.context.languageOrLocale); // Card Number
    self.numberTextField.text = self.cardInfo.cardNumber ? self.cardInfo.cardNumber : @"";
    self.numberTextField.keyboardType = UIKeyboardTypeNumberPad;
    self.numberTextField.clearButtonMode = UITextFieldViewModeNever;
    self.numberTextField.backgroundColor = kColorDefaultCell;
    self.numberTextField.textAlignment = [CardIOLocalizer textAlignmentForLanguageOrLocale:self.context.languageOrLocale];
    self.numberTextField.autocorrectionType = UITextAutocorrectionTypeNo;

    // For fancier masking (e.g., by number group rather than by individual digit),
    // put fancier functionality into CardIONumbersTextFieldDelegate instead of setting secureTextEntry.
    self.numberTextField.secureTextEntry = self.context.maskManualEntryDigits;

    [self updateCardLogo];

    [rows addObject:numberRow];
  }

  if(self.collectExpiry || self.collectCVV) {
    CardIOMultipleFieldTableViewCell *multiFieldRow = [[CardIOMultipleFieldTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    multiFieldRow.backgroundColor = kColorDefaultCell;
    multiFieldRow.textAlignment = [CardIOLocalizer textAlignmentForLanguageOrLocale:self.context.languageOrLocale];

    BOOL collectBoth = self.collectExpiry && self.collectCVV;
    BOOL bothInOneRow = NO;
    if (collectBoth) {
      NSString *expiryText = CardIOLocalizedString(@"entry_expires", self.context.languageOrLocale); // Expires
      NSString* cvvText = CardIOLocalizedString(@"entry_cvv", self.context.languageOrLocale); // CVV
      CGFloat fieldWidthForTwoFieldsPerRow = kMinimumDefaultRowWidth / 2;
      bothInOneRow = ([multiFieldRow textFitsInMultiFieldForLabel:@"" forPlaceholder:expiryText forFieldWidth:fieldWidthForTwoFieldsPerRow] &&
                      [multiFieldRow textFitsInMultiFieldForLabel:@"" forPlaceholder:cvvText forFieldWidth:fieldWidthForTwoFieldsPerRow]);
    }

    multiFieldRow.hiddenLabels = YES;

    if(self.collectExpiry) {
      multiFieldRow.numberOfFields++;
      NSString *expiryText = CardIOLocalizedString(@"entry_expires", self.context.languageOrLocale); // Expires
      [multiFieldRow.labels addObject:expiryText];
      self.expiryTextField = [multiFieldRow.textFields lastObject];
      [self.visibleTextFields addObject:self.expiryTextField];

      self.expiryTextFieldDelegate = [[CardIOExpiryTextFieldDelegate alloc] init];
      self.expiryTextField.delegate = self.expiryTextFieldDelegate;
      self.expiryTextField.placeholder = CardIOLocalizedString(@"expires_placeholder", self.context.languageOrLocale); // MM/YY
      // Add a space on each side of the slash. (Do this in code rather than in the string, because the L10n process won't preserve the spaces.)
      self.expiryTextField.placeholder = [self.expiryTextField.placeholder stringByReplacingOccurrencesOfString:@"/" withString:@" / "];
      self.expiryTextField.placeholder = [self.expiryTextField.placeholder stringByReplacingOccurrencesOfString:@"  " withString:@" "];
      self.expiryTextField.keyboardType = UIKeyboardTypeNumberPad;
      self.expiryTextField.textAlignment = [CardIOLocalizer textAlignmentForLanguageOrLocale:self.context.languageOrLocale];
      self.expiryTextField.autocorrectionType = UITextAutocorrectionTypeNo;

      if(self.cardInfo.expiryMonth > 0 && self.cardInfo.expiryYear > 0) {
        self.expiryTextField.text = [self.expiryTextFieldDelegate.formatter stringForObjectValue:self.cardInfo];
        if (![[self class] cardExpiryIsValid:self.cardInfo]) {
          self.expiryTextField.textColor = [UIColor redColor];
        }
      }
    }

    if (collectBoth && !bothInOneRow) {
      [rows addObject:multiFieldRow];
      multiFieldRow = [[CardIOMultipleFieldTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
      multiFieldRow.hiddenLabels = YES;
      multiFieldRow.backgroundColor = kColorDefaultCell;
      multiFieldRow.textAlignment = [CardIOLocalizer textAlignmentForLanguageOrLocale:self.context.languageOrLocale];
    }

    if(self.collectCVV) {
      multiFieldRow.numberOfFields++;
      if (bothInOneRow) {
        multiFieldRow.labelWidth = 0;
      }

      NSString* cvvText = CardIOLocalizedString(@"entry_cvv", self.context.languageOrLocale); // CVV
      [multiFieldRow.labels addObject:cvvText];
      self.cvvTextField = [multiFieldRow.textFields lastObject];
      [self.visibleTextFields addObject:self.cvvTextField];

      self.cvvRowTextFieldDelegate = [[CardIOCVVTextFieldDelegate alloc] init];
      self.cvvRowTextFieldDelegate.maxLength = [self cvvLength];

      self.cvvTextField.delegate = self.cvvRowTextFieldDelegate;
      self.cvvTextField.placeholder = cvvText;
      self.cvvTextField.text = self.cardInfo.cvv;
      self.cvvTextField.keyboardType = UIKeyboardTypeNumberPad;
      self.cvvTextField.clearButtonMode = UITextFieldViewModeNever;
      self.cvvTextField.text = @"";
      self.cvvTextField.textAlignment = [CardIOLocalizer textAlignmentForLanguageOrLocale:self.context.languageOrLocale];
      self.cvvTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    }

    [rows addObject:multiFieldRow];
  }

  if(self.collectPostalCode) {
    CardIOMultipleFieldTableViewCell *postalCodeRow = [[CardIOMultipleFieldTableViewCell alloc] init];
    postalCodeRow.backgroundColor = kColorDefaultCell;
    postalCodeRow.numberOfFields = 1;
    postalCodeRow.hiddenLabels = YES;
    postalCodeRow.textAlignment = [CardIOLocalizer textAlignmentForLanguageOrLocale:self.context.languageOrLocale];

    NSString *postalCodeText = CardIOLocalizedString(@"entry_postal_code", self.context.languageOrLocale); // Postal Code
    [postalCodeRow.labels addObject:postalCodeText];

    self.postalCodeTextField = [postalCodeRow.textFields lastObject];
    [self.visibleTextFields addObject:self.postalCodeTextField];

    self.postalCodeRowTextFieldDelegate = [[CardIOPostalCodeTextFieldDelegate alloc] init];
    self.postalCodeTextField.placeholder = postalCodeText;
    self.postalCodeTextField.delegate = self.postalCodeRowTextFieldDelegate;
    self.postalCodeTextField.text = self.cardInfo.postalCode;
    self.postalCodeTextField.keyboardType = UIKeyboardTypeNumbersAndPunctuation;
    self.postalCodeTextField.clearButtonMode = UITextFieldViewModeNever;
    self.postalCodeTextField.text = @"";
    self.postalCodeTextField.textAlignment = [CardIOLocalizer textAlignmentForLanguageOrLocale:self.context.languageOrLocale];
    self.postalCodeTextField.autocorrectionType = UITextAutocorrectionTypeNo;

    [rows addObject:postalCodeRow];
  }

  CardIORowBasedTableViewSection *infoSection = [[CardIORowBasedTableViewSection alloc] init];
  infoSection.rows = rows;
  [sections addObject:infoSection];

  self.tableViewDelegate = [[CardIOSectionBasedTableViewDelegate alloc] init];
  self.tableViewDelegate.sections = sections;

  self.tableView.delegate = self.tableViewDelegate;
  self.tableView.dataSource = self.tableViewDelegate;
  self.tableView.backgroundColor = kColorViewBackground;
  self.tableView.opaque = YES;

  self.view.backgroundColor = kColorViewBackground;

  UIView *background = [[UIView alloc] initWithFrame:self.tableView.bounds];
  background.backgroundColor = kColorViewBackground;
  self.tableView.backgroundView = background;

  [self.scrollView addSubview:self.tableView];

  if (iOS_7_PLUS) {
    self.leftTableBorderForIOS7 = [[UIView alloc] init];
    self.leftTableBorderForIOS7.backgroundColor = [UIColor colorWithWhite:kiOS7TableViewBorderColor alpha:1];
    self.leftTableBorderForIOS7.hidden = YES;
    [self.scrollView addSubview:self.leftTableBorderForIOS7];

    self.rightTableBorderForIOS7 = [[UIView alloc] init];
    self.rightTableBorderForIOS7.backgroundColor = [UIColor colorWithWhite:kiOS7TableViewBorderColor alpha:1];
    self.rightTableBorderForIOS7.hidden = YES;
    [self.scrollView addSubview:self.rightTableBorderForIOS7];
  }

  if (self.cardView) {
    // Animations look better if the cardView is in front of the tableView
    [self.scrollView bringSubviewToFront:self.cardView];
  }

  [self.view addSubview:self.scrollView];
}

- (void)viewWillAppear:(BOOL)animated {
  if ([UIApplication sharedApplication].statusBarOrientation != (UIInterfaceOrientation)[UIDevice currentDevice].orientation) {
    // Force interface to rotate to match current device orientation, following portrait-only camera view.
    [[NSNotificationCenter defaultCenter] postNotificationName:UIDeviceOrientationDidChangeNotification object:nil];
  }

  [super viewWillAppear:animated];

  if (self.navigationController.modalPresentationStyle == UIModalPresentationFullScreen && !self.statusBarHidden) {
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
    if (iOS_7_PLUS) {
      [self setNeedsStatusBarAppearanceUpdate];
    }
  }

  if (!self.context.keepStatusBarStyle) {
    if (iOS_7_PLUS) {
      [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleDefault;
    }
    else {
      [UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleLightContent;
    }
  }

  [self.navigationController setNavigationBarHidden:NO animated:animated];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];

  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillMove:) name:UIKeyboardWillShowNotification object:nil];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillMove:) name:UIKeyboardWillHideNotification object:nil];

  if(self.manualEntry) {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(cardNumberDidChange:)
                                                 name:UITextFieldTextDidChangeNotification
                                               object:self.numberTextField];
  }
  if(self.collectExpiry) {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(expiryDidChange:)
                                                 name:UITextFieldTextDidChangeNotification
                                               object:self.expiryTextField];
  }
  if(self.collectCVV) {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(cvvDidChange:)
                                                 name:UITextFieldTextDidChangeNotification
                                               object:self.cvvTextField];
  }
  if(self.collectPostalCode) {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(postalCodeDidChange:)
                                                 name:UITextFieldTextDidChangeNotification
                                               object:self.postalCodeTextField];
  }

  [self layoutForCurrentOrientation];

  if (self.floatingCardView) {
    if (self.cardView) {
      CGRect  newCardViewFrame = self.cardView.frame; // as set above by [self layoutForCurrentOrientation]
      CGRect  cardFrameInView = [self.view convertRect:self.floatingCardView.frame fromView:self.floatingCardView.superview];
      self.cardView.frame = cardFrameInView;  // start the animation with the card appearing as in the CardIOTransitionView

      self.cardView.hidden = NO;
      self.floatingCardWindow.hidden = YES;
      self.floatingCardView = nil;
      self.floatingCardWindow = nil;
      self.priorKeyWindow = nil;

      if ([self.tableView numberOfRowsInSection:0] > 0) {
        self.tableView.alpha = 0;
        self.tableView.hidden = NO;
        [self showTableBorders:NO];
      }

      [UIView animateWithDuration:0.4
                       animations:^{
                         self.cardView.frame = newCardViewFrame;
                         self.tableView.alpha = 1;
                       }
                       completion:^(BOOL finished) {
                         [self showTableBorders:YES];
                         int64_t delay = [self isWideScreenMode] ? (int64_t)(0.2f * NSEC_PER_SEC) : 0;
                         dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay), dispatch_get_main_queue(), ^(void){
                           [self advanceToNextEmptyFieldFrom:nil];
                         });
                       }];
    }
    else {
      // It's slightly nicer to animate this transition from floating card view to table view,
      // but in widescreen mode there's a simultaneous viewcontroller rotation involved that
      // makes things messy. (The floating card view rotates to portrait mode before fading away.)
      if ([self isWideScreenMode]) {
        self.tableView.alpha = 1;
        self.tableView.hidden = NO;
        [self showTableBorders:YES];
        self.floatingCardWindow.alpha = 0;
        self.floatingCardWindow.hidden = YES;
        self.floatingCardView = nil;
        self.floatingCardWindow = nil;
        self.priorKeyWindow = nil;
      }
      else {
        self.tableView.alpha = 0;
        self.tableView.hidden = NO;
        [self showTableBorders:NO];

        [UIView animateWithDuration:0.4
                         animations:^{
                           self.tableView.alpha = 1;
                           self.floatingCardWindow.alpha = 0;
                         }
                         completion:^(BOOL finished) {
                           [self showTableBorders:YES];
                           self.floatingCardWindow.hidden = YES;
                           self.floatingCardView = nil;
                           self.floatingCardWindow = nil;
                           self.priorKeyWindow = nil;
                         }];
      }

      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
        [self advanceToNextEmptyFieldFrom:nil];
      });
    }
  }
  else {
    self.tableView.alpha = 1;
    self.tableView.hidden = NO;
    [self showTableBorders:YES];
    [self advanceToNextEmptyFieldFrom:nil];
  }

  [self validate];
}

- (void)keyboardWillMove:(NSNotification *)inputViewNotification {
  CGRect inputViewFrame = [[[inputViewNotification userInfo] valueForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];

  CGRect inputViewFrameInView = [self.view convertRect:inputViewFrame fromView:nil];
  CGRect intersection = CGRectIntersection(self.scrollView.frame, inputViewFrameInView);

  UIEdgeInsets ei = UIEdgeInsetsMake(0.0, 0.0, intersection.size.height, 0.0);
  self.scrollView.scrollIndicatorInsets = ei;
  self.scrollView.contentInset = ei;

  CGRect scrollTo = [self.tableView rectForSection:0];
  scrollTo = [self.scrollView convertRect:scrollTo fromView:self.tableView];
  if (scrollTo.size.height <= inputViewFrameInView.origin.y) {
    [self.scrollView scrollRectToVisible:scrollTo animated:YES];
  }
  else {
    scrollTo.size.height = 1;
    for (NSUInteger index = 0; index < self.visibleTextFields.count; index++) {
      if ([self.visibleTextFields[index] isEditing]) {
        UITextField *textField = ((UITextField *)self.visibleTextFields[index]);
        scrollTo = textField.bounds;
        scrollTo = [self.scrollView convertRect:scrollTo fromView:textField];
        break;
      }
    }
    [self.scrollView scrollRectToVisible:scrollTo animated:YES];
  }
}

- (void)viewWillDisappear:(BOOL)animated {
  [super viewWillDisappear:animated];

  for(UITextField *tf in self.visibleTextFields) {
    [tf resignFirstResponder];
  }

  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidUnload {
  self.tableView.delegate = nil, self.tableView.dataSource = nil, self.tableView = nil;

  self.tableViewDelegate = nil;
  self.numberRowTextFieldDelegate = nil;
  self.expiryTextFieldDelegate = nil;
  self.cvvRowTextFieldDelegate = nil;
  self.postalCodeRowTextFieldDelegate = nil;

  self.expiryTextField = nil;
  self.numberTextField = nil;
  self.cvvTextField = nil;
  self.postalCodeTextField = nil;

  self.visibleTextFields = nil;

  [super viewDidUnload];
}

#pragma mark - orientation-based subview layout

- (BOOL)isWideScreenMode {
  return ((self.navigationController.modalPresentationStyle == UIModalPresentationFullScreen)
          && UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation]));
}

- (void)showTableBorders:(BOOL)showTableBorders {
  if (iOS_7_PLUS) {
    self.leftTableBorderForIOS7.hidden = !showTableBorders;
    self.rightTableBorderForIOS7.hidden = !showTableBorders;
  }
}

- (void)layoutForCurrentOrientation {
  self.oldHeight = self.view.bounds.size.height;

  [self calculateRelevantViewFrame];
  self.scrollView.frame = self.relevantViewFrame;

  if (self.cardView) {
    CGRect cardViewFrame = self.cardView.frame;
    CGRect tableViewFrame = self.tableView.frame;
    BOOL showTableView = ([self.tableView numberOfRowsInSection:0] > 0);

    if ([self isWideScreenMode]) {
      cardViewFrame.size.width = (CGFloat)floor(MAX(self.scrollView.bounds.size.width, self.scrollView.bounds.size.height) * kLandscapeZoomedInCardImageSizePercent);
      cardViewFrame.size.height = (CGFloat)floor(self.cardImage.size.height * (cardViewFrame.size.width / self.cardImage.size.width));
      if (!showTableView) {
        cardViewFrame.size.width *= 1.5;
        cardViewFrame.size.height *= 1.5;
      }
    }
    else {
      cardViewFrame.size.width = (CGFloat)floor(self.scrollView.bounds.size.width * kPortraitZoomedInCardImageSizePercent);
      cardViewFrame.size.height = (CGFloat)floor(self.cardImage.size.height * (cardViewFrame.size.width / self.cardImage.size.width));
    }

    if (showTableView) {
      if ([self isWideScreenMode]) {
        cardViewFrame.origin.x = kCardPadding;
        cardViewFrame.origin.y = kCardPadding;

        tableViewFrame.size.width = (CGFloat)(self.scrollView.bounds.size.width - cardViewFrame.size.width - 3 * kCardPadding);
        tableViewFrame.size.height = self.scrollView.bounds.size.height;
        tableViewFrame.origin.x = CGRectGetMaxX(self.scrollView.bounds) - tableViewFrame.size.width - kCardPadding;

        if (iOS_7_PLUS) {
          NSInteger lastSection = [self.tableView numberOfSections] - 1;
          NSInteger lastRow = [self.tableView numberOfRowsInSection:lastSection] - 1;
          UITableViewCell *firstCell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
          UITableViewCell *lastCell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:lastRow inSection:lastSection]];
          tableViewFrame.origin.y = kCardPadding - firstCell.frame.origin.y;

          CGRect leftTableBorderFrame = self.leftTableBorderForIOS7.frame;
          leftTableBorderFrame.origin.x = tableViewFrame.origin.x - 0.5f;
          leftTableBorderFrame.origin.y = tableViewFrame.origin.y + firstCell.frame.origin.y;
          leftTableBorderFrame.size.height = lastCell.frame.origin.y + lastCell.frame.size.height - firstCell.frame.origin.y + 0.5f;
          leftTableBorderFrame.size.width = 0.5f;
          self.leftTableBorderForIOS7.frame = leftTableBorderFrame;

          CGRect rightTableBorderFrame = leftTableBorderFrame;
          rightTableBorderFrame.origin.x = tableViewFrame.origin.x + tableViewFrame.size.width;
          self.rightTableBorderForIOS7.frame = rightTableBorderFrame;
        }
        else {
          tableViewFrame.origin.y = 0;
        }
      }
      else {
        cardViewFrame.origin.x = (CGFloat)floor((self.scrollView.bounds.size.width - cardViewFrame.size.width) / 2);
        cardViewFrame.origin.y = (CGFloat)floor(kCardPadding / 2);

        tableViewFrame = self.scrollView.bounds;
        tableViewFrame.origin.y = CGRectGetMaxY(cardViewFrame);

        if (iOS_7_PLUS) {
          CGRect tableBorderFrame = CGRectMake(0, 0, 0, 0);
          self.leftTableBorderForIOS7.frame = tableBorderFrame;
          self.rightTableBorderForIOS7.frame = tableBorderFrame;
        }
      }
    }
    else {
      cardViewFrame.origin.x = (CGFloat)floor((self.scrollView.frame.size.width - cardViewFrame.size.width) / 2);
      cardViewFrame.origin.y = (CGFloat)floor((self.scrollView.frame.size.height - cardViewFrame.size.height) / 3);
      tableViewFrame = CGRectZero;
    }

    self.cardView.frame = cardViewFrame;
    self.tableView.frame = tableViewFrame;

    self.scrollView.contentSize = CGSizeMake(self.scrollView.bounds.size.width,
                                             MAX(self.tableView.frame.origin.y + CGRectGetMaxY([self.tableView rectForSection:0]), CGRectGetMaxY(self.cardView.frame)));
  }
  else {
    CGRect tableViewFrame;

    if ([self isWideScreenMode]) {
      CGFloat tableWidth = MAX((CGFloat)floor(self.scrollView.bounds.size.width / 2), 400);

      tableViewFrame.size.width = tableWidth;
      tableViewFrame.size.height = self.scrollView.bounds.size.height;
      tableViewFrame.origin.x = (CGFloat)floor((self.scrollView.bounds.size.width - tableWidth) / 2);
      tableViewFrame.origin.y = 0;

      if (iOS_7_PLUS) {
        NSInteger lastSection = [self.tableView numberOfSections] - 1;
        NSInteger lastRow = [self.tableView numberOfRowsInSection:lastSection] - 1;
        UITableViewCell *firstCell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
        UITableViewCell *lastCell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:lastRow inSection:lastSection]];

        CGRect leftTableBorderFrame = self.leftTableBorderForIOS7.frame;
        leftTableBorderFrame.origin.x = tableViewFrame.origin.x - 0.5f;
        leftTableBorderFrame.origin.y = tableViewFrame.origin.y + firstCell.frame.origin.y;
        leftTableBorderFrame.size.height = lastCell.frame.origin.y + lastCell.frame.size.height - firstCell.frame.origin.y;
        leftTableBorderFrame.size.width = 0.5f;
        self.leftTableBorderForIOS7.frame = leftTableBorderFrame;

        CGRect rightTableBorderFrame = leftTableBorderFrame;
        rightTableBorderFrame.origin.x = tableViewFrame.origin.x + tableViewFrame.size.width;
        self.rightTableBorderForIOS7.frame = rightTableBorderFrame;
      }
    }
    else {
      tableViewFrame = self.scrollView.bounds;

      if (iOS_7_PLUS) {
        CGRect tableBorderFrame = CGRectMake(0, 0, 0, 0);
        self.leftTableBorderForIOS7.frame = tableBorderFrame;
        self.rightTableBorderForIOS7.frame = tableBorderFrame;
      }
    }

    self.tableView.frame = tableViewFrame;

    self.scrollView.contentSize = CGSizeMake(self.scrollView.bounds.size.width,
                                             self.tableView.frame.origin.y + CGRectGetMaxY([self.tableView rectForSection:0]));
  }
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
  self.activeTextField = nil;
  for(UITextField *textField in self.visibleTextFields) {
    if ([textField isFirstResponder]) {
      self.activeTextField = textField;
      [textField resignFirstResponder];
      break;
    }
  }

  [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
  [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];

  if (self.view.bounds.size.height != self.oldHeight) {
    [self showTableBorders:NO];

    [UIView animateWithDuration:0.4
                     animations:^{
                       [self layoutForCurrentOrientation];
                     }
                     completion:^(BOOL finished) {
                       [self showTableBorders:YES];
                     }];
  }

  [self.activeTextField becomeFirstResponder];
}

#pragma mark - Status bar preferences (iOS 7)

- (UIStatusBarStyle) preferredStatusBarStyle {
  return UIStatusBarStyleDefault;
}

- (BOOL)prefersStatusBarHidden {
  return self.statusBarHidden;
}

#pragma mark -

- (void)popToTop {
  if (iOS_7_PLUS) {
    // iOS 7 apparently has a quirk in which keyboard dismisses only after the pop.
    // We fix this by explicitly calling resignFirstResponder on all fields
    // to ensure keyboard dismisses immediately.
    for (UITextField *field in self.visibleTextFields) {
      [field resignFirstResponder];
    }
  }

  if (iOS_7_PLUS) {
    // On iOS 7, looks better if we start sliding away the nav bar prior to transitioning to camera-view.
    [self.navigationController setNavigationBarHidden:YES animated:YES];
  }

  ((CardIOPaymentViewController *)self.navigationController).currentViewControllerIsDataEntry = NO;
  ((CardIOPaymentViewController *)self.navigationController).initialInterfaceOrientationForViewcontroller = [UIApplication sharedApplication].statusBarOrientation;
  [self.navigationController popToRootViewControllerAnimated:YES];
}

- (void)cancel {
  CardIOPaymentViewController *pvc = (CardIOPaymentViewController *)self.navigationController;
  [pvc.paymentDelegate userDidCancelPaymentViewController:pvc];
}

- (void)done {
  if(self.manualEntry) {
    self.cardInfo.cardNumber = [CardIOCreditCardNumber stringByRemovingNonNumbers:self.numberTextField.text];
  }

  self.cardInfo.cvv = self.cvvTextField.text;
  self.cardInfo.postalCode = [self.postalCodeTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

  CardIOPaymentViewController *pvc = (CardIOPaymentViewController *)self.navigationController;
  [pvc.paymentDelegate userDidProvideCreditCardInfo:self.cardInfo inPaymentViewController:pvc];
}

- (void)advanceToNextEmptyFieldFrom:(id)fromField {
  NSUInteger startIndex = 0;

  // Define start index
  if (fromField) {
    NSUInteger indexOfSender = [self.visibleTextFields indexOfObject:fromField];
    if (indexOfSender != NSNotFound) {
      startIndex = indexOfSender + 1;
      if (startIndex >= self.visibleTextFields.count) {
        startIndex = 0;
      }
    }
  }
  // Iterate through
  for (NSUInteger i = startIndex; i < self.visibleTextFields.count; i++) {
    UITextField *tf = self.visibleTextFields[i];
    if(tf.text.length == 0) {
      [tf becomeFirstResponder];
      break;
    }
  }
}

- (void)cardNumberDidChange:(id)sender {
  static BOOL recursionBlock = NO;
  if (recursionBlock) {
    return;
  }

  BOOL fieldIsInFlux = ![self.numberRowTextFieldDelegate cleanupTextField:self.numberTextField];

  CardIOCreditCardInfo *cleanedInfo = self.cardInfo;
  [self.numberRowTextFieldDelegate.formatter getObjectValue:&cleanedInfo forString:self.numberTextField.text errorDescription:nil];
  self.cardInfo = cleanedInfo;

  self.cvvRowTextFieldDelegate.maxLength = [self cvvLength];
  [self updateCvvColor];

  CardIOCreditCardType cardType = [CardIOCreditCardNumber cardTypeForCardNumber:self.cardInfo.cardNumber];

  if([CardIOCreditCardNumber isValidNumber:self.cardInfo.cardNumber]) {
    if (!fieldIsInFlux) {
      recursionBlock = YES;
      [self advanceToNextEmptyFieldFrom:self.numberTextField];
      recursionBlock = NO;
    }
    self.numberTextField.textColor = [CardIOTableViewCell defaultDetailTextLabelColorForCellStyle:[CardIOTableViewCell defaultCellStyle]];
  } else if ([self.cardInfo.cardNumber length] > 0 &&
             ((cardType == CardIOCreditCardTypeUnrecognized && [self.cardInfo.cardNumber length] == 16) ||
              self.cardInfo.cardNumber.length == [CardIOCreditCardNumber numberLengthForCardNumber:self.cardInfo.cardNumber])) {
               self.numberTextField.textColor = [UIColor redColor];
             } else {
               self.numberTextField.textColor = [CardIOTableViewCell defaultDetailTextLabelColorForCellStyle:[CardIOTableViewCell defaultCellStyle]];
             }

  [self updateCardLogo];

  [self validate];
}

- (void)updateCardLogo {
  NSString              *cardNumber = [CardIOCreditCardNumber stringbyRemovingSpaces:_numberTextField.text];
  CardIOCreditCardType  cardType = [CardIOCreditCardNumber cardTypeForCardNumber:cardNumber];
  if (_cardTypeForLogo != cardType) {
    self.cardTypeForLogo = cardType;
    UIImage *cardLogo = [CardIOCreditCardInfo logoForCardType:cardType];
    if (cardLogo) {
      UIImageView*	logoView = [[UIImageView alloc] initWithImage:cardLogo];
      logoView.contentMode = UIViewContentModeScaleAspectFit;
      logoView.bounds = CGRectMake(0, 0, cardLogo.size.width, cardLogo.size.height);
      logoView.accessibilityLabel = [CardIOCreditCardInfo displayStringForCardType:cardType usingLanguageOrLocale:self.context.languageOrLocale];
      logoView.isAccessibilityElement = YES;

      _numberTextField.rightView = logoView;
      _numberTextField.rightViewMode = UITextFieldViewModeAlways;
    }
    else {
      _numberTextField.rightView = nil;
      _numberTextField.rightViewMode = UITextFieldViewModeNever;
    }
  }
}

- (void)expiryDidChange:(id)sender {
  static BOOL recursionBlock = NO;
  if (recursionBlock) {
    return;
  }

  BOOL fieldIsInFlux = ![self.expiryTextFieldDelegate cleanupTextField:self.expiryTextField];

  CardIOCreditCardInfo *cleanedInfo = self.cardInfo;
  [self.expiryTextFieldDelegate.formatter getObjectValue:&cleanedInfo forString:self.expiryTextField.text errorDescription:nil];
  self.cardInfo = cleanedInfo;

  if([[self class] cardExpiryIsValid:self.cardInfo] ) {
    if (!fieldIsInFlux) {
      recursionBlock = YES;
      [self advanceToNextEmptyFieldFrom:self.expiryTextField];
      recursionBlock = NO;
    }
    self.expiryTextField.textColor = [CardIOTableViewCell defaultDetailTextLabelColorForCellStyle:[CardIOTableViewCell defaultCellStyle]];
  } else if(self.expiryTextField.text.length >= 7) {
    self.expiryTextField.textColor = [UIColor redColor];
  } else {
    self.expiryTextField.textColor = [CardIOTableViewCell defaultDetailTextLabelColorForCellStyle:[CardIOTableViewCell defaultCellStyle]];
  }

  [self validate];
}

- (void)cvvDidChange:(id)sender {
  self.cardInfo.cvv = self.cvvTextField.text;

  [self updateCvvColor];

  CardIOCreditCardType cardType = [CardIOCreditCardNumber cardTypeForCardNumber:self.cardInfo.cardNumber];
  if(cardType != CardIOCreditCardTypeUnrecognized && cardType != CardIOCreditCardTypeAmbiguous &&
     [CardIOCVVTextFieldDelegate isValidCVV:self.cardInfo.cvv forNumber:self.cardInfo.cardNumber]) {
    [self advanceToNextEmptyFieldFrom:self.cvvTextField];
  }

  [self validate];
}

- (void)updateCvvColor {
  if([CardIOCVVTextFieldDelegate isValidCVV:self.cardInfo.cvv forNumber:self.cardInfo.cardNumber]) {
    self.cvvTextField.textColor = [CardIOTableViewCell defaultDetailTextLabelColorForCellStyle:[CardIOTableViewCell defaultCellStyle]];
  } else if(self.cvvTextField.text.length > [self cvvLength]) {
    self.cvvTextField.textColor = [UIColor redColor];
  } else {
    self.cvvTextField.textColor = [CardIOTableViewCell defaultDetailTextLabelColorForCellStyle:[CardIOTableViewCell defaultCellStyle]];
  }
}

- (void)postalCodeDidChange:(id)sender {
  self.cardInfo.postalCode = [self.postalCodeTextField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];

  // For globalization, we can't be sure of a valid postalCode length. So for now we'll skip all of this.
  //
  //  if([CardIOPostalCodeTextFieldDelegate isValidPostalCode:self.cardInfo.postalCode]) {
  //    [self advanceToNextEmptyFieldFrom:self.postalCodeTextField];
  //    self.postalCodeTextField.textColor = [CardIOTableViewCell defaultDetailTextLabelColorForCellStyle:[CardIOTableViewCell defaultCellStyle]];
  //  } else if(self.postalCodeTextField.text.length >= 5) {
  //    // probably won't reach this case, since length == 5 is the only validation rule, but we'll leave it here for consitency and for future enhancements.
  //    self.postalCodeTextField.textColor = [UIColor redColor];
  //  } else {
  //    self.postalCodeTextField.textColor = [CardIOTableViewCell defaultDetailTextLabelColorForCellStyle:[CardIOTableViewCell defaultCellStyle]];
  //  }

  [self validate];
}

- (BOOL)validate {
  BOOL numberIsValid = !self.manualEntry || [CardIOCreditCardNumber isValidNumber:self.cardInfo.cardNumber];
  BOOL expiryIsValid = !self.expiryTextField || [[self class] cardExpiryIsValid:self.cardInfo];
  BOOL cvvIsValid = !self.cvvTextField || [CardIOCVVTextFieldDelegate isValidCVV:self.cardInfo.cvv forNumber:self.cardInfo.cardNumber];
  BOOL postalCodeIsValid = !self.postalCodeTextField || [CardIOPostalCodeTextFieldDelegate isValidPostalCode:self.cardInfo.postalCode];
  BOOL isValid = numberIsValid && expiryIsValid && cvvIsValid && postalCodeIsValid;
  self.navigationItem.rightBarButtonItem.enabled = isValid;

  return isValid;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

// this could maybe become a property of CardIOCreditCardInfo, but that's public facing....
+ (BOOL)cardExpiryIsValid:(CardIOCreditCardInfo*)info {

  if(info.expiryMonth == 0 || info.expiryYear == 0) {
    return NO;
  }

  // we are under the assumption of a normal US calendar
  NSCalendar *cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];

  NSDateComponents *expiryComponents = [[NSDateComponents alloc] init];
  [expiryComponents setMonth:info.expiryMonth + 1]; // +1 to account for cards expiring "this month"
  [expiryComponents setYear:info.expiryYear];

  NSDate* expiryDate = [cal dateFromComponents:expiryComponents];

  if([expiryDate compare:[NSDate date]] == NSOrderedAscending) {
    return NO; // card is expired
  }

  NSDate *fifteenYearsFromNow = [[NSDate date] dateByAddingTimeInterval:3600 * 24 * 365.25 * 15]; // seconds/hr * hrs/day * days/yr * 15 (which roughly accounts for leap years, but without being very fussy about it)

  if([expiryDate compare:fifteenYearsFromNow] == NSOrderedDescending) {
    return NO; // expiry is more than 15 years out.
  }

  return YES;
}

- (NSUInteger)cvvLength {
  NSInteger cvvLength = [CardIOCreditCardNumber cvvLengthForCardType:self.cardInfo.cardType];
  if(cvvLength <= 0) {
    cvvLength = 4;
  }
  return cvvLength;
}

- (NSString *)cvvPlaceholder {
  return [@"1234567890" substringToIndex:[self cvvLength]];
}

@end
