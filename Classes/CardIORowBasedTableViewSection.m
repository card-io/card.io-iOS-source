//
//  CardIORowBasedTableViewSection.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#import "CardIORowBasedTableViewSection.h"

#define kCellHeightAdjustment 1

@implementation CardIORowBasedTableViewSection

@synthesize rows;
@synthesize headerTitle;
@synthesize headerView;
@synthesize footerTitle;
@synthesize footerView;

- (NSUInteger)indexOfRow:(id<UITableViewDelegate, UITableViewDataSource>)row {
  return [self.rows indexOfObject:row];
}

#pragma mark - Non-delegated

- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)theSection {
  return [self.rows count];
}

- (NSString *)tableView:(UITableView *)aTableView titleForHeaderInSection:(NSInteger)theSection {
  return self.headerTitle;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
  return self.headerView;  
}

- (CGFloat)tableView:(UITableView *)aTableView heightForHeaderInSection:(NSInteger)section {
  return self.headerView ? self.headerView.bounds.size.height : aTableView.sectionHeaderHeight;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
  return self.footerTitle;
}

- (UIView *)tableView:(UITableView *)aTableView viewForFooterInSection:(NSInteger)theSection {
  return self.footerView;
}

- (CGFloat)tableView:(UITableView *)aTableView heightForFooterInSection:(NSInteger)theSection {
  return self.footerView ? self.footerView.bounds.size.height : aTableView.sectionFooterHeight;
}

// Gross hack alert:
// Apple's table layout code actually adjusts table cell frame height,
// presumably to draw separator lines.
// The result is that UITableViewCells in our rows array are increased
// in size on every table redraw.
// We adjust for this by returning the contentView bounds + an adjustment.
// (brfitzgerald 9/12/2012)
- (CGFloat)tableView:(UITableView *)aTableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
  id row = self.rows[indexPath.row];
  if([row respondsToSelector:@selector(tableView:heightForRowAtIndexPath:)]) {
    id<UITableViewDelegate> dataSourceRow = row;
    return [dataSourceRow tableView:aTableView heightForRowAtIndexPath:indexPath];
  } else if([row isKindOfClass:[UITableViewCell class]]) {
    UITableViewCell *cell = (UITableViewCell *)row;
    if(cell.bounds.size.height > 0) {
      return cell.contentView.bounds.size.height + kCellHeightAdjustment;
    } else {
      return aTableView.rowHeight;
    }
  } else {
    return aTableView.rowHeight;
  }
}

#pragma mark - Required

- (UITableViewCell *)tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  id row = self.rows[indexPath.row];
  if([row conformsToProtocol:@protocol(UITableViewDataSource)]) {
    id<UITableViewDataSource> dataSourceRow = row;
    return [dataSourceRow tableView:aTableView cellForRowAtIndexPath:indexPath];
  } else if([row isKindOfClass:[UITableViewCell class]]) {
    return row;
  } else {
    return nil;
  }
}

#pragma mark - Optional

- (void)tableView:(UITableView *)aTableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
  id<UITableViewDelegate> row = self.rows[indexPath.row];
  if([row respondsToSelector:@selector(tableView:willDisplayCell:forRowAtIndexPath:)]) {
    [row tableView:aTableView willDisplayCell:cell forRowAtIndexPath:indexPath];
  }
}

- (void)tableView:(UITableView *)aTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  id<UITableViewDelegate> row = self.rows[indexPath.row];
  if([row respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)]) {
    [row tableView:aTableView didSelectRowAtIndexPath:indexPath];
  } else if([row isKindOfClass:[UITableViewCell class]]) {
    [aTableView deselectRowAtIndexPath:indexPath animated:NO];
  }
}

- (NSIndexPath *)tableView:(UITableView *)aTableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  id<UITableViewDelegate> row = self.rows[indexPath.row];
  if([row respondsToSelector:@selector(tableView:willSelectRowAtIndexPath:)]) {
    return [row tableView:aTableView willSelectRowAtIndexPath:indexPath];
  } else {
    return indexPath;
  }
}


@end
