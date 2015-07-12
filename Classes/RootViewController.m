//
//  RootViewController.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#import "RootViewController.h"
#import "iccChoicesSelectViewController.h"
#import "CardIO.h"
#import "CardIOCGGeometry.h"
#import "TestGeneratedModels.h"

#if CARDIO_DEBUG
#import "CardIOLocalizer.h"
#import "CardIOPaymentViewControllerContinuation.h"
#endif

#define TEST_HIDEABLE_CARDIOVIEW 1

#pragma mark -

@interface RootViewController ()

@property(nonatomic, strong, readwrite) IBOutlet UIButton *scanButton;
@property(nonatomic, strong, readwrite) IBOutlet UIButton *scanPicoPikaButton;
@property(nonatomic, strong, readwrite) IBOutlet UISwitch *manualSwitch;
@property(nonatomic, strong, readwrite) IBOutlet UISwitch *expirySwitch;
@property(nonatomic, strong, readwrite) IBOutlet UISwitch *cvvSwitch;
@property(nonatomic, strong, readwrite) IBOutlet UISwitch *zipSwitch;
@property(nonatomic, strong, readwrite) IBOutlet UILabel *outcomeLabel;
@property(nonatomic, strong, readwrite) IBOutlet UIImageView *cardImageView;
@property(nonatomic, strong, readwrite) IBOutlet UISwitch *processSwitch;
@property(nonatomic, strong, readwrite) IBOutlet UISwitch *confirmSwitch;
@property(nonatomic, strong, readwrite) IBOutlet UISwitch *hideCardImageSwitch;
@property(nonatomic, strong, readwrite) IBOutlet UISwitch *redactSwitch;
@property(nonatomic, strong, readwrite) IBOutlet UISwitch *disableManualEntrySwitch;
@property(nonatomic, strong, readwrite) IBOutlet UISwitch *useCardIOLogoSwitch;
@property(nonatomic, strong, readwrite) IBOutlet UISwitch *doABTestingSwitch;
@property(nonatomic, strong, readwrite) IBOutlet UISegmentedControl *modalPresentationStyleSegment;
@property(nonatomic, strong, readwrite) IBOutlet UITextField *scannedImageDurationField;
@property(nonatomic, strong, readwrite) IBOutlet CardIOView *hideableCardIOView;

@property(nonatomic, strong, readwrite) IBOutlet UIButton *languageButton;
@property(nonatomic, strong, readwrite) NSString *language;

@property(nonatomic, strong, readwrite) CardIOView *adHocCardIOView;

@property(nonatomic, assign, readwrite) CGFloat originalOutcomeLabelWidth;

@property(nonatomic, assign, readwrite) BOOL        i18nAutopilot;
@property(nonatomic, strong, readwrite) NSArray    *i18nLanguages;
@property(nonatomic, assign, readwrite) NSInteger   i18nLanguageIndex;
@property(nonatomic, assign, readwrite) NSInteger   i18nPhase;
@property(nonatomic, strong, readwrite) CardIOPaymentViewController *i18nCardIOPaymentViewController;
@property(nonatomic, strong, readwrite) UIAlertView *i18nAlertView;
@property(nonatomic, strong, readwrite) UIView      *i18nAlertViewBackground;

@end


#pragma mark -

@implementation RootViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
  if((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didReceiveWillResignActiveNotification:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:[UIApplication sharedApplication]];
#if !CARDIO_DEBUG
    self.doABTestingSwitch.enabled = NO;
#endif
  }
  return self;
}

- (IBAction)scan {
  CardIOPaymentViewController *paymentVC = [[CardIOPaymentViewController alloc] initWithPaymentDelegate:self scanningEnabled:!self.manualSwitch.on];
  paymentVC.collectExpiry = self.expirySwitch.on;
  paymentVC.collectCVV = self.cvvSwitch.on;
  paymentVC.collectPostalCode = self.zipSwitch.on;
  paymentVC.disableManualEntryButtons = self.disableManualEntrySwitch.on;
  paymentVC.useCardIOLogo = self.useCardIOLogoSwitch.on;
  paymentVC.allowFreelyRotatingCardGuide = NO;
  paymentVC.scannedImageDuration = [self.scannedImageDurationField.text floatValue];
#if CARDIO_DEBUG
  paymentVC.doABTesting = self.doABTestingSwitch.on;
#endif

  paymentVC.languageOrLocale = self.language;

  paymentVC.suppressScanConfirmation = self.confirmSwitch ? !self.confirmSwitch.on : NO;
  paymentVC.suppressScannedCardImage = self.hideCardImageSwitch ? self.hideCardImageSwitch.on : NO;
  paymentVC.maskManualEntryDigits = self.doABTestingSwitch.on;

  if (self.modalPresentationStyleSegment) {
    paymentVC.modalPresentationStyle = (UIModalPresentationStyle)self.modalPresentationStyleSegment.selectedSegmentIndex;
  }
  
  [self presentViewController:paymentVC animated:YES completion:nil];
}

- (IBAction)scanPicoPika {
#if TEST_HIDEABLE_CARDIOVIEW
  if (!self.hideableCardIOView.hidden) {
    self.hideableCardIOView.hidden = YES;
    return;
  }
#else
  if (self.adHocCardIOView) {
    [self.adHocCardIOView removeFromSuperview];
    self.adHocCardIOView = nil;
    return;
  }
#endif


  CardIOView *cardIOView;
#if TEST_HIDEABLE_CARDIOVIEW
  cardIOView = self.hideableCardIOView;
#else
  self.adHocCardIOView = [[CardIOView alloc] initWithFrame:self.hideableCardIOView.frame];
  self.adHocCardIOView.delegate = self;
  cardIOView = self.adHocCardIOView;
#endif

  cardIOView.scanExpiry = self.expirySwitch.on;
  cardIOView.useCardIOLogo = self.useCardIOLogoSwitch.on;
  //  cardIOView.allowFreelyRotatingCardGuide = NO;
  cardIOView.scannedImageDuration = [self.scannedImageDurationField.text floatValue];

  cardIOView.languageOrLocale = self.language;

#if TEST_HIDEABLE_CARDIOVIEW
  self.hideableCardIOView.hidden = NO;
#else
  [self.view addSubview:self.adHocCardIOView];
#endif
}

- (void)updateLanguageDisplay {
  NSString *buttonText = nil;
  if ([self.language length]) {
    buttonText = self.language;
  }
  else {
    buttonText = @"device";
  }
  [self.languageButton setTitle:[NSString stringWithFormat:@"Language [%@]", buttonText] forState:UIControlStateNormal];
}

- (IBAction)languageChangeAction:(id)sender {
  NSArray *choices = @[@"ar", @"da", @"de", @"en", @"en_AU", @"en_GB", @"es", @"es_MX", @"fr", @"he", @"is", @"it", @"ja", @"ko", @"ms", @"nb", @"nl", @"pl", @"pt", @"pt_BR", @"ru", @"sv", @"th", @"tr", @"zh-Hans", @"zh-Hant", @"zh-Hant_TW"];

  iccChoicesSelectViewController *vc = [[iccChoicesSelectViewController alloc] initWithTitle:@"Language" choices:choices currentSelection:self.language completion:^(NSString *selection) {
    if (selection) {
      self.language = selection;
      [self updateLanguageDisplay];
    }
    [self dismissViewControllerAnimated:YES completion:nil];
  }];

  UINavigationController* nc = [[UINavigationController alloc] initWithRootViewController:vc];
  [self presentViewController:nc animated:YES completion:nil];
}

#pragma mark - I18n testing

#if CARDIO_DEBUG

- (IBAction)doI18n {
  self.i18nAutopilot = self.doABTestingSwitch.on;
  self.i18nLanguages = [CardIOLocalizer allLanguages];
  self.i18nLanguageIndex = 0;
  self.i18nPhase = 0;
  [self displayI18nCardIOPaymentViewController];
}

- (void)displayI18nCardIOPaymentViewController {
  NSString *language = self.i18nLanguages[self.i18nLanguageIndex];

  self.i18nCardIOPaymentViewController = [[CardIOPaymentViewController alloc] initWithPaymentDelegate:self scanningEnabled:(self.i18nPhase == 0)];
  self.i18nCardIOPaymentViewController.collectExpiry = YES;
  self.i18nCardIOPaymentViewController.collectCVV = YES;
  self.i18nCardIOPaymentViewController.collectPostalCode = YES;
  self.i18nCardIOPaymentViewController.disableManualEntryButtons = NO;
  self.i18nCardIOPaymentViewController.useCardIOLogo = NO;
  self.i18nCardIOPaymentViewController.languageOrLocale = language;

  UIView *coverView = [[UIView alloc] initWithFrame:self.i18nCardIOPaymentViewController.view.bounds];
  coverView.backgroundColor = [UIColor clearColor];
  coverView.userInteractionEnabled = YES;

  UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, coverView.frame.size.height / 5, coverView.frame.size.width, 44)];
  label.text = language;
  label.textAlignment = NSTextAlignmentCenter;
  label.textColor = [UIColor greenColor];
  label.font = [UIFont fontWithName:@"Helvetica" size:32];
  label.backgroundColor = [UIColor clearColor];
  [coverView addSubview:label];

  UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(displayNextI18nScreen)];
  [coverView addGestureRecognizer:tapRecognizer];

  UISwipeGestureRecognizer *tapLeftRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(displayNextI18nScreen)];
  tapLeftRecognizer.direction = UISwipeGestureRecognizerDirectionLeft;
  [coverView addGestureRecognizer:tapLeftRecognizer];

  UISwipeGestureRecognizer *tapRightRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(displayPreviousI18nScreen)];
  tapRightRecognizer.direction = UISwipeGestureRecognizerDirectionRight;
  [coverView addGestureRecognizer:tapRightRecognizer];

  [self presentViewController:self.i18nCardIOPaymentViewController animated:NO completion:nil];
  [self.i18nCardIOPaymentViewController.view addSubview:coverView];

  if (self.i18nAutopilot) {
    [self captureI18nScreenAndAdvance];
  }
}

- (void)dismissCurrentI18nScreen {
  if (self.i18nCardIOPaymentViewController) {
    [self.i18nCardIOPaymentViewController dismissViewControllerAnimated:NO completion:nil];
    self.i18nCardIOPaymentViewController = nil;
  }
  else if (self.i18nAlertView) {
    [self.i18nAlertView dismissWithClickedButtonIndex:0 animated:NO];
    self.i18nAlertView = nil;
  }
}

- (void)displayNextI18nScreen {
  [self dismissCurrentI18nScreen];

  self.i18nLanguageIndex++;

  if (self.i18nLanguageIndex < [self.i18nLanguages count]) {
    if (self.i18nPhase < 2) {
      [self displayI18nCardIOPaymentViewController];
    }
  }
  else {
    self.i18nLanguageIndex = 0;
    self.i18nPhase++;

    if (self.i18nPhase < 2) {
      [self displayI18nCardIOPaymentViewController];
    }
    else {
      if (self.i18nAlertViewBackground != nil) {
        [self.i18nAlertViewBackground removeFromSuperview];
        self.i18nAlertViewBackground = nil;
      }
    }
  }
}

- (void)displayPreviousI18nScreen {
  [self dismissCurrentI18nScreen];

  self.i18nLanguageIndex--;

  if (self.i18nLanguageIndex >= 0) {
    if (self.i18nPhase == 0 || self.i18nPhase == 1) {
      [self displayI18nCardIOPaymentViewController];
    }
  }
  else {
    self.i18nLanguageIndex = [self.i18nLanguages count] - 1;
    self.i18nPhase--;

    if (self.i18nPhase < 0) {
      // do nothing
    }
    else if (self.i18nPhase < 2) {
      if (self.i18nAlertViewBackground != nil) {
        [self.i18nAlertViewBackground removeFromSuperview];
        self.i18nAlertViewBackground = nil;
      }
      [self displayI18nCardIOPaymentViewController];
    }
  }
}

- (void)captureI18nScreenAndAdvance {
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
    UIWindow    *keyWindow = [UIApplication sharedApplication].keyWindow;
    UIGraphicsBeginImageContext(keyWindow.bounds.size);
    [keyWindow.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    NSData * data = UIImagePNGRepresentation(image);

    NSString *suffix;
    switch (self.i18nPhase) {
      case 0:
        suffix = @"camera";
        break;
      case 1:
        suffix = @"data";
        break;
      case 2:
        suffix = @"unauthorized";
        break;
    }
    NSString *applicationDocumentsDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    NSString *filename = [NSString stringWithFormat:@"%@.png", [NSString stringWithFormat:@"%@-%@",
                                                                self.i18nLanguages[self.i18nLanguageIndex], suffix]];
    NSString *storePath = [applicationDocumentsDir stringByAppendingPathComponent:filename];
    NSLog(@"*** Writing file: '%@' ***", storePath);
    [data writeToFile:storePath atomically:YES];

    if (self.i18nLanguageIndex + 1 < [self.i18nLanguages count] || self.i18nPhase < 2) {
      [self displayNextI18nScreen];
    }
    else {
      [self dismissCurrentI18nScreen];
      [self.i18nAlertViewBackground removeFromSuperview];
      self.i18nAlertViewBackground = nil;
    }
  });
}

#endif // CARDIO_DEBUG

#pragma mark - View lifecycle etc.

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];

  [self updateLanguageDisplay];

  NSUInteger systemMajorVersion = [[[[[UIDevice currentDevice] systemVersion] componentsSeparatedByString:@"."] objectAtIndex:0] intValue];
  if (systemMajorVersion >= 7) {
    // There are ways to do this in the .xib, but this is a non-disruptive hack for the short run
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      CGFloat delta = [UIApplication sharedApplication].statusBarFrame.size.height;
      for (UIView *subview in self.view.subviews) {
        if (subview != self.cardImageView) {
          subview.frame = CGRectByAddingYOffset(subview.frame, delta);
        }
      }
    });
  }
}

- (void)viewDidLoad {
  [super viewDidLoad];

  self.hideableCardIOView.delegate = self;

  self.originalOutcomeLabelWidth = self.outcomeLabel.frame.size.width;

#if TEST_GENERATED_MODELS
  [TestGeneratedModels selfCheck];
#endif

  [CardIOUtilities preload];
}

- (UIStatusBarStyle) preferredStatusBarStyle {
  return UIStatusBarStyleDefault;
}

- (BOOL)prefersStatusBarHidden {
  return [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"UIStatusBarHidden"] boolValue];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
  return YES;
}

- (BOOL)shouldAutorotate {
  return YES;
}

- (NSUInteger)supportedInterfaceOrientations {
  return UIInterfaceOrientationMaskAll;
}

- (void)didReceiveWillResignActiveNotification:(NSNotification *)notification {
  [self setOutcomeText:@"" image:nil];
}

- (void)setOutcomeText:(NSString *)text image:(UIImage *)image {
  self.outcomeLabel.text = text;

  CGRect frame = self.outcomeLabel.frame;
  frame.size.width = self.originalOutcomeLabelWidth;
  self.outcomeLabel.frame = frame;
  [self.outcomeLabel sizeToFit];

  self.cardImageView.image = image;
}

#pragma mark - CardIOPaymentViewControllerDelegate methods

- (void)userDidCancelPaymentViewController:(CardIOPaymentViewController *)paymentViewController {
  CardIOLog(@"Received userDidCancelPaymentViewController:");
  [self setOutcomeText:@"Cancelled" image:nil];
  [paymentViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)userDidProvideCreditCardInfo:(CardIOCreditCardInfo *)info inPaymentViewController:(CardIOPaymentViewController *)paymentViewController {
  CardIOLog(@"Received userDidProvideCreditCardInfo:inPaymentViewController:");
  NSMutableString *resultStr = [NSMutableString stringWithCapacity:100];

  [resultStr appendFormat:@"Number (%@): %@\n", info.scanned ? @"scanned" : @"manual", [info redactedCardNumber]];

  NSString *cardType = [CardIOCreditCardInfo displayStringForCardType:info.cardType usingLanguageOrLocale:nil];
  [resultStr appendFormat:@"%@\n", [cardType length] ? cardType : @"Unrecognized card type"];

  if(self.expirySwitch.on) {
    [resultStr appendFormat:@"Expiry: %02lu/%02lu\n", (unsigned long)info.expiryMonth, (unsigned long)info.expiryYear];
  }
  if(self.cvvSwitch.on) {
    [resultStr appendFormat:@"CVV: %@\n", info.cvv];
  }
  if(self.zipSwitch.on) {
    [resultStr appendFormat:@"Postal Code: %@\n", info.postalCode];
  }

#if CARDIO_DEBUG
  [self setOutcomeText:resultStr image:info.cardImage];
#else
  [self setOutcomeText:resultStr image:nil];
#endif

  [paymentViewController dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark CardIOViewDelegate method

- (void)cardIOView:(CardIOView *)cardIOView didScanCard:(CardIOCreditCardInfo *)cardInfo {
  CardIOLog(@"Received cardIOView:didScanCard:");
  if (cardInfo) {
    NSMutableString *resultStr = [NSMutableString stringWithCapacity:100];
    [resultStr appendFormat:@"Number (%@): %@\n", @"scanned", [cardInfo redactedCardNumber]];

    NSString *cardType = [CardIOCreditCardInfo displayStringForCardType:cardInfo.cardType usingLanguageOrLocale:nil];
    [resultStr appendFormat:@"%@\n", [cardType length] ? cardType : @"Unrecognized card type"];

    if(self.expirySwitch.on) {
      [resultStr appendFormat:@"Expiry: %02lu/%02lu\n", (unsigned long)cardInfo.expiryMonth, (unsigned long)cardInfo.expiryYear];
    }

#if CARDIO_DEBUG
    [self setOutcomeText:resultStr image:cardInfo.cardImage];
#else
    [self setOutcomeText:resultStr image:nil];
#endif
  }
  else {
    [self setOutcomeText:@"Cancelled" image:nil];
  }

#if TEST_HIDEABLE_CARDIOVIEW
  self.hideableCardIOView.hidden = YES;
#else
  [self.adHocCardIOView removeFromSuperview];
  self.adHocCardIOView = nil;
#endif
}

#pragma mark - Memory management

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  self.hideableCardIOView.delegate = nil;
}

@end
