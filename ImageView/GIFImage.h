//
//  GIFImage.h
//  JddGame
//
//  Created by Kattern on 2017/8/2.
//  Copyright © 2017年 JddGame. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface GIFImage : UIImage
@property (nonatomic, readonly) NSTimeInterval *frameDurations;
@property (nonatomic, readonly) NSTimeInterval totalDuration;
@property (nonatomic, readonly) NSUInteger loopCount;
- (UIImage*)getFrameWithIndex:(NSUInteger)idx;
@end
