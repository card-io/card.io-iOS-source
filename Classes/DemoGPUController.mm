//
//  DemoGPUController.m
//  icc
//
//  Created by Brent Fitzgerald on 6/6/12.
//  Copyright (c) 2012 Lumber Labs Inc. All rights reserved.
//

#import "DemoGPUController.h"
#import "dmz.h"
#import "CardIOCGGeometry.h"
#import "CardIOIplImage.h"
#import "CardIOGPUFilter.h"
#import "eigen.h"
#import "warp.h"

static const dmz_rect kNormalDMZRect = dmz_create_rect(-1, -1, 2, 2);


@interface DemoGPUController ()

- (void) updateDewarpedImage;

@end

@implementation DemoGPUController

@synthesize btnHandles;
@synthesize srcImgView;
@synthesize dstImgView;
@synthesize modeSwitch;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  if (self) {
    self.btnHandles = [NSMutableArray arrayWithCapacity:4];
    dmz = dmz_init();

  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  UIImage *srcImg = [UIImage imageNamed:@"cardio_logo_220.png"];
  srcImgView = [[UIImageView alloc] initWithImage:srcImg];
  srcImgView.frame = CGRectByAddingXAndYOffset(srcImgView.frame, (self.view.frame.size.width - srcImgView.frame.size.width) / 2, 30);
  [self.view addSubview:srcImgView];
  
  dstImgView = [[UIImageView alloc] initWithImage:srcImg];
  dstImgView.frame = CGRectByAddingYOffset(srcImgView.frame, srcImgView.frame.size.height + 30);
  [self.view addSubview:dstImgView];
  
  _transformFilter = [[CardIOGPUTransformFilter alloc] initWithSize:dstImgView.frame.size];
  
  CGPoint points[] = {
    srcImgView.frame.origin,
    CGPointByAddingXOffset(srcImgView.frame.origin, srcImgView.frame.size.width),
    CGPointByAddingYOffset(srcImgView.frame.origin, srcImgView.frame.size.height),
    CGPointMake(srcImgView.frame.origin.x + srcImgView.frame.size.width, srcImgView.frame.origin.y + srcImgView.frame.size.height)
  };
  
  for (int i = 0; i < 4; i++) {
    UIButton *btnHandle = [UIButton buttonWithType:UIButtonTypeInfoDark];
    btnHandle.center = points[i];
    [btnHandle addTarget:self action:@selector(handleTouch:withEvent:) forControlEvents:UIControlEventTouchDown];
    [btnHandle addTarget:self action:@selector(handleMove:withEvent:) forControlEvents:UIControlEventTouchDragInside];
    [self.view addSubview:btnHandle];
    [btnHandles addObject:btnHandle];
  }
}

- (void) updateDewarpedImage {
//
  
  IplImage *srcImg = [CardIOIplImage imageWithUIImage:srcImgView.image].image;
  IplImage *dstImg;
  
  CGPoint tl = ((UIControl *)[self.btnHandles objectAtIndex:0]).center,
  tr = ((UIControl *)[self.btnHandles objectAtIndex:1]).center,
  bl = ((UIControl *)[self.btnHandles objectAtIndex:2]).center,
  br = ((UIControl *)[self.btnHandles objectAtIndex:3]).center;
  

  UIImage *resultImg;
  if (modeSwitch.on) {
    
    // handle positions normalized to -1 to 1 coordinates
    dmz_point sourcePoints[] = {
      dmz_create_point(bl.x - srcImgView.frame.origin.x, bl.y - srcImgView.frame.origin.y),
      dmz_create_point(tl.x - srcImgView.frame.origin.x, tl.y - srcImgView.frame.origin.y),
      dmz_create_point(br.x - srcImgView.frame.origin.x, br.y - srcImgView.frame.origin.y),
      dmz_create_point(tr.x - srcImgView.frame.origin.x, tr.y - srcImgView.frame.origin.y),
    };
    
    // OpenGL has reversed vertical coordinate system, with positive y-axis going down.
    // So we setup a reverse vertical mapping to our image.
    dmz_point destPoints[] = {
      dmz_create_point(-1, 1),  // maps to left BOTTOM (i.e. -1, -1)
      dmz_create_point(-1, -1), //         left TOP (i.e. -1, 1)
      dmz_create_point(1, 1),   //         right BOTTOM (i.e. 1, -1)
      dmz_create_point(1, -1),  //         right TOP (i.e. 1, 1)
    };
    

    for(int i = 0; i < 4; i++) {
      printf("sourcePoints[%d]: (%f, %f)\n", i, sourcePoints[i].x, sourcePoints[i].y);
      printf("destPoints[%d]: (%f, %f)\n", i, destPoints[i].x, destPoints[i].y);
    }

    float m[16];
    llcv_calc_persp_transform(m, 16, false, sourcePoints, destPoints);
    
    [_transformFilter setPerspectiveMat:m];
//    resultImg = [_transformFilter processIplToUIImage:srcImg];
    IplImage *result = cvCloneImage(srcImg);
    [_transformFilter processIplImage:srcImg dstIplImg:result];
    resultImg = [CardIOIplImage imageWithIplImage:result].UIImage;

  } else {

      dmz_corner_points corner_points; // TODO - make property, create in init

      corner_points.top_left.x = tl.x - srcImgView.frame.origin.x;
      corner_points.top_left.y = tl.y - srcImgView.frame.origin.y;
      corner_points.top_right.x = tr.x - srcImgView.frame.origin.x;
      corner_points.top_right.y = tr.y - srcImgView.frame.origin.y;
      corner_points.bottom_left.x = bl.x - srcImgView.frame.origin.x;
      corner_points.bottom_left.y = bl.y - srcImgView.frame.origin.y;
      corner_points.bottom_right.x = br.x - srcImgView.frame.origin.x;
      corner_points.bottom_right.y = br.y - srcImgView.frame.origin.y;

      dmz_transform_card(NULL, srcImg, corner_points, FrameOrientationPortrait, &dstImg);
      resultImg = [CardIOIplImage imageWithIplImage:dstImg].UIImage;
  }
  dstImgView.image = resultImg;
  dstImgView.contentMode = UIViewContentModeScaleAspectFit;
  
}


- (IBAction) handleTouch:(id) sender withEvent:(UIEvent *) event 
{
  NSLog(@"handleTouch");
}

- (IBAction) handleMove:(id) sender withEvent:(UIEvent *) event
{
  NSLog(@"handleMove");
  CGPoint point = [[[event allTouches] anyObject] locationInView:self.view];
  UIControl *control = sender;
  control.center = point;
  [self updateDewarpedImage];
}

- (void)viewDidUnload
{
  [super viewDidUnload];
  [modeSwitch release], modeSwitch = nil;
  [srcImgView release], srcImgView = nil;
  [dstImgView release], dstImgView = nil;
  [btnHandles release], btnHandles = nil;
  [_transformFilter release], _transformFilter = nil;

  // Release any retained subviews of the main view.
  // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
  return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)dealloc 
{
  [modeSwitch release], modeSwitch = nil;
  [srcImgView release], srcImgView = nil;
  [dstImgView release], dstImgView = nil;
  [btnHandles release], btnHandles = nil;
  [_transformFilter release], _transformFilter = nil;

  dmz_destroy(dmz);
  [super dealloc];
}

@end
