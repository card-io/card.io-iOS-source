//
//  iccAppDelegate.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#import "iccAppDelegate.h"
#import "RootViewController.h"
#import "CardIOMacros.h"
#import "CardIOPaymentViewController.h"
#import "CardIOUtilities.h"

@implementation iccAppDelegate

@synthesize window;

#pragma mark -
#pragma mark Application lifecycle

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  window.backgroundColor = [UIColor whiteColor];  // otherwise, on iPad apparently defaults to {red:1 green:0.0471187 blue:0}
  window.rootViewController = [[RootViewController alloc] initWithNibName:nil bundle:nil];
  [window addSubview:window.rootViewController.view];
  [window makeKeyAndVisible];
  CardIOLog(@"Client version is %@.", [CardIOUtilities libraryVersion]);
	return YES;
}



@end
