//
//  CardIOGPURenderer.m
//  See the file "LICENSE.md" for the full license governing this code.
//

#import "CardIOGPURenderer.h"
#import "CardIOMacros.h"
#import "dmz.h"
#import <OpenGLES/ES2/glext.h>
#import <OpenGLES/ES3/gl.h>

typedef struct {
  float Position[3];
  float TexCoord[2];
} Vertex;

const GLubyte Indices[] = {
  0, 1, 2,
  2, 3, 0
};

@interface CardIOGPURenderer()
@property (nonatomic, strong, readwrite) EAGLContext *context;
@end

@implementation CardIOGPURenderer

- (id)initWithSize:(CGSize)size vertexShaderSrc:(NSString *)vertexShaderSrc fragmentShaderSrc:(NSString *)fragmentShaderSrc {
  self = [super init];
  if (self) {
    _size = size;
    
    __block BOOL successfulSetup = NO;

    [self withContextDo:^{
      [self setupGL];
      if ([self compileProgramWithVertexShaderSrc:vertexShaderSrc fragmentShaderSrc:fragmentShaderSrc]) {
        [self prepareForUse];
        successfulSetup = YES;
      }
    }];

    if (!successfulSetup) {
      self = nil;
    }
  }
  return self;
}

- (void)dealloc {
  [self finish];
}

- (void)finish {
  if (self.context) {
    [self withContextDo:^{
      glFinish();
    }];
  }
}

#pragma mark Setup helpers

- (void)withContextDo:(void (^)(void))successBlock {
  // Be extra careful; MKMapKit, for one, doesn't expect anyone to swap contexts out from under it.
  // See https://github.paypal.com/card-io/icc/issues/28 and https://github.com/card-io/card.io-iOS-SDK/issues/10
  
  // Note that if formerContext == self.context,then this method is essentially a no-op.
  // Therefore, unnecessarily redundant calls to this method are harmless.
  
  EAGLContext *formerContext = [EAGLContext currentContext];
  
  if (!_context) {
    _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
  }
  
  if (!_context) {
    CardIOLog(@"Failed to initialize OpenGLES 2.0 context");
  }
  else {
    BOOL contextSet = NO;
    if (_context == formerContext) {
      contextSet = YES;
    }
    else {
      if (formerContext != nil) {
        // this glFlush() recommended by http://developer.apple.com/library/ios/#documentation/3DDrawing/Conceptual/OpenGLES_ProgrammingGuide/WorkingwithOpenGLESContexts/WorkingwithOpenGLESContexts.html
        glFlush();
      }

      if ([EAGLContext setCurrentContext:_context]) {
        contextSet = YES;
      }
      else {
        CardIOLog(@"Failed to set current OpenGL context");
        if (![EAGLContext setCurrentContext:formerContext]) {
          CardIOLog(@"Failed to reset former OpenGL context");
        }
      }
    }
    
    if (contextSet) {
      if (successBlock) {
        successBlock();
        glFlush();
        if (![EAGLContext setCurrentContext:formerContext]) {
          CardIOLog(@"Failed to reset former OpenGL context");
        }
      }
    }
  }
}

- (void) setupGL {
  [self withContextDo:^{
    // FRAMEBUFFER
    
    // generate framebuffer handler and set it up
    GLuint framebuffer;
    glGenFramebuffers(1, &framebuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
    
    // generate renderbuffer handle and set it up with storage
    GLuint colorRenderBuffer;
    glGenRenderbuffers(1, &colorRenderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, colorRenderBuffer);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_RGBA8_OES, (GLsizei)_size.width, (GLsizei)_size.height);
    
    // assoc renderbuffer with framebuffer
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, colorRenderBuffer);
    
    
    // VERTICES
    
    float w = (float)_size.width;
    float h = (float)_size.height;
    
    const Vertex v[] = {
      {{w, 0, 0}, {1, 0}},
      {{w, h, 0}, {1, 1}},
      {{0, h, 0}, {0, 1}},
      {{0, 0, 0}, {0, 0}}
    };
    
    // Set up vertex buffer and indexBuffer
    
    GLuint vertexBuffer;
    glGenBuffers(1, &vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(v), v, GL_STATIC_DRAW);
    
    GLuint indexBuffer;
    glGenBuffers(1, &indexBuffer);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(Indices), Indices, GL_STATIC_DRAW);
    
    // TEXTURES
    // Create texture handle
    glGenTextures(1, &_inputTexture);
  }];
}

- (BOOL)compileProgramWithVertexShaderSrc:(NSString *)vertexShaderSrc fragmentShaderSrc:(NSString *)fragmentShaderSrc {
  __block BOOL successful = NO;
  [self withContextDo:^{
    GLuint vertexShader, fragmentShader;
    // compile shaders, prepare program
    if ([[self class] compileShader:&vertexShader type:GL_VERTEX_SHADER source:vertexShaderSrc] &&
        [[self class] compileShader:&fragmentShader type:GL_FRAGMENT_SHADER source:fragmentShaderSrc] &&
        [[self class] prepareProgram:&_programHandle vertexShader:vertexShader fragmentShader:fragmentShader]) {
      // use program!
      glUseProgram(_programHandle);
      
      _positionSlot = glGetAttribLocation(_programHandle, "position");
      glEnableVertexAttribArray(_positionSlot);
      
      _texCoordSlot = glGetAttribLocation(_programHandle, "texCoordIn");
      glEnableVertexAttribArray(_texCoordSlot);
      _textureUniform = glGetUniformLocation(_programHandle, "texture");
      
      successful = YES;
    }
  }];
  
  return successful;
}

- (void)prepareForUse {
  [self withContextDo:^{
    glEnable(GL_TEXTURE_2D); // Enable textures
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f); // Set clear color to black, then clear all.
    glClear(GL_COLOR_BUFFER_BIT);
  }];
}

#pragma mark Textures

- (void)prepareTexture {
  [self withContextDo:^{
    glBindTexture(GL_TEXTURE_2D, _inputTexture);
    
    // Bi-linear interpolation for both minification and magnification
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    
    // This is necessary for non-power-of-two textures
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  }];
}

- (void)renderToSize:(const CGSize)targetSize {
  // Setup viewport to same size as image
  [self withContextDo:^{
    [self prepareForUse];
    glViewport(0, 0, (GLsizei)targetSize.width, (GLsizei)targetSize.height);
    
    glVertexAttribPointer(_positionSlot, 3, GL_FLOAT, GL_FALSE,
                          sizeof(Vertex), 0);
    
    glVertexAttribPointer(_texCoordSlot, 2, GL_FLOAT, GL_FALSE, sizeof(Vertex), (GLvoid *) (sizeof(float) * 3));
    
    // Bind image to _textureUniform
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _inputTexture);
    glUniform1f(_textureUniform, 0);
    
    glDrawElements(GL_TRIANGLES, sizeof(Indices)/sizeof(Indices[0]), GL_UNSIGNED_BYTE, 0);
  }];
}

#pragma mark Uniform access

- (GLuint) uniformIndex:(NSString *)uniformName {
  __block GLuint uniformIndex = -1;
  [self withContextDo:^{
    uniformIndex = glGetUniformLocation(_programHandle, [uniformName UTF8String]);
  }];
  return uniformIndex;
}

#pragma mark UIImage handling

- (void)setInputTextureUIImage:(UIImage *)image {
  
  // get CGImage out of UIImage
  CGImageRef spriteImage = image.CGImage;
  
  // get height/width for use later
  size_t width = CGImageGetWidth(spriteImage);
  size_t height = CGImageGetHeight(spriteImage);
  
  // create a buffer for the image data
  GLubyte *spriteData = (GLubyte *) calloc(width * height * 4, sizeof(GLubyte));
  
  // set up a CGContext
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  CGContextRef spriteContext = CGBitmapContextCreate(spriteData, width, height, 8, width * 4, colorSpace, kCGImageAlphaPremultipliedLast);
  CGColorSpaceRelease(colorSpace);
  
  // draw the image into the context's data
  CGContextDrawImage(spriteContext, CGRectMake(0, 0, width, height), spriteImage);
  
  [self withContextDo:^{
    // Generate a texture name
    [self prepareTexture];
    
    // Put the sprite data into the texture
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (GLsizei)width, (GLsizei)height, 0, GL_RGBA, GL_UNSIGNED_BYTE, spriteData);
  }];
  
  // release the context
  CGContextRelease(spriteContext);
  
  // release the data
  free(spriteData);
  
}

- (void)renderUIImage:(UIImage *)inputImage toSize:(const CGSize)targetSize {
  [self withContextDo:^{
    [self prepareForUse];
    [self setInputTextureUIImage:inputImage];
    [self renderToSize:targetSize];
  }];
}

- (UIImage *)captureUIImageOfSize:(const CGSize)size {
  __block uint8_t *buffer = NULL;

  [self withContextDo:^{
    glFlush();
    buffer = (uint8_t *) malloc((size_t)(size.width * size.height * 4));
    glReadPixels(0, 0, (GLsizei)size.width, (GLsizei)size.height, GL_RGBA, GL_UNSIGNED_BYTE, buffer);
  }];

  // Put into UIImage
  CGDataProviderRef ref = CGDataProviderCreateWithData(NULL, buffer, (size_t)(size.width * size.height * 4), NULL);
  
  CGColorSpaceRef colorSpaceRef = CGColorSpaceCreateDeviceRGB();
  
  CGImageRef iref = CGImageCreate((size_t)size.width, (size_t)size.height, 8, 32, (size_t)(size.width * 4), colorSpaceRef, kCGBitmapByteOrderDefault, ref, NULL, true, kCGRenderingIntentDefault);
  
  UIImage *resultImg = [UIImage imageWithCGImage:iref];
  
  CGImageRelease(iref);
  CGDataProviderRelease(ref);
  CGColorSpaceRelease(colorSpaceRef);
  return resultImg;
}

#if USE_CAMERA
#pragma mark IplImage handling

- (void)setInputTextureIplImage:(IplImage *)image {
  [self withContextDo:^{
    [self prepareTexture];
    
#if CARDIO_DEBUG
    while (glGetError()); // Clear GL Errors
#endif
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, image->width, image->height, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, image->imageData);
    
#if CARDIO_DEBUG
    GLuint error = glGetError();
    if (error != GL_NO_ERROR) {
      CardIOLog(@"glTexImage2D error: %u", error);
    }
#endif
  }];
}

- (void)renderIplImage:(IplImage *)inputImage toSize:(const CGSize)targetSize {
  [self withContextDo:^{
    [self prepareForUse];
    [self setInputTextureIplImage:inputImage];
    [self renderToSize:targetSize];
  }];
}

// Capture an IPL Image from the framebuffer.
//
- (void)captureIplImage:(IplImage *)dstImg {
  __block uint8_t *buffer = NULL;
  
  [self withContextDo:^{
    glFlush();
    buffer = (uint8_t *) malloc(dstImg->imageSize * 4);
    
    // Can only read out to RGBA.
    while (glGetError());
    glReadPixels(0, 0, dstImg->width, dstImg->height, GL_RGBA, GL_UNSIGNED_BYTE, buffer);
    GLuint error = glGetError();
    if (error) {
      CardIOLog(@"glReadPixels Error: %u", error);
    }
  }];
  
  CvMat dststub, *dst = cvGetMat( dstImg, &dststub );
  if (dstImg->widthStep == dstImg->width) {
    dmz_deinterleave_RGBA_to_R(buffer, dst->data.ptr, dstImg->imageSize);
  }
  else {
    for (int rowStart = 0; rowStart < dstImg->imageSize; rowStart += dstImg->widthStep) {
      dmz_deinterleave_RGBA_to_R(&buffer[rowStart], &dst->data.ptr[rowStart * 4], dstImg->width);
    }
  }

  free(buffer);
}

#endif // USE_CAMERA

#pragma mark Compile

+ (BOOL)compileShader:(GLuint *)shader type:(GLenum)type source:(NSString *)str {
  GLint logLen = 0, 
  success = GL_FALSE;
  
  const GLchar *source = (GLchar *)[str UTF8String];
  *shader = glCreateShader(type);
  glShaderSource(*shader, 1, &source, NULL);
  glCompileShader(*shader);
  
  // Check the status of the compile/link
  glGetShaderiv(*shader, GL_COMPILE_STATUS, &success);
  if (success != GL_TRUE) {
    CardIOLog(@"Shader compile failed");
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLen);
    if (logLen > 0)
    {
      // Show any errors as appropriate
      GLchar *log = (GLchar *)malloc(logLen);
      glGetShaderInfoLog(*shader, logLen, &logLen, log);
      CardIOLog(@"Shader compile log:\n%s", log);
      free(log);
    }
    return NO;
  }
  else {
    CardIOLog(@"Shader compile OK");
    return YES;
  }
}

+ (BOOL)prepareProgram:(GLuint *)program vertexShader:(GLuint)vertexShader fragmentShader:(GLuint) fragmentShader {
  // Validate program
  
  GLint logLen = 0, 
  success = GL_FALSE;
  
  *program = glCreateProgram();
  glAttachShader(*program, vertexShader);
  glAttachShader(*program, fragmentShader);
  glLinkProgram(*program);
  glValidateProgram(*program);
  
  // Check the status of the compile/link
  glGetProgramiv(*program, GL_LINK_STATUS, &success);
  if (success != GL_TRUE) {
    CardIOLog(@"Program link failed");
    glGetProgramiv(*program, GL_INFO_LOG_LENGTH, &logLen);
    if (logLen > 0) {
      // Show any errors as appropriate
      GLchar *log = (GLchar *)malloc(logLen);
      glGetProgramInfoLog(*program, logLen, &logLen, log);
      CardIOLog(@"Program Log: %s\n", log);
      free(log);
    }
    return NO;
  }
  else {
    CardIOLog(@"Program link OK");
    return YES;
  }
}

@end
