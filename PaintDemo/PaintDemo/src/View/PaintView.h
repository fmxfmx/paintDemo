/////////////////////////////////////////////////////////////////////////////////////////////////////
///	
///  @file       PaintView.h
///  @copyright  Copyright © 2019 小灬豆米. All rights reserved.
///  @brief      PaintView
///  @date       2019/6/23
///  @author     小灬豆米
///
/////////////////////////////////////////////////////////////////////////////////////////////////////

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PaintViewConfig : NSObject

@property (nonatomic, assign, getter=shouldChangeTexture) BOOL changeTexture;
@property (nonatomic, strong, readonly) UIImage *textureImage;
@property (nonatomic, assign) GLsizei defaultWidth;
@property (nonatomic, copy) NSString *textureImageName;
@property (nonatomic, assign) BOOL needAddSpeed;

@end

@interface PaintView : UIView

@property (nonatomic, strong, readonly) PaintViewConfig *config;

- (instancetype)initWithConfig:(PaintViewConfig *)config frame:(CGRect)frame;
- (void)clear;
- (void)undo;

@end

NS_ASSUME_NONNULL_END
