//
//  DemoGPUController.h
//  icc
//
//  Created by Brent Fitzgerald on 6/6/12.
//  Copyright (c) 2012 Lumber Labs Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "dmz.h"
#import "CardIOGPUTransformFilter.h"

@interface DemoGPUController : UIViewController {
@private
  UIImageView *srcImgView;
  UIImageView *dstImgView;
  IBOutlet UISwitch *modeSwitch;
  
  CardIOGPUTransformFilter *_transformFilter;
  
  NSMutableArray *btnHandles;
  void *dmz;
}

@property (nonatomic, retain) UIImageView *srcImgView;
@property (nonatomic, retain) UIImageView *dstImgView;
@property (nonatomic, retain) UISwitch *modeSwitch;
@property (nonatomic, retain) NSMutableArray* btnHandles;

@end
