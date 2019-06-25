/////////////////////////////////////////////////////////////////////////////////////////////////////
///	
///  @file       PaintView.m
///  @copyright  Copyright © 2019 小灬豆米. All rights reserved.
///  @brief      PaintView
///  @date       2019/6/23
///  @author     小灬豆米
///
/////////////////////////////////////////////////////////////////////////////////////////////////////

#import "PaintView.h"
#import "PaintModel.h"
#import "shaderUtil.h"
#import "fileUtil.h"
#import "debug.h"
#import <OpenGLES/ES3/gl.h>
#import <OpenGLES/ES3/glext.h>
#import <OpenGLES/EAGLDrawable.h>
#import <GLKit/GLKit.h>

#define kBrushOpacity        (1.0 / 3.0)
#define kBrushPixelStep        3
#define kBrushScale            2

// MARKS Shaders Info
enum {
    PROGRAM_POINT,
    NUM_PROGRAMS
};

enum {
    UNIFORM_MVP,
    UNIFORM_POINT_SIZE,
    UNIFORM_VERTEX_COLOR,
    UNIFORM_TEXTURE,
    NUM_UNIFORMS
};

enum {
    ATTRIB_VERTEX,
    NUM_ATTRIBS
};

typedef struct {
    char *vert, *frag;
    GLint uniform[NUM_UNIFORMS];
    GLuint id;
} programInfo_t;

programInfo_t program[NUM_PROGRAMS] = {
    {"point.vsh", "point.fsh"},
};

// MARKS: Texture
typedef struct {
    GLuint id;
    GLsizei width, height;
} textureInfo_t;

FOUNDATION_STATIC_INLINE double CalculatorWidth(double speed, double force, GLsizei normalWidth) {
    double v4 = 1.5;
    double v5 = normalWidth;
    double v6 = normalWidth * 0.7 + v4 * (v5 * 200.0 / speed) * 0.6;
    double v7 = 0.5;
    double v8;
    if (v6 >= 0.5) {
        v8 = v5 * v4;
        v7 = v6;
        if (v6 > v8) {
            v7 = v8;
        }
    }
    return force * 3.0 + v7;
}

@interface PaintViewConfig ()

@property (nonatomic, strong, readwrite) UIImage *textureImage;

@end

@implementation PaintViewConfig

- (void)setTextureImageName:(NSString *)textureImageName {
    self.changeTexture = ![_textureImageName isEqualToString:textureImageName];
    
    if (self.shouldChangeTexture) {
        _textureImageName = textureImageName;
        UIImage *textureImage = [UIImage imageNamed:textureImageName];
        self.textureImage = textureImage;
    }
}

@end

@interface PaintView ()
{
    EAGLContext *_context;
    
    GLuint vboID;
    
    GLint _backgroundWidth, _backgroundHeight;
    GLuint _viewRenderbuffer, _viewFramebuffer, _depthRenderbuffer;
    
    textureInfo_t _brushTexture;
    GLfloat _brushColor[4];
    
    GLuint _vertexShader, _fragmentShader, _shaderProgram;
    
    GLuint mMSAAFramebuffer, mMSAARenderbuffer, mMSAADepthRenderbuffer;
}

@property (nonatomic, strong, readwrite) PaintViewConfig *config;
@property (nonatomic, strong) NSMutableArray<PaintModel *> *pointModelArray;
@property (nonatomic, assign) NSTimeInterval timestamp;

@end

@implementation PaintView

- (void)dealloc
{
    // Destroy framebuffers and renderbuffers
    if (_viewFramebuffer) {
        glDeleteFramebuffers(1, &_viewFramebuffer);
        _viewFramebuffer = 0;
    }
    if (_viewRenderbuffer) {
        glDeleteRenderbuffers(1, &_viewRenderbuffer);
        _viewRenderbuffer = 0;
    }

    // texture
    if (_brushTexture.id) {
        glDeleteTextures(1, &_brushTexture.id);
        _brushTexture.id = 0;
    }
    // vbo
    if (vboID) {
        glDeleteBuffers(1, &vboID);
        vboID = 0;
    }
    
    // tear down context
    if ([EAGLContext currentContext] == _context) {
        [EAGLContext setCurrentContext:nil];
    }
}

+ (Class)layerClass {
    return [CAEAGLLayer class];
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (instancetype)initWithConfig:(PaintViewConfig *)config frame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.config = config;
        [self commonInit];
    }
    
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    CGFloat height = CGRectGetHeight(self.bounds);
    UITouch *touch = [event touchesForView:self].anyObject;
    CGPoint location = [touch locationInView:self];
    
    if (self.config.shouldChangeTexture) {
        _brushTexture = [self setUpTextureWithImage:self.config.textureImage];
        [self setUpShaders];
        self.config.changeTexture = NO;
    }
    
    PaintPointModel *pointModel = [[PaintPointModel alloc] init];
    pointModel.loaction = CGPointMake(location.x, height - location.y);
    
    PaintModel *model = [[PaintModel alloc] init];
    [model.pointArray addObject:pointModel];
    
    [self.pointModelArray addObject:model];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    CGFloat height = CGRectGetHeight(self.bounds);
    UITouch *touch = [event touchesForView:self].anyObject;
    CGPoint location = [touch locationInView:self];
    
    CGPoint preLocation = self.pointModelArray.lastObject.pointArray.lastObject.loaction;
//    location.y = height - location.y;
//    preLocation = [touch previousLocationInView:self];
//    preLocation.y = height - preLocation.y;

    PaintModel *model = self.pointModelArray.lastObject;
    
    PaintPointModel *pointModel = [[PaintPointModel alloc] init];
    pointModel.loaction = CGPointMake(location.x, height - location.y);
    [model.pointArray addObject:pointModel];
    
//    if (self.config.needAddSpeed) {
//        CGFloat distance = sqrtf(pow(location.x - preLocation.x, 2) + pow(location.y - preLocation.y, 2));
//
//        if (distance >= 2.0) {
//            CGFloat timeOffset = touch.timestamp - self.timestamp;
//            self.timestamp = touch.timestamp;
//            CGFloat speed = distance / timeOffset;
//            double value = CalculatorWidth(speed, touch.force, self.config.defaultWidth);
//
//            if (value > 0.0f) {
//                pointModel.lineWidth = value;
//                glUniform1f(program[PROGRAM_POINT].uniform[UNIFORM_POINT_SIZE], value);
//            }
//        }
//    }
    
    [self renderLineFromPoint:preLocation toPoint:pointModel.loaction];
//    [self renderLineFromPoint:preLocation toPoint:location];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self touchesMoved:touches withEvent:event];
}

#pragma mark - Public Methods

- (void)clear {
    [EAGLContext setCurrentContext:_context];
    
    // Clear the buffer
    glBindFramebuffer(GL_FRAMEBUFFER, _viewFramebuffer);
    glClearColor(0.0, 0.0, 0.0, 0.0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    // Display the buffer
    glBindRenderbuffer(GL_RENDERBUFFER, _viewRenderbuffer);
    [_context presentRenderbuffer:GL_RENDERBUFFER];
    
    [self.pointModelArray removeAllObjects];
}

- (void)undo {
    if (!self.pointModelArray.count) return;
    
    [self.pointModelArray removeLastObject];
    
    if (self.pointModelArray.count == 0) {
        [self clear];
        return;
    }
    
    [EAGLContext setCurrentContext:_context];
    glBindFramebuffer(GL_FRAMEBUFFER, _viewFramebuffer);
    glClearColor(0.0, 0.0, 0.0, 0.0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    for (PaintModel *model in self.pointModelArray) {
        for (NSUInteger i = 0; i < model.pointArray.count - 1; i++) {
            CGPoint start = model.pointArray[i].loaction;
            CGPoint end = model.pointArray[i + 1].loaction;
            
            if (self.config.needAddSpeed) {
                glUniform1f(program[PROGRAM_POINT].uniform[UNIFORM_POINT_SIZE], model.pointArray[i].lineWidth);
            }
            
            [self setDrawArray:start toPoint:end];
        }
    }
    
    glBindRenderbuffer(GL_RENDERBUFFER, _viewRenderbuffer);
    [_context presentRenderbuffer:GL_RENDERBUFFER];
}

#pragma mark - Customized

- (void)commonInit {
    
    if (![self setUpContext]) {
        return;
    }
    
    self.contentScaleFactor = [UIScreen mainScreen].scale;
    
    UIColor *color = [UIColor blackColor];
    _brushColor[0] = CGColorGetComponents(color.CGColor)[0] * kBrushOpacity;
    _brushColor[1] = CGColorGetComponents(color.CGColor)[1] * kBrushOpacity;
    _brushColor[1] = CGColorGetComponents(color.CGColor)[2] * kBrushOpacity;
    _brushColor[3] = kBrushOpacity;
    
    [self setUpBuffers];
//    [self render];
    
    self.pointModelArray = @[].mutableCopy;
    self.userInteractionEnabled = YES;
}

- (BOOL)setUpContext {
    CAEAGLLayer *glLayer = (CAEAGLLayer *)self.layer;
    glLayer.opaque = YES;
    glLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                  [NSNumber numberWithBool:YES], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
    
    _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    
    if (!_context || ![EAGLContext setCurrentContext:_context]) {
        return NO;
    }
    
    return YES;
}

- (void)setUpBuffers {
    
    [EAGLContext setCurrentContext:_context];
    
    glGenFramebuffers(1, &_viewFramebuffer);
    glGenRenderbuffers(1, &_viewRenderbuffer);
    
    glBindFramebuffer(GL_FRAMEBUFFER, _viewFramebuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _viewRenderbuffer);
    
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(id<EAGLDrawable>)self.layer];
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _viewRenderbuffer);
    
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backgroundWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backgroundHeight);
    
    glGenRenderbuffers(1, &_depthRenderbuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _depthRenderbuffer);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT16, _backgroundWidth, _backgroundHeight);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, _depthRenderbuffer);
    
    if(glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
    {
        NSLog(@"failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
        return;
    }
    
    glViewport(0, 0, _backgroundWidth, _backgroundHeight);
    glGenBuffers(1, &vboID);
    
    _brushTexture = [self setUpTextureWithImage:self.config.textureImage];
    self.config.changeTexture = NO;
    [self setUpShaders];
    
    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
}

//- (void)render {
//    if(glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
//    {
//        NSLog(@"failed to make complete framebuffer object %x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
//        return;
//    }
//
//    glViewport(0, 0, _backgroundWidth, _backgroundHeight);
//    glGenBuffers(1, &vboID);
//
//    _brushTexture = [self setUpTextureWithImage:self.config.textureImage];
//    self.config.changeTexture = NO;
//    [self setUpShaders];
//
//    glEnable(GL_BLEND);
//    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
//}

- (void)setUpShaders {
    for (int i = 0; i < NUM_PROGRAMS; i++)
    {
        char *vsrc = readFile(pathForResource(program[i].vert));
        char *fsrc = readFile(pathForResource(program[i].frag));
        GLsizei attribCt = 0;
        GLchar *attribUsed[NUM_ATTRIBS];
        GLint attrib[NUM_ATTRIBS];
        GLchar *attribName[NUM_ATTRIBS] = {
            "inVertex",
        };
        const GLchar *uniformName[NUM_UNIFORMS] = {
            "MVP", "pointSize", "vertexColor", "texture",
        };
        
        // auto-assign known attribs
        for (int j = 0; j < NUM_ATTRIBS; j++)
        {
            if (strstr(vsrc, attribName[j]))
            {
                attrib[attribCt] = j;
                attribUsed[attribCt++] = attribName[j];
            }
        }
        
        glueCreateProgram(vsrc, fsrc,
                          attribCt, (const GLchar **)&attribUsed[0], attrib,
                          NUM_UNIFORMS, &uniformName[0], program[i].uniform,
                          &program[i].id);
        free(vsrc);
        free(fsrc);
        
        // Set constant/initalize uniforms
        if (i == PROGRAM_POINT)
        {
            glUseProgram(program[PROGRAM_POINT].id);
            
            // the brush texture will be bound to texture unit 0
            glUniform1i(program[PROGRAM_POINT].uniform[UNIFORM_TEXTURE], 0);
            
            // viewing matrices
            GLKMatrix4 projectionMatrix = GLKMatrix4MakeOrtho(0, _backgroundWidth, 0, _backgroundHeight, -1, 1);
            GLKMatrix4 modelViewMatrix = GLKMatrix4Identity; // this sample uses a constant identity modelView matrix
            GLKMatrix4 MVPMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
            
            glUniformMatrix4fv(program[PROGRAM_POINT].uniform[UNIFORM_MVP], 1, GL_FALSE, MVPMatrix.m);
            
            // point size
            float size = (_brushTexture.width);
            glUniform1f(program[PROGRAM_POINT].uniform[UNIFORM_POINT_SIZE], size);
            
            // initialize brush color
            glUniform4fv(program[PROGRAM_POINT].uniform[UNIFORM_VERTEX_COLOR], 1, _brushColor);
        }
    }
    
    glError();
}

- (textureInfo_t)setUpTextureWithImage:(UIImage *)image {
    
    textureInfo_t texture = {};
    
    if (!image) return texture;
    
    CGImageRef brushImage = image.CGImage;
    
    size_t width = CGImageGetWidth(brushImage);
    size_t height = CGImageGetHeight(brushImage);

//    CGFloat ratio = height / width;
//
//    width = (size_t)self.config.defaultWidth;
//    height = (size_t)(self.config.defaultWidth * ratio);
    
    GLubyte *brushData = (GLubyte *) calloc(width * height * 4, sizeof(GLubyte));
    
    CGContextRef brushContext = CGBitmapContextCreate(brushData, width, height, 8, width * 4, CGImageGetColorSpace(brushImage), kCGImageAlphaPremultipliedLast);
    
    CGContextDrawImage(brushContext, CGRectMake(0, 0, (CGFloat)width, (CGFloat)height), brushImage);
    CGContextRelease(brushContext);
    
    GLuint textureID;
    glGenTextures(1, &textureID);
    
    glBindTexture(GL_TEXTURE_2D, textureID);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (int)width, (int)height, 0, GL_RGBA, GL_UNSIGNED_BYTE, brushData);
    free(brushData);
    
    texture.id = textureID;
//    texture.width = (int)self.config.defaultWidth;
    //    texture.height = (int)self.config.defaultWidth;
    
    texture.width = (int)width * 0.65;
    texture.height = (int)height * 0.65;
    
    return texture;
}

- (void)renderLineFromPoint:(CGPoint)start toPoint:(CGPoint)end {
    [EAGLContext setCurrentContext:_context];
    glBindFramebuffer(GL_FRAMEBUFFER, _viewFramebuffer);
    
//    [self setDrawArray:start toPoint:end];
    static GLfloat*        vertexBuffer = NULL;
    static NSUInteger    vertexMax = 64;
    NSUInteger            vertexCount = 0,
    count,
    i;
    
    [EAGLContext setCurrentContext:_context];
    
    glBindFramebuffer(GL_FRAMEBUFFER, _viewFramebuffer);
    // Convert locations from Points to Pixels
    CGFloat scale = self.contentScaleFactor;
    start.x *= scale;
    start.y *= scale;
    end.x *= scale;
    end.y *= scale;
    
    count = MAX(ceilf(sqrtf((end.x - start.x) * (end.x - start.x) + (end.y - start.y) * (end.y - start.y)) / kBrushPixelStep), 1);
    count += 100;
    
    if(vertexBuffer == NULL) {
        vertexMax = count;
        vertexBuffer = malloc(vertexMax * 2 * sizeof(GLfloat));
    }
    
    for(i = 0; i < count; ++i) {
        
        if(vertexCount == vertexMax) {
            vertexMax = 2 * vertexMax;
            vertexBuffer = realloc(vertexBuffer, vertexMax * 2 * sizeof(GLfloat));
        }
        
        vertexBuffer[2 * vertexCount + 0] = start.x + (end.x - start.x) * ((GLfloat)i / (GLfloat)count);
        vertexBuffer[2 * vertexCount + 1] = start.y + (end.y - start.y) * ((GLfloat)i / (GLfloat)count);
        vertexCount += 1;
    }
    
    // Load data to the Vertex Buffer Object
    glBindBuffer(GL_ARRAY_BUFFER, vboID);
    glBufferData(GL_ARRAY_BUFFER, vertexCount*2*sizeof(GLfloat), vertexBuffer, GL_DYNAMIC_DRAW);
    
    glEnableVertexAttribArray(ATTRIB_VERTEX);
    glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, GL_FALSE, 0, 0);
    
    // Draw
    glUseProgram(program[PROGRAM_POINT].id);
    glDrawArrays(GL_POINTS, 0, (int)vertexCount);
    
    glBindRenderbuffer(GL_RENDERBUFFER, _viewRenderbuffer);
    [_context presentRenderbuffer:GL_RENDERBUFFER];
}

- (void)setDrawArray:(CGPoint)start toPoint:(CGPoint)end {
    static GLfloat*        vertexBuffer = NULL;
    static NSUInteger    vertexMax = 64;
    NSUInteger            vertexCount = 0,
    count,
    i;
    
    [EAGLContext setCurrentContext:_context];
    
    glBindFramebuffer(GL_FRAMEBUFFER, _viewFramebuffer);
    // Convert locations from Points to Pixels
    CGFloat scale = self.contentScaleFactor;
    start.x *= scale;
    start.y *= scale;
    end.x *= scale;
    end.y *= scale;
    
    count = MAX(ceilf(sqrtf((end.x - start.x) * (end.x - start.x) + (end.y - start.y) * (end.y - start.y)) / kBrushPixelStep), 1);
    count += 100;
    
    if(vertexBuffer == NULL) {
        vertexMax = count;
        vertexBuffer = malloc(vertexMax * 2 * sizeof(GLfloat));
    }
    
    for(i = 0; i < count; ++i) {
        
        if(vertexCount == vertexMax) {
            vertexMax = 2 * vertexMax;
            vertexBuffer = realloc(vertexBuffer, vertexMax * 2 * sizeof(GLfloat));
        }
        
        vertexBuffer[2 * vertexCount + 0] = start.x + (end.x - start.x) * ((GLfloat)i / (GLfloat)count);
        vertexBuffer[2 * vertexCount + 1] = start.y + (end.y - start.y) * ((GLfloat)i / (GLfloat)count);
        vertexCount += 1;
    }
    
    // Load data to the Vertex Buffer Object
    glBindBuffer(GL_ARRAY_BUFFER, vboID);
    glBufferData(GL_ARRAY_BUFFER, vertexCount*2*sizeof(GLfloat), vertexBuffer, GL_DYNAMIC_DRAW);
    
    glEnableVertexAttribArray(ATTRIB_VERTEX);
    glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, GL_FALSE, 0, 0);
    
    // Draw
    glUseProgram(program[PROGRAM_POINT].id);
    glDrawArrays(GL_POINTS, 0, (int)vertexCount);
}

@end
