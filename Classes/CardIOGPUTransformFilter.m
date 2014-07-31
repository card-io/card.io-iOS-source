//
//  CardIOGPUTransformFilter.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#import "CardIOGPUTransformFilter.h"
#import "CardIOGPUShaders.h"
#import "CardIOMacros.h"

NSString *const kCardIOTransformVertexShader = SHADER_STRING
(
 attribute vec4 position;    // input position
 attribute vec2 texCoordIn;  // input texture coordinate
 varying   vec2 texCoordOut; // output texture coordinate (goes to frag shader)
 // "varying" means OpenGL will use interpolation to
 // determine color
 
 uniform mat4 transformMatrix;
 uniform mat4 orthographicMatrix;
 
 void main(void) {
   gl_Position = vec4(orthographicMatrix * transformMatrix * position);
   texCoordOut = texCoordIn;
 }
);

// Fragment shader for drawing texture
NSString *const kCardIOPassthroughFragmentShader = SHADER_STRING
(
 varying lowp vec2 texCoordOut; // input texture coordinate (from vertex shader)
 uniform sampler2D texture; // input texture
 
 void main(void) {
   gl_FragColor = texture2D(texture, texCoordOut).rgba; // Interpolate texture for texCoordOut
 }
);

@implementation CardIOGPUTransformFilter

- (id)initWithSize:(CGSize)size {
  if((self = [super initWithSize:size vertexShaderSrc:kCardIOTransformVertexShader fragmentShaderSrc:kCardIOPassthroughFragmentShader])) {
    [_gpuRenderer withContextDo:^{
      // Get our matrix handles
      _transformMatrixUniform = [_gpuRenderer uniformIndex:@"transformMatrix"];
      _orthographicMatrixUniform = [_gpuRenderer uniformIndex:@"orthographicMatrix"];
      
      // Set up the ortho matrix
      // Could hard-code this into the shader. But it's easier to understand in this form, I think.
      [[self class] loadOrthoMatrix:orthographicMatrix left:-1.0 right:1.0 bottom:-1.0 top:1.0 near:-1.0 far:1.0];
      glUniformMatrix4fv(_orthographicMatrixUniform, 1, GL_FALSE, orthographicMatrix);
    }];
  }
  return self;
}

// Sets the matrix data for use with the vertex shader
- (void)setPerspectiveMat:(float *)matrix {
  [_gpuRenderer withContextDo:^{
    [_gpuRenderer prepareForUse];
    //  CardIOLog(@"GL perspective matrix: \n%@", [[self class] matrixAsString:matrix size:4 rowMajor:NO]);
    glUniformMatrix4fv(_transformMatrixUniform, 1, GL_FALSE, matrix);
  }];
}

@end
