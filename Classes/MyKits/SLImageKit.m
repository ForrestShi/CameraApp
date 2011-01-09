//
//  SLImageKit.m
//  Camera+Timer
//
//  Created by forrest on 10-7-17.
//  Copyright 2010 WAVIS LLC. All rights reserved.
//

#import "SLImageKit.h"

@implementation SLImageKit

#pragma mark -
#pragma mark OpenCV Support Methods

// NOTE you SHOULD cvReleaseImage() for the return value when end of the code.
+ (IplImage *)CreateIplImageFromUIImage:(UIImage *)image {
	CGImageRef imageRef = image.CGImage;
	
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	IplImage *iplimage = cvCreateImage(cvSize(image.size.width, image.size.height), IPL_DEPTH_8U, 4);
	CGContextRef contextRef = CGBitmapContextCreate(iplimage->imageData, iplimage->width, iplimage->height,
													iplimage->depth, iplimage->widthStep,
													colorSpace, kCGImageAlphaPremultipliedLast|kCGBitmapByteOrderDefault);
	CGContextDrawImage(contextRef, CGRectMake(0, 0, image.size.width, image.size.height), imageRef);
	CGContextRelease(contextRef);
	CGColorSpaceRelease(colorSpace);
	
	IplImage *ret = cvCreateImage(cvGetSize(iplimage), IPL_DEPTH_8U, 3);
	cvCvtColor(iplimage, ret, CV_RGBA2BGR);
	cvReleaseImage(&iplimage);
	
	return ret;
}

+ (IplImage *)CreateIplImageFromCGImage:(CGImageRef)image {
	CGImageRef imageRef = image;
	int width = CGImageGetWidth(image);
	int height = CGImageGetHeight(image);
	
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	IplImage *iplimage = cvCreateImage(cvSize(width, height), IPL_DEPTH_8U, 4);
	CGContextRef contextRef = CGBitmapContextCreate(iplimage->imageData, iplimage->width, iplimage->height,
													iplimage->depth, iplimage->widthStep,
													colorSpace, kCGImageAlphaPremultipliedLast|kCGBitmapByteOrderDefault);
	CGContextDrawImage(contextRef, CGRectMake(0, 0, width, height), imageRef);
	CGContextRelease(contextRef);
	CGColorSpaceRelease(colorSpace);
	
	return iplimage;
}


// NOTE You should convert color mode as RGB before passing to this function
+ (UIImage *)UIImageFromIplImage:(IplImage *)image {
#ifdef DEBUG
	NSLog(@"IplImage (%d, %d) %d bits by %d channels, %d bytes/row %s", image->width, image->height, image->depth, image->nChannels, image->widthStep, image->channelSeq);
#endif
	
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	NSData *data = [NSData dataWithBytes:image->imageData length:image->imageSize];
	CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)data);
	CGImageRef imageRef = CGImageCreate(image->width, image->height,
										image->depth, image->depth * image->nChannels, image->widthStep,
										colorSpace, kCGImageAlphaNone|kCGBitmapByteOrderDefault,
										provider, NULL, false, kCGRenderingIntentDefault);
	UIImage *ret = [UIImage imageWithCGImage:imageRef];
	CGImageRelease(imageRef);
	CGDataProviderRelease(provider);
	CGColorSpaceRelease(colorSpace);
	return ret;
}

+ (CGImageRef)CGImageFromIplImage:(IplImage *)image {
#ifdef DEBUG
	NSLog(@"IplImage (%d, %d) %d bits by %d channels, %d bytes/row %s", image->width, image->height, image->depth, image->nChannels, image->widthStep, image->channelSeq);
#endif	
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	NSData *data = [NSData dataWithBytes:image->imageData length:image->imageSize];
	CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)data);
	CGImageRef imageRef = CGImageCreate(image->width, image->height,
										image->depth, image->depth * image->nChannels, image->widthStep,
										colorSpace, kCGImageAlphaNone|kCGBitmapByteOrderDefault,
										provider, NULL, false, kCGRenderingIntentDefault);
	
	return imageRef;
}

#pragma mark resize 

+ (CGImageRef) resizeFromCGImage:(CGImageRef)cgImage toSize:(CGSize)newSize {
	
	IplImage* iplImg = [SLImageKit CreateIplImageFromCGImage:cgImage];
	IplImage* newImg = cvCreateImage(cvSize(newSize.width, newSize.height), iplImg->depth, iplImg->nChannels);
	cvResize(iplImg, newImg, CV_INTER_LINEAR);
	
	CGImageRef	newCGImg = [SLImageKit CGImageFromIplImage:newImg];
	cvReleaseImage(&newImg);
	cvReleaseImage(&iplImg);
	
	return newCGImg;

}

/*
 @ need optimize for memory 
 */
+ (CGImageRef) opencvEdgeDetect:(CGImageRef)cgImage {
	
		cvSetErrMode(CV_ErrModeParent);
		
		// Create grayscale IplImage from UIImage
		IplImage *img_color = [SLImageKit CreateIplImageFromCGImage:cgImage];
		IplImage *img = cvCreateImage(cvGetSize(img_color), IPL_DEPTH_8U, 1);
		cvCvtColor(img_color, img, CV_BGR2GRAY);
		cvReleaseImage(&img_color);
		
		// Detect edge
		IplImage *img2 = cvCreateImage(cvGetSize(img), IPL_DEPTH_8U, 1);
		cvCanny(img, img2, 64, 128, 3);
		cvReleaseImage(&img);
		
		// Convert black and whilte to 24bit image then convert to UIImage to show
		IplImage *image = cvCreateImage(cvGetSize(img2), IPL_DEPTH_8U, 3);
		for(int y=0; y<img2->height; y++) {
			for(int x=0; x<img2->width; x++) {
				char *p = image->imageData + y * image->widthStep + x * 3;
				*p = *(p+1) = *(p+2) = img2->imageData[y * img2->widthStep + x];
			}
		}
		cvReleaseImage(&img2);
		
		CGImageRef	newCGImg = [SLImageKit CGImageFromIplImage:image];
		cvReleaseImage(&image);
		return newCGImg;
}



+ (CGImageRef) XRayEffect:(CGImageRef)cgImage {
	
	cvSetErrMode(CV_ErrModeParent);
	
	// Create grayscale IplImage from UIImage
	IplImage *img_color = [SLImageKit CreateIplImageFromCGImage:cgImage];
	IplImage *img = cvCreateImage(cvGetSize(img_color), IPL_DEPTH_8U, 4);
	
	cvNot(img_color, img);
	CGImageRef	newCGImg = [SLImageKit CGImageFromIplImage:img];
	
	cvReleaseImage(&img_color);
	cvReleaseImage(&img);
	
	return newCGImg;
}
@end
