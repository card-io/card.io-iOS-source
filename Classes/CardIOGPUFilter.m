//
//  CardIOGPUFilter.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#import "CardIOGPUFilter.h"

@implementation CardIOGPUFilter

#pragma mark Utility classmethods

- (id)initWithSize:(CGSize)size vertexShaderSrc:(NSString *)vertexShaderSrc fragmentShaderSrc:(NSString *)fragmentShaderSrc;
{
  if((self = [super init])) {
    // Create GPUImageView, which actually handles the processing
    _gpuRenderer = [[CardIOGPURenderer alloc] initWithSize:size
                                       vertexShaderSrc:vertexShaderSrc
                                     fragmentShaderSrc:fragmentShaderSrc];
    if (!_gpuRenderer) {
      self = nil;
    }
  }
  return self;
}

- (CGSize)size {
  return _gpuRenderer.size;
}

- (void)finish {
  [_gpuRenderer finish];
}

// Process images

- (UIImage *)processUIImage:(UIImage *)srcUIImage toSize:(const CGSize)size {
  [_gpuRenderer renderUIImage:srcUIImage toSize:size];
  return [_gpuRenderer captureUIImageOfSize:size];
}

#if USE_CAMERA

- (UIImage *)processIplToUIImage:(IplImage *)srcImg toSize:(const CGSize)size {
  [_gpuRenderer renderIplImage:srcImg toSize:(CGSize)size];
  return [_gpuRenderer captureUIImageOfSize:size];
}

- (void)processIplImage:(IplImage *)srcImg dstIplImg:(IplImage *)dstImg {
  [_gpuRenderer renderIplImage:srcImg toSize:CGSizeMake(dstImg->width, dstImg->height)];
  [_gpuRenderer captureIplImage:dstImg];
}

#endif // USE_CAMERA

#pragma mark Matrices

+ (void)loadIdentityMatrix:(GLfloat *)matrix size:(GLuint)size {
  for (int i = 0; i < size * size; i++) {
    matrix[i] = (i % (size + 1) == 0) ? 1 : 0;
  }
}

// Brad Larson's BSD-licensed work on this is interesting. Check it out.
+ (void)loadOrthoMatrix:(GLfloat *)matrix left:(GLfloat)left right:(GLfloat)right bottom:(GLfloat)bottom top:(GLfloat)top near:(GLfloat)near far:(GLfloat)far {
  GLfloat r_l = right - left;
  GLfloat t_b = top - bottom;
  GLfloat f_n = far - near;
  GLfloat tx = - (right + left) / (right - left);
  GLfloat ty = - (top + bottom) / (top - bottom);
  GLfloat tz = - (far + near) / (far - near);
  
  matrix[0] = 2.0f / r_l;
  matrix[1] = 0.0f;
  matrix[2] = 0.0f;
  matrix[3] = tx;
  
  matrix[4] = 0.0f;
  matrix[5] = 2.0f / t_b;
  matrix[6] = 0.0f;
  matrix[7] = ty;
  
  matrix[8] = 0.0f;
  matrix[9] = 0.0f;
  matrix[10] = 2.0f / f_n;
  matrix[11] = tz;
  
  matrix[12] = 0.0f;
  matrix[13] = 0.0f;
  matrix[14] = 0.0f;
  matrix[15] = 1.0f;
}

+ (NSString *)matrixAsString:(GLfloat *)matrix size:(GLuint)size rowMajor:(BOOL)rowMajor {
  NSString *ret = [NSString string];
  for (int i = 0; i < size; i++) {
    for (int j = 0; j < size; j++) {
      int index = rowMajor ? (i * size + j) : j * size + i;
      ret = [ret stringByAppendingString:[NSString stringWithFormat:@"%.2f ", matrix[index]]];
    }
    ret = [ret stringByAppendingString:@"\n"];
  }
  return ret;
}

@end
