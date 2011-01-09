#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CoreMedia.h>
#import <AudioToolbox/AudioToolbox.h>

#import <opencv/cv.h>

#import "SettingViewController.h"


/*!
 @class	AVController 
 @author Benjamin Loulier
 
 @brief    Controller to demonstrate how we can have a direct access to the camera using the iPhone SDK 4
 */
@interface MyAVController : UIViewController <AVCaptureVideoDataOutputSampleBufferDelegate,
												SettingDelegate,
												UIImagePickerControllerDelegate> {
	
	AVCaptureSession *_captureSession;
	UIImageView *_imageView;
	CALayer *_customLayer;
	AVCaptureVideoPreviewLayer *_prevLayer;
	CGImageRef imageData;
	
	//timer
	NSTimer* captureTimer;
	NSInteger counter;
	
	
	// UI components
	UIButton* startButton;
	UIButton* settingButton;
	UIButton* aboutButton;
	
	//Data
	SettingData* parameter;
	
    //OpenCV Image Data
	IplImage* pSrcImage;	
	IplImage* pDstImage;
	
	SystemSoundID timerSoundID;
	SystemSoundID shutterSoundID;

}

/*!
 @brief	The capture session takes the input from the camera and capture it
 */
@property (nonatomic, retain) AVCaptureSession *captureSession;

/*!
 @brief	The UIImageView we use to display the image generated from the imageBuffer
 */
@property (nonatomic, retain) UIImageView *imageView;
/*!
 @brief	The CALayer we use to display the CGImageRef generated from the imageBuffer
 */
@property (nonatomic, retain) CALayer *customLayer;
/*!
 @brief	The CALAyer customized by apple to display the video corresponding to a capture session
 */
@property (nonatomic, retain) AVCaptureVideoPreviewLayer *prevLayer;

/*
 @ pointer to image data of current frame, used for further processing 
 */
@property (nonatomic, assign) CGImageRef imageData;

@property (nonatomic, assign) IplImage* pSrcImage;	
@property (nonatomic, assign) IplImage* pDstImage;

@property (nonatomic, retain) NSTimer* captureTimer;
@property (nonatomic, assign) NSInteger counter;
@property (nonatomic, retain) UIButton* startButton;
@property (nonatomic, retain) UIButton* settingButton;
@property (nonatomic, retain) UIButton* aboutButton;

/*
 @
 */
@property (nonatomic, retain) SettingData* parameter;

/*!
 @brief	This method initializes the capture session
 */
- (void)initCapture;

- (void) createStartButton;

- (CGImageRef) processCurrentFrame:(CGImageRef)currentFrame;

@end