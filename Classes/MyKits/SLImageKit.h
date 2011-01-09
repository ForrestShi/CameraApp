//
// Provide Common ImageKit
// 1. Image Format Transfer 
// 2. Resize 
//
//  Created by forrest on 10-7-17.
//  Copyright 2010 WAVIS LLC. All rights reserved.
//


#import <Foundation/Foundation.h>
#import <opencv/cv.h>


@interface SLImageKit : NSObject {

}

#pragma mark -
#pragma mark format conversion

+ (IplImage *)CreateIplImageFromUIImage:(UIImage *)image ;
+ (IplImage *)CreateIplImageFromCGImage:(CGImageRef)image ;
+ (UIImage *)UIImageFromIplImage:(IplImage *)image ;
+ (CGImageRef )CGImageFromIplImage:(IplImage *)image;

#pragma mark -
#pragma mark basic operations: resize 
+ (CGImageRef) resizeFromCGImage:(CGImageRef)cgImage toSize:(CGSize)newSize ;

#pragma mark -
#pragma mark special effects

+ (CGImageRef) opencvEdgeDetect:(CGImageRef)cgImage  ;

+ (CGImageRef) XRayEffect:(CGImageRef)cgImage ;

@end
