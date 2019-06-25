/////////////////////////////////////////////////////////////////////////////////////////////////////
///	
///  @file       DrawModel.h
///  @copyright  Copyright © 2019 小灬豆米. All rights reserved.
///  @brief      DrawModel
///  @date       2019/6/23
///  @author     小灬豆米
///
/////////////////////////////////////////////////////////////////////////////////////////////////////

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PaintPointModel : NSObject

@property (nonatomic, assign) CGPoint loaction;
@property (nonatomic, assign) CGFloat lineWidth;

@end

@interface PaintModel : NSObject

@property (nonatomic, strong) UIColor *lineColor;
@property (nonatomic, strong) NSMutableArray<PaintPointModel *> *pointArray;

@end

NS_ASSUME_NONNULL_END
