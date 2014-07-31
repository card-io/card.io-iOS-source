//
//  CardIOGPUGaussianBlurFilter.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#import "CardIOGPUGaussianBlurFilter.h"
#import "CardIOGPUShaders.h"

NSString *const kCardIOGPUImageGaussianBlurVertexShaderString = SHADER_STRING
(
 // Coded for simplicity of comprehension and reasonable speed; NOT super-hyper-optimized for speed.
 // For fancier, faster approaches, see, e.g., http://stackoverflow.com/questions/4804732/gaussian-filter-with-opengl-shaders
 
 attribute vec4 position;
 attribute vec2 texCoordIn;
 uniform   mat4 orthographicMatrix;
 
 // This is a one-dimensional blur. Apply sequentially (if so desired) for horizontal and for vertical (or vice-versa).
 uniform int horizontalPass;
 
 const lowp int KERNEL_SIZE = 9;
 const lowp int KERNEL_SIZE_HALF = (KERNEL_SIZE - 1) / 2;
 
 varying highp vec2 blurCoordinates[KERNEL_SIZE];
 
 void main() {
   gl_Position = vec4(position * orthographicMatrix);
   
   int texelWidthOffset;
   int texelHeightOffset;
   
   if (horizontalPass == 1) {
     texelWidthOffset = 1;
     texelHeightOffset = 0;
   }
   else {
     texelWidthOffset = 0;
     texelHeightOffset = 1;
   }
   
   for (lowp int i = 0; i < KERNEL_SIZE; i++) {
     blurCoordinates[i] = texCoordIn + vec2((i - KERNEL_SIZE_HALF) * texelWidthOffset, (i - KERNEL_SIZE_HALF) * texelHeightOffset);
   }
 }
);

NSString *const kCardIOGPUImageGaussianBlurFragmentShaderString = SHADER_STRING
(
 uniform sampler2D texture;
 
 const lowp int KERNEL_SIZE = 9;
 
 varying highp vec2 blurCoordinates[KERNEL_SIZE];
 
 void main() {
   lowp vec4 sum = vec4(0.0);
   
   sum += texture2D(texture, blurCoordinates[0]) * 0.05;
   sum += texture2D(texture, blurCoordinates[1]) * 0.09;
   sum += texture2D(texture, blurCoordinates[2]) * 0.12;
   sum += texture2D(texture, blurCoordinates[3]) * 0.15;
   sum += texture2D(texture, blurCoordinates[4]) * 0.18;
   sum += texture2D(texture, blurCoordinates[5]) * 0.15;
   sum += texture2D(texture, blurCoordinates[6]) * 0.12;
   sum += texture2D(texture, blurCoordinates[7]) * 0.09;
   sum += texture2D(texture, blurCoordinates[8]) * 0.05;
   
   gl_FragColor = sum;
 }
);

@implementation CardIOGPUGaussianBlurFilter

- (id)initWithSize:(CGSize)size
{
  if((self = [super initWithSize:size vertexShaderSrc:kCardIOGPUImageGaussianBlurVertexShaderString fragmentShaderSrc:kCardIOGPUImageGaussianBlurFragmentShaderString])) {
    [_gpuRenderer withContextDo:^{
      GLfloat orthographicMatrix[16];
      // Set up the ortho matrix
      // Could hard-code this into the shader. But it's easier to understand in this form, I think.
      [[self class] loadOrthoMatrix:orthographicMatrix left:0 right:(GLfloat)size.width bottom:0 top:(GLfloat)size.height near:-1.0 far:1.0];
      glUniformMatrix4fv([_gpuRenderer uniformIndex:@"orthographicMatrix"], 1, GL_FALSE, orthographicMatrix);
    }];
  }
  return self;
}

- (UIImage *)processUIImage:(UIImage *)srcUIImage toSize:(const CGSize)size {
  __block UIImage *image1 = nil;
  
  [_gpuRenderer withContextDo:^{
    UIImage *image2 = nil;
    GLint horizontalPass = [_gpuRenderer uniformIndex:@"horizontalPass"];
    
    glUniform1i(horizontalPass, 1);
    image1 = [super processUIImage:srcUIImage toSize:size];
    image2 = [super processUIImage:image1 toSize:size];
    image1 = [super processUIImage:image2 toSize:size];
  }];
  
  return image1;
}

@end
