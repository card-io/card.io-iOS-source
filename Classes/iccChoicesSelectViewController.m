//
//  iccChoicesSelectViewController.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#import "iccChoicesSelectViewController.h"

@interface iccChoicesSelectViewController ()
@property (nonatomic, strong, readwrite) NSArray *choices;
@property (nonatomic, strong, readwrite) NSString *currentSelection;
@property (nonatomic, copy, readwrite) PPChoiceSelected completion;
@end

@implementation iccChoicesSelectViewController

- (instancetype)initWithTitle:(NSString *)title choices:(NSArray *)choices currentSelection:(NSString *)currentSelection completion:(PPChoiceSelected)completed {
  if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
    self.title = title;
    _choices = choices;
    _currentSelection = currentSelection;
    _completion = completed;
  }
  return self;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelAction:)];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return [self.choices count] + 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  static NSString *CellIdentifier = @"Cell";
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
  
  if (!cell) {
    cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
  }
  
  NSString *choice = nil;
  BOOL isSame = NO;
  if (indexPath.row == 0) {
    choice = @"device settings";
    if (![self.currentSelection length]) {
      isSame = YES;
    }
  }
  else {
    choice = self.choices[indexPath.row - 1];
    isSame = [choice isEqualToString:self.currentSelection];
  }
  cell.textLabel.text = choice;
  cell.accessoryType = isSame ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
  
  return cell;
}


#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  for (UITableViewCell* onScreenCell in [self.tableView visibleCells]) {
    onScreenCell.accessoryType = UITableViewCellAccessoryNone;
  }
  
  UITableViewCell* cell = [self.tableView cellForRowAtIndexPath:indexPath];
  cell.accessoryType = UITableViewCellAccessoryCheckmark;
  
  [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
  
  if (indexPath.row == 0) {
    self.currentSelection = @"";
  }
  else {
    self.currentSelection = self.choices[indexPath.row - 1];
  }
  
  float delayInSeconds = 0.3f;
  dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
  dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
    _completion(_currentSelection);
  });
  
}

#pragma mark -

- (void)cancelAction:(id) sender {
  _completion(nil);
}

@end
