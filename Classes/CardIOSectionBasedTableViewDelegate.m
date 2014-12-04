//
//  CardIOSectionBasedTableViewDelegate.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#import "CardIOSectionBasedTableViewDelegate.h"

@implementation CardIOSectionBasedTableViewDelegate

@synthesize sections;

- (NSUInteger)indexOfSection:(id<UITableViewDelegate, UITableViewDataSource>)section {
  return [self.sections indexOfObject:section];
}

#pragma mark - Non-delegated

- (NSInteger)numberOfSectionsInTableView:(UITableView *)aTableView {
  return [self.sections count];
}

#pragma mark - Required

- (UITableViewCell *)tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  id<UITableViewDataSource> section = self.sections[indexPath.section];
  return [section tableView:aTableView cellForRowAtIndexPath:indexPath];
}

- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)theSection {
  id<UITableViewDataSource> section = self.sections[theSection];
  return [section tableView:aTableView numberOfRowsInSection:theSection];
}

#pragma mark - Optional

- (void)tableView:(UITableView *)aTableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
  id<UITableViewDelegate> section = self.sections[indexPath.section];
  if([section respondsToSelector:@selector(tableView:willDisplayCell:forRowAtIndexPath:)]) {
    [section tableView:aTableView willDisplayCell:cell forRowAtIndexPath:indexPath];
  }
}

- (void)tableView:(UITableView *)aTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  id<UITableViewDelegate> section = self.sections[indexPath.section];
  if([section respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)]) {
    [section tableView:aTableView didSelectRowAtIndexPath:indexPath];
  }
}

- (NSString *)tableView:(UITableView *)aTableView titleForHeaderInSection:(NSInteger)theSection {
  id<UITableViewDataSource> section = self.sections[theSection];
  if([section respondsToSelector:@selector(tableView:titleForHeaderInSection:)]) {
    return [section tableView:aTableView titleForHeaderInSection:theSection];
  } else {
    return nil;
  }
}

- (UIView *)tableView:(UITableView *)aTableView viewForHeaderInSection:(NSInteger)theSection {
  id<UITableViewDelegate> section = self.sections[theSection];
  if([section respondsToSelector:@selector(tableView:viewForHeaderInSection:)]) {
    return [section tableView:aTableView viewForHeaderInSection:theSection];
  } else {
    return nil;
  }
}

- (UIView *)tableView:(UITableView *)aTableView viewForFooterInSection:(NSInteger)theSection {
  id<UITableViewDelegate> section = self.sections[theSection];
  if([section respondsToSelector:@selector(tableView:viewForFooterInSection:)]) {
    return [section tableView:aTableView viewForFooterInSection:theSection];
  } else {
    return nil;
  }
}

- (NSString *)tableView:(UITableView *)aTableView titleForFooterInSection:(NSInteger)theSection {
  id<UITableViewDataSource> section = self.sections[theSection];
  if([section respondsToSelector:@selector(tableView:titleForFooterInSection:)]) {
    return [section tableView:aTableView titleForFooterInSection:theSection];
  } else {
    return nil;
  }
}

- (NSIndexPath *)tableView:(UITableView *)aTableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  id<UITableViewDelegate> section = self.sections[indexPath.section];
  if([section respondsToSelector:@selector(tableView:willSelectRowAtIndexPath:)]) {
    return [section tableView:aTableView willSelectRowAtIndexPath:indexPath];
  } else {
    return indexPath;
  }
}

- (CGFloat)tableView:(UITableView *)aTableView heightForHeaderInSection:(NSInteger)theSection {
  id<UITableViewDelegate> section = self.sections[theSection];
  if([section respondsToSelector:@selector(tableView:heightForHeaderInSection:)]) {
    return [section tableView:aTableView heightForHeaderInSection:theSection];
  } else {
    return aTableView.sectionHeaderHeight;
  }
}

- (CGFloat)tableView:(UITableView *)aTableView heightForFooterInSection:(NSInteger)theSection {
  id<UITableViewDelegate> section = self.sections[theSection];
  if([section respondsToSelector:@selector(tableView:heightForFooterInSection:)]) {
    return [section tableView:aTableView heightForFooterInSection:theSection];
  } else {
    return aTableView.sectionFooterHeight;
  }
}

- (CGFloat)tableView:(UITableView *)aTableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
  id<UITableViewDelegate> section = self.sections[indexPath.section];
  if([section respondsToSelector:@selector(tableView:heightForRowAtIndexPath:)]) {
    return [section tableView:aTableView heightForRowAtIndexPath:indexPath];
  } else {
    return aTableView.rowHeight;
  }
}

@end
