//
//  GIFImage.m
//  JddGame
//
//  Created by Kattern on 2017/8/2.
//  Copyright © 2017年 JddGame. All rights reserved.
//

#import "GIFImage.h"
#import <ImageIO/ImageIO.h>
#import <SDWebImage/NSData+ImageContentType.h>

static NSUInteger _prefetchedNum = 10;

@interface GIFImage()
{
    dispatch_queue_t readFrameQueue;
    CGImageSourceRef _imageSourceRef;
    CGFloat _scale;
}
@property (nonatomic, readwrite) NSMutableArray *images;
@property (nonatomic, readwrite) NSTimeInterval *frameDurations;
@property (nonatomic, readwrite) NSTimeInterval totalDuration;
@property (nonatomic, readwrite) NSUInteger loopCount;
@property (nonatomic, readwrite) CGImageSourceRef incrementalSource;
@end
@implementation GIFImage
@synthesize images;

+ (nullable UIImage *)imageWithData:(NSData *)data
{
    return [self imageWithData:data scale:1.0];
}
+ (nullable UIImage *)imageWithData:(NSData *)data scale:(CGFloat)scale
{
    if (!data) return nil;
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)(data), NULL);
    UIImage *image;
    if ([[NSData sd_contentTypeForImageData:data] isEqualToString:@"image/gif"]){
        image = [[self alloc] initWithCGImageSource:source scale:scale];
    }else{
        image = [super imageWithData:data scale:scale];
    }
    if (source){
        CFRelease(source);
    }
    return image;
}
- (id)initWithCGImageSource:(CGImageSourceRef)imageSource scale:(CGFloat)scale
{
    self = [super init];
    if (!imageSource || !self) {
        return nil;
    }
    
    CFRetain(imageSource);
    
    NSUInteger numberOfFrames = CGImageSourceGetCount(imageSource);
    
    NSDictionary *imageProperties = CFBridgingRelease(CGImageSourceCopyProperties(imageSource, NULL));
    NSDictionary *gifProperties = [imageProperties objectForKey:(NSString *)kCGImagePropertyGIFDictionary];
    
    self.frameDurations = (NSTimeInterval *)malloc(numberOfFrames  * sizeof(NSTimeInterval));
    self.loopCount = [gifProperties[(NSString *)kCGImagePropertyGIFLoopCount] unsignedIntegerValue];
    self.images = [NSMutableArray arrayWithCapacity:numberOfFrames];
    
    NSNull *aNull = [NSNull null];
    for (NSUInteger i = 0; i < numberOfFrames; ++i) {
        [self.images addObject:aNull];
        NSTimeInterval frameDuration = [self sd_frameDurationAtIndex:i source:imageSource];
        self.frameDurations[i] = frameDuration;
        self.totalDuration += frameDuration;
    }
    //CFTimeInterval start = CFAbsoluteTimeGetCurrent();
    // Load first frame
    NSUInteger num = MIN(_prefetchedNum, numberOfFrames);
    for (NSUInteger i=0; i<num; i++) {
        CGImageRef image = CGImageSourceCreateImageAtIndex(imageSource, i, NULL);
        if (image != NULL) {
            [self.images replaceObjectAtIndex:i withObject:[UIImage imageWithCGImage:image scale:_scale orientation:UIImageOrientationUp]];
            CFRelease(image);
        } else {
            [self.images replaceObjectAtIndex:i withObject:[NSNull null]];
        }
    }
    _imageSourceRef = imageSource;
    CFRetain(_imageSourceRef);
    CFRelease(imageSource);
    //});
    
    _scale = scale;
    readFrameQueue = dispatch_queue_create("com.ronnie.gifreadframe", DISPATCH_QUEUE_SERIAL);
    
    return self;
}
- (float)sd_frameDurationAtIndex:(NSUInteger)index source:(CGImageSourceRef)source {
    float frameDuration = 0.1f;
    CFDictionaryRef cfFrameProperties = CGImageSourceCopyPropertiesAtIndex(source, index, nil);
    NSDictionary *frameProperties = (__bridge NSDictionary *)cfFrameProperties;
    NSDictionary *gifProperties = frameProperties[(NSString *)kCGImagePropertyGIFDictionary];
    
    NSNumber *delayTimeUnclampedProp = gifProperties[(NSString *)kCGImagePropertyGIFUnclampedDelayTime];
    if (delayTimeUnclampedProp) {
        frameDuration = [delayTimeUnclampedProp floatValue];
    }
    else {
        
        NSNumber *delayTimeProp = gifProperties[(NSString *)kCGImagePropertyGIFDelayTime];
        if (delayTimeProp) {
            frameDuration = [delayTimeProp floatValue];
        }
    }
    if (frameDuration < 0.011f) {
        frameDuration = 0.100f;
    }
    
    CFRelease(cfFrameProperties);
    return frameDuration;
}
- (UIImage*)getFrameWithIndex:(NSUInteger)idx
{
    UIImage* frame = nil;
    @synchronized(self.images) {
        frame = self.images[idx];
    }
    if(!frame) {
        CGImageRef image = CGImageSourceCreateImageAtIndex(_imageSourceRef, idx, NULL);
        if (image != NULL) {
            frame = [UIImage imageWithCGImage:image scale:_scale orientation:UIImageOrientationUp];
            CFRelease(image);
        }
    }
    if(self.images.count > _prefetchedNum) {
        if(idx != 0) {
            [self.images replaceObjectAtIndex:idx withObject:[NSNull null]];
        }
        NSUInteger nextReadIdx = (idx + _prefetchedNum);
        for(NSUInteger i=idx+1; i<=nextReadIdx; i++) {
            NSUInteger _idx = i%self.images.count;
            if([self.images[_idx] isKindOfClass:[NSNull class]]) {
                dispatch_async(readFrameQueue, ^{
                    CGImageRef image = CGImageSourceCreateImageAtIndex(_imageSourceRef, _idx, NULL);
                    @synchronized(self.images) {
                        if (image != NULL) {
                            [self.images replaceObjectAtIndex:_idx withObject:[UIImage imageWithCGImage:image scale:_scale orientation:UIImageOrientationUp]];
                            CFRelease(image);
                        } else {
                            [self.images replaceObjectAtIndex:_idx withObject:[NSNull null]];
                        }
                    }
                });
            }
        }
    }
    return frame;
}
- (CGSize)size
{
    if (self.images.count) {
        GIFImage *image = [self.images objectAtIndex:0];
        return [image size];
    }
    return [super size];
}

- (CGImageRef)CGImage
{
    if (self.images.count) {
        return [[self.images objectAtIndex:0] CGImage];
    } else {
        return [super CGImage];
    }
}

- (UIImageOrientation)imageOrientation
{
    if (self.images.count) {
        return [[self.images objectAtIndex:0] imageOrientation];
    } else {
        return [super imageOrientation];
    }
}

- (CGFloat)scale
{
    if (self.images.count) {
        return [(UIImage *)[self.images objectAtIndex:0] scale];
    } else {
        return [super scale];
    }
}

- (NSTimeInterval)duration
{
    return self.images ? self.totalDuration : [super duration];
}

- (void)dealloc {
    if(_imageSourceRef) {
        CFRelease(_imageSourceRef);
    }
    free(_frameDurations);
    if (_incrementalSource) {
        CFRelease(_incrementalSource);
    }
}
@end
