//
//  CardIOMultipleFieldTableViewCell.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#import "CardIOMultipleFieldTableViewCell.h"
#import "CardIOTableViewCell.h"
#import "CardIOStyles.h"
#import "CardIOMacros.h"

// uncomment to debug layout issues
//#define DEBUG_LAYOUT_WITH_COLORS

#define CELLPADDING 7
#define kDefaultLabelWidth 50
#define kLineSeparatorWidthPreIOS7 1.0f
#define kLineSeparatorWidthIOS7 0.5f
#define kLineSeparatorGrayColor 0.75f

@interface CardIOMultipleFieldContentView : UIView

@property(nonatomic, assign, readwrite) NSUInteger numberOfFields; // should be a reasonable number ... 1-3 range.
@property(nonatomic, assign, readwrite) Class textFieldClass;
@property(nonatomic, strong, readonly) NSMutableArray *textFields;
@property(nonatomic, strong, readonly) NSMutableArray *labels;
@property(nonatomic, strong, readonly) NSMutableArray *labelLabels;
@property(nonatomic, assign, readonly) UITableViewCellStyle cellStyle;
@property(nonatomic, assign, readwrite) CGFloat labelWidth;
@property(nonatomic, assign, readwrite) BOOL hiddenLabel;
@property(nonatomic, assign, readwrite) NSTextAlignment textAlignment;

@end

@implementation CardIOMultipleFieldContentView

#pragma mark - Properties

- (void)setNumberOfFields:(NSUInteger)nof {
  if(nof == _numberOfFields) {
    return;
  }
  _numberOfFields = nof;
  
  [self setNeedsDisplay];
  
  while([self.textFields count] > _numberOfFields) {
    [self.textFields removeLastObject];
    [self.labelLabels removeLastObject];
  }
  
  // number of fields has changed, so we need to re-layout
  for(UIView *v in [self subviews]) {
    [v removeFromSuperview];
  }
  
  while([self.textFields count] < _numberOfFields) {
    // field will be positioned by layoutSubviews
    UITextField *field = [[self.textFieldClass alloc] initWithFrame:CGRectZero];
    field.textAlignment = self.textAlignment;
    field.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    CGFloat fontSize = [CardIOTableViewCell defaultDetailTextLabelFontSizeForCellStyle:self.cellStyle];
    field.font = [CardIOTableViewCell defaultDetailTextLabelFontForCellStyle:self.cellStyle fontSize:fontSize];
    field.textColor = [CardIOTableViewCell defaultDetailTextLabelColorForCellStyle:self.cellStyle];
    field.backgroundColor = kColorDefaultCell;
    [self.textFields addObject:field];

    UILabel *label = [[UILabel alloc]initWithFrame:CGRectZero];
    label.textAlignment = self.textAlignment;
    fontSize = [CardIOTableViewCell defaultTextLabelFontSizeForCellStyle:self.cellStyle];
    label.font = [CardIOTableViewCell defaultTextLabelFontForCellStyle:self.cellStyle fontSize:fontSize];
    label.textColor = [CardIOTableViewCell defaultTextLabelColorForCellStyle:self.cellStyle];
    label.backgroundColor = kColorDefaultCell;
    [self.labelLabels addObject:label];
  }
}

- (void)setTextAlignment:(NSTextAlignment)textAlignment {
  if (textAlignment != self.textAlignment) {
    _textAlignment = textAlignment;
    for (UITextField *field in self.textFields) {
      field.textAlignment = textAlignment;
    }
    for (UILabel *label in self.labelLabels) {
      label.textAlignment = textAlignment;
    }
    
    [self setNeedsLayout];
  }
}

#pragma mark -

- (id)init {
  if((self = [super init])) {
    self.opaque = NO;
    self.autoresizesSubviews = NO;
    
    _cellStyle = UITableViewCellStyleValue2;
    _textFields = [[NSMutableArray alloc] initWithCapacity:3];
    _labels = [[NSMutableArray alloc] initWithCapacity:3];
    _labelLabels = [[NSMutableArray alloc] initWithCapacity:3];
    _labelWidth = kDefaultLabelWidth;
  }
  return self;
}

- (void)drawRect:(CGRect)rect {
  
  CGContextRef cgContext = UIGraphicsGetCurrentContext();
  
  CGFloat cellWidth = self.bounds.size.width / _numberOfFields;
  CGFloat xAdjust;
  
  if (iOS_7_PLUS) {
    xAdjust = 0;
    CGContextSetLineWidth(cgContext, kLineSeparatorWidthIOS7);
  }
  else {
    xAdjust = 0.5f;
    CGContextSetLineWidth(cgContext, kLineSeparatorWidthPreIOS7);
  }
  
  CGFloat y_min = 0;
  CGFloat y_max = self.bounds.size.height;
  
  for(int i = 1; i < _numberOfFields; i++) {
    CGFloat x = (CGFloat)floor(cellWidth * i) - xAdjust;
    
    CGContextSetGrayStrokeColor(cgContext, kLineSeparatorGrayColor, 1.0);
    
    CGContextMoveToPoint(cgContext, x, y_min);
    CGContextAddLineToPoint(cgContext, x, y_max);
    CGContextDrawPath(cgContext, kCGPathStroke);
    
    CGContextSetRGBStrokeColor(cgContext, 1.0, 1.0, 1.0, 1.0);
    CGContextMoveToPoint(cgContext, x + 1.0f, y_min);
    CGContextAddLineToPoint(cgContext, x + 1.0f, y_max);
    CGContextDrawPath(cgContext, kCGPathStroke);
  }
}

- (void)layoutSubviews {
  
  // Each field within the cell = <CELLPADDING><Label><CELLPADDING><Field><CELLPADDING>
  // (Reverse that for right-to-left languages.)
  
#ifdef DEBUG_LAYOUT_WITH_COLORS
  CardIOLog(@"contentView(%@) layoutSubviews",self);
  self.backgroundColor = [UIColor redColor];
#endif
  
  for(NSInteger position = 0; position < [self.textFields count]; position++) {
    NSInteger index;
    if (self.textAlignment == NSTextAlignmentRight) {
      index = ([self.textFields count] - 1) - position;
    }
    else {
      index = position;
    }
    
    CGSize rowsize = self.bounds.size;
    CGFloat cellwidth = rowsize.width/_numberOfFields;

    UILabel *label = self.labelLabels[index];

    if(index < [_labels count] && !self.hiddenLabel) {
      label.text = _labels[index];
    } else {
      label.text = @"";
    }
    
    [label sizeToFit];
    CGRect labelRect = label.frame;

    if (!self.hiddenLabel) {
      labelRect.size.width = (CGFloat)fmax(self.labelWidth, labelRect.size.width);
    } else {
      labelRect.size = CGSizeZero;
    }
    
    if (self.textAlignment == NSTextAlignmentRight) {
      labelRect.origin = CGPointMake((CGFloat)floor((position + 1) * cellwidth) - CELLPADDING - labelRect.size.width, 0);
    }
    else {
      labelRect.origin = CGPointMake((CGFloat)floor(position * cellwidth) + CELLPADDING, 0);
    }

    label.frame = labelRect;

    CGPoint labelCtr = label.center;
    labelCtr.y = self.bounds.size.height/2;
    label.center = labelCtr;
    
    if(![label superview]) {
      [self addSubview:label];
    }

    UITextField *field = self.textFields[index];
    
    CGFloat fieldWidth = (CGFloat)floor(cellwidth) - 3 * CELLPADDING - label.bounds.size.width;
    CGFloat fieldHeight = rowsize.height - 2 * CELLPADDING;
    
    CGFloat x;
    if (self.textAlignment == NSTextAlignmentRight) {
      x = (CGFloat)floor(position * cellwidth) + CELLPADDING;
    }
    else {
      x = (CGFloat)floor(position * cellwidth) + 2 * CELLPADDING + label.bounds.size.width;
    }

    CGRect fieldFrame = CGRectMake(x, CELLPADDING, fieldWidth, fieldHeight);
    
    field.frame = fieldFrame;
    
    if(![field superview]) {
      [self addSubview:field];
    }
    
#ifdef DEBUG_LAYOUT_WITH_COLORS
    label.backgroundColor = [UIColor blueColor];
    field.backgroundColor = [UIColor greenColor];
#endif
  }
  
  [self setNeedsDisplay]; // otherwise our vertical dividers won't redraw
}

- (BOOL)textFitsInMultiFieldForLabel:(NSString *)labelText
                      forPlaceholder:(NSString *)placeholderText
                       forFieldWidth:(CGFloat)fieldWidth {

  // Each field within the cell = <CELLPADDING><Label><CELLPADDING><Field><CELLPADDING>
  // (Reverse that for right-to-left languages.)

  CGFloat labelFontSize = [CardIOTableViewCell defaultTextLabelFontSizeForCellStyle:self.cellStyle];
  UIFont *labelFont = [CardIOTableViewCell defaultTextLabelFontForCellStyle:self.cellStyle fontSize:labelFontSize];
  CGFloat measuredLabelWidth = [labelText sizeWithFont:labelFont].width;

  CGFloat placeholderFontSize = [CardIOTableViewCell defaultDetailTextLabelFontSizeForCellStyle:self.cellStyle];
  UIFont *placeholderFont = [CardIOTableViewCell defaultDetailTextLabelFontForCellStyle:self.cellStyle fontSize:placeholderFontSize];
  CGFloat measuredPlaceholderWidth = [placeholderText sizeWithFont:placeholderFont].width;

  return (measuredLabelWidth + measuredPlaceholderWidth + 3 * CELLPADDING < fieldWidth);
}

@end

#pragma mark -

@implementation CardIOMultipleFieldTableViewCell

@synthesize textFieldClass;

#pragma mark - Properties

-(void)setNumberOfFields:(NSUInteger)numberOfFields {
  content.numberOfFields = numberOfFields;
}

- (NSUInteger)numberOfFields {
  return content.numberOfFields;
}

- (NSArray *)textFields {
  return content.textFields;
}

- (NSArray *)labels {
  return content.labels;
}

- (CGFloat)labelWidth {
  return content.labelWidth;
}

- (void)setLabelWidth:(CGFloat)labelWidth {
  content.labelWidth = labelWidth;
}


- (void)setHiddenLabels:(BOOL)hideLabels {
  content.hiddenLabel = hideLabels;
}

- (void)setTextAlignment:(NSTextAlignment)textAlignment {
  content.textAlignment = textAlignment;
}


#pragma mark -

- (BOOL)textFitsInMultiFieldForLabel:(NSString *)labelText
                      forPlaceholder:(NSString *)placeholderText
                       forFieldWidth:(CGFloat)fieldWidth {
  return [content textFitsInMultiFieldForLabel:labelText
                                forPlaceholder:placeholderText
                                 forFieldWidth:(CGFloat)fieldWidth];
}

#pragma mark - UITableView delegate/dataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return 0;
}

- (UITableViewCell *)tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  return self;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
  self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
  if(self) {
    textFieldClass = [UITextField class];
    content = [[CardIOMultipleFieldContentView alloc] init];
    content.textFieldClass = textFieldClass;
    self.selectionStyle = UITableViewCellSelectionStyleNone;
  }
  return self;
}

#pragma mark -

- (void)layoutSubviews {
  [super layoutSubviews];
  
  if(!content.superview) {
    self.autoresizesSubviews = NO;
    [self.contentView addSubview:content];
    [content setNeedsLayout];
  }
  
  if (!CGRectEqualToRect(content.frame, self.contentView.bounds)) {
    content.frame = self.contentView.bounds;
    [content setNeedsLayout];
  }
}

- (void)setTextFieldClass:(Class)newTextFieldClass {
  textFieldClass = newTextFieldClass;
  content.textFieldClass = newTextFieldClass;
  content.numberOfFields = self.numberOfFields;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
  [super setSelected:selected animated:animated];
}

@end
