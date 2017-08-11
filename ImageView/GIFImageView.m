//
//  GIFImageView.m
//  JddGame
//
//  Created by Kattern on 2017/8/2.
//  Copyright © 2017年 JddGame. All rights reserved.
//

#import "GIFImageView.h"
#import "GIFImage.h"
@interface GIFImageView()

@end
@implementation GIFImageView

-(void)gifImageWithUrl:(NSString*)url iconImageUrl:(NSString *)iconImageUrl
{
    NSData *gifImageData = [self imageDataFromDiskCacheWithKey:url];
    if (gifImageData){
        [self animatedImageView:self data:gifImageData];
        return;
    
    }
    __weak __typeof(self) weakSelf = self;
    NSURL *newUrl = [NSURL URLWithString:url];
    [[[SDWebImageManager sharedManager] imageDownloader] downloadImageWithURL:newUrl options:0 progress:nil completed:^(UIImage *image, NSData *data, NSError *error, BOOL finished) {
        if (error) {
        
            [self sd_setImageWithURL:[NSURL URLWithString:iconImageUrl] placeholderImage:IMAGE_NAMED(@"unlogin_portrait")];
            
            return ;
        }
        if (image) {
            [[[SDWebImageManager sharedManager] imageCache] storeImage:image recalculateFromImage:NO imageData:data forKey:newUrl.absoluteString toDisk:YES];
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf animatedImageView:weakSelf data:data];
        });
    }];
}
- (void)animatedImageView:(WebGIFImageView *)imageView data:(NSData *)data
{
    GIFImage *gifImage =(GIFImage*) [GIFImage imageWithData:data];
    self.image = gifImage;
}
- (NSData *)imageDataFromDiskCacheWithKey:(NSString *)key
{
    NSString *path = [[[SDWebImageManager sharedManager] imageCache] defaultCachePathForKey:key];
    return [NSData dataWithContentsOfFile:path];
}
@end
