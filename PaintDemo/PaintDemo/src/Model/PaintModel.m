/////////////////////////////////////////////////////////////////////////////////////////////////////
///	
///  @file       DrawModel.m
///  @copyright  Copyright © 2019 小灬豆米. All rights reserved.
///  @brief      DrawModel
///  @date       2019/6/23
///  @author     小灬豆米
///
/////////////////////////////////////////////////////////////////////////////////////////////////////

#import "PaintModel.h"

@implementation PaintPointModel

@end

@implementation PaintModel

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.pointArray = @[].mutableCopy;
    }
    return self;
}

@end
