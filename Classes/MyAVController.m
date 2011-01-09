#import "MyAVController.h"
#import "SettingViewController.h"
#import "SettingData.h"
#import "SLImageKit.h"

@implementation MyAVController

@synthesize captureSession = _captureSession;
@synthesize imageView = _imageView;
@synthesize customLayer = _customLayer;
@synthesize prevLayer = _prevLayer;
@synthesize captureTimer;
@synthesize counter;
@synthesize startButton;
@synthesize settingButton;
@synthesize aboutButton;
@synthesize parameter;
@synthesize imageData ;
@synthesize pSrcImage;
@synthesize pDstImage;

#pragma mark -
#pragma mark Initialization
- (id)init {
	self = [super init];
	if (self) {
		/*We initialize some variables (they might be not initialized depending on what is commented or not)*/
		self.imageView = nil;
		self.prevLayer = nil;
		self.customLayer = nil;
		self.captureTimer = nil;
		self.settingButton = nil;
		self.startButton = nil;
		self.aboutButton = nil;
		
		parameter = [[SettingData alloc] init];
		self.pSrcImage = nil;
		self.pDstImage = nil;
		
		//sound 
		NSURL *url = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"Tink" ofType:@"aiff"] isDirectory:NO];
		AudioServicesCreateSystemSoundID((CFURLRef)url, &timerSoundID);
		[url release];
		
		NSURL *url1= [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"photoShutter" ofType:@"caf"] isDirectory:NO];
		AudioServicesCreateSystemSoundID((CFURLRef)url1, &shutterSoundID);
		[url1 release];
		
		[UIApplication sharedApplication].statusBarStyle = UIStatusBarStyleBlackTranslucent;
		
		self.view.backgroundColor = [UIColor clearColor];
		
	}
	return self;
}


- (void)dealloc {
	[self.captureSession release];
	[self.imageView release];
	[self.prevLayer release];
	[self.customLayer release];
	[self.startButton release];
	[self.settingButton release];
	[self.aboutButton release];
	if (self.pSrcImage != nil) {
		cvRelease(&pSrcImage);
	}
	if (self.pDstImage != nil) {
		cvRelease(&pDstImage);
	}
	AudioServicesDisposeSystemSoundID(timerSoundID);
	AudioServicesDisposeSystemSoundID(shutterSoundID);
	
    [super dealloc];
}


- (void)viewDidLoad {
	/*We intialize the capture*/
	[self initCapture];
}

- (void)initCapture {
	/*We setup the input*/
	AVCaptureDeviceInput *captureInput = [AVCaptureDeviceInput 
										  deviceInputWithDevice:[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo] 
										  error:nil];
	/*We setupt the output*/
	AVCaptureVideoDataOutput *captureOutput = [[AVCaptureVideoDataOutput alloc] init];
	/*While a frame is processes in -captureOutput:didOutputSampleBuffer:fromConnection: delegate methods no other frames are added in the queue.
	 If you don't want this behaviour set the property to NO */
	captureOutput.alwaysDiscardsLateVideoFrames = YES; 
	/*We specify a minimum duration for each frame (play with this settings to avoid having too many frames waiting
	 in the queue because it can cause memory issues). It is similar to the inverse of the maximum framerate.
	 In this example we set a min frame duration of 1/10 seconds so a maximum framerate of 10fps. We say that
	 we are not able to process more than 10 frames per second.*/
	//captureOutput.minFrameDuration = CMTimeMake(1, 10);
	
	/*We create a serial queue to handle the processing of our frames*/
	dispatch_queue_t queue;
	queue = dispatch_queue_create("cameraQueue", NULL);
	[captureOutput setSampleBufferDelegate:self queue:queue];
	dispatch_release(queue);
	// Set the video output to store frame in BGRA (It is supposed to be faster)
	NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey; 
	NSNumber* value = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA]; 
	NSDictionary* videoSettings = [NSDictionary dictionaryWithObject:value forKey:key]; 
	[captureOutput setVideoSettings:videoSettings]; 
	/*And we create a capture session*/
	self.captureSession = [[AVCaptureSession alloc] init];
	/*We add input and output*/
	[self.captureSession addInput:captureInput];
	[self.captureSession addOutput:captureOutput];
	/*We add the Custom Layer (We need to change the orientation of the layer so that the video is displayed correctly)*/
//	self.customLayer = [CALayer layer];
//	self.customLayer.frame = self.view.bounds;
//	self.customLayer.transform = CATransform3DRotate(CATransform3DIdentity, M_PI/2.0f, 0, 0, 1);
//	self.customLayer.contentsGravity = kCAGravityResizeAspectFill;
//	[self.view.layer addSublayer:self.customLayer];
	
	/*We add the preview layer*/
//	self.prevLayer = [AVCaptureVideoPreviewLayer layerWithSession: self.captureSession];
//	self.prevLayer.frame = self.view.bounds;// CGRectMake(100, 0, 100, 100);
//	self.prevLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
//	[self.view.layer addSublayer: self.prevLayer];
	
	/*We add the imageView*/
	self.imageView = [[UIImageView alloc] init];
	self.imageView.frame = self.view.bounds; // CGRectMake(0, 0, 32*2,48*2 ); 
	[self.view addSubview:self.imageView];
	
	
	/*We start the capture*/
	[self.captureSession startRunning];
	
	//button
	[self createAboutButton];
	[self createStartButton];
	[self createSettingButton];	
	counter= 1; 
}

#pragma mark -
#pragma mark button event handler

- (void) createStartButton {
	if (startButton == nil) {
		startButton = [[UIButton alloc] init];
		startButton.frame= CGRectMake(160 - 32, 400, 64, 64);
		
		UIImage* image = [UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"start.png" ofType:nil]];
		if (image == nil) {
			startButton.backgroundColor = [UIColor redColor];
		}else{
			[startButton setBackgroundImage:image forState:UIControlEventAllEvents];
			[startButton setBackgroundImage:image forState:UIControlStateNormal];
			
		}
		
		startButton.opaque = YES;
		startButton.backgroundColor = [UIColor clearColor];
		startButton.alpha = 0.8;
		
		[startButton addTarget:self action:@selector(onClickStartButton:) forControlEvents:UIControlEventTouchDown];
		[self.view addSubview:startButton];
	}
}

- (void) createSettingButton {
	if (settingButton == nil) {
		settingButton = [[UIButton alloc] init];
		settingButton.frame= CGRectMake(38, 400, 64, 64);
		
		
		UIImage* image = [UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"Setting.png" ofType:nil]];
		if (image == nil) {
			settingButton.backgroundColor = [UIColor redColor];
		}else{
			[settingButton setBackgroundImage:image forState:UIControlEventAllEvents];
			[settingButton setBackgroundImage:image forState:UIControlStateNormal];
			
		}
		
		settingButton.opaque = YES;
		settingButton.alpha = 0.8;
		settingButton.backgroundColor = [UIColor clearColor];
		
		[settingButton addTarget:self action:@selector(onClickSettingButton:) forControlEvents:UIControlEventTouchDown];
		[self.view addSubview:settingButton];
	}
}

- (void) createAboutButton {
	if (aboutButton == nil) {
		aboutButton = [[UIButton alloc] init];
		aboutButton.frame= CGRectMake(218, 400, 64, 64);
		
		UIImage* image = [UIImage imageWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"film.png" ofType:nil]];
		if (image == nil) {
			aboutButton.backgroundColor = [UIColor redColor];
		}else{
			[aboutButton setBackgroundImage:image forState:UIControlEventAllEvents];
			[aboutButton setBackgroundImage:image forState:UIControlStateNormal];
			
		}
		
		aboutButton.opaque = YES;
		aboutButton.alpha = 0.8;
		
		[aboutButton addTarget:self action:@selector(onClickAboutButton:) forControlEvents:UIControlEventTouchDown];
		[self.view addSubview:aboutButton];
	}
}


- (void) onClickStartButton:(id)sender{
#ifdef DEBUG 
	NSLog(@"%s",_FUCNTION_);
#endif
	//
	NSInteger intervals = self.parameter.intervelSeconds;
	counter = 1;
	//start timer
	captureTimer = [NSTimer scheduledTimerWithTimeInterval:intervals target:self selector:@selector(captureImage) userInfo:nil repeats:YES];
	
	[UIView beginAnimations:@"start capture" context:nil];
	[UIView setAnimationDuration:1];
	[UIView setAnimationBeginsFromCurrentState:YES];
	
	startButton.alpha = 0;
	settingButton.alpha = 0;
	aboutButton.alpha = 0;
	[UIView commitAnimations];
	
	[startButton setEnabled:FALSE];	
	[aboutButton setEnabled:FALSE];
	[settingButton setEnabled:FALSE];
	
}

- (void) onClickSettingButton:(id)sender{
#ifdef DEBUG 
	NSLog(@"%s",_FUCNTION_);
#endif
	//
	SettingViewController* viewController = [[SettingViewController alloc] initWithData: parameter];

	viewController.delegate = self;
	
	[self presentModalViewController:viewController animated:YES];

	[viewController release];
}

- (void) onClickAboutButton:(id)sender{
#ifdef DEBUG 
	NSLog(@"%s",_FUCNTION_);
#endif
	//
	
	// Create image picker controller
	UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
	
	// Set source to the camera
	imagePicker.sourceType =  UIImagePickerControllerSourceTypeSavedPhotosAlbum;	
	// Delegate is self
	imagePicker.delegate = self;
	
	// Allow editing of image ?
	//imagePicker.allowsImageEditing = YES;
	imagePicker.allowsEditing = YES;
	
	// Show image picker
	[self presentModalViewController:imagePicker animated:YES];
	
	[imagePicker release];

}

#pragma mark UIImagePickerControllerDelegate

//- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
//{
//#ifdef DEBUG 
//	NSLog(@"%s",_FUCNTION_);
//#endif
//	//
//	// newImage is a UIImage do not try to use a UIImageView
//	UIImage* newImage = [info objectForKey:@"UIImagePickerControllerOriginalImage"];
//	// Dismiss UIImagePickerController and release it
//	[picker dismissModalViewControllerAnimated:YES];
//	[picker.view removeFromSuperview];
//	[picker	release];
//	UIImageView* newImgView = [[UIImageView alloc] initWithImage:newImage];
//	[self.view addSubview:newImgView ];
//}
//
//- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker{
//#ifdef DEBUG 
//	NSLog(@"%s",_FUCNTION_);
//#endif
//	//
//}



#pragma mark -
#pragma mark SettingDelegate

- (void) ChangesApplied{
	[self.parameter dumpData];
	[self dismissModalViewControllerAnimated:YES];
	
	//start capture 
	[self onClickStartButton:nil];
}

#pragma mark -
#pragma mark capture timer action 

- (void) beep{
	BOOL audio	= self.parameter.audioFlag;
	if (audio == TRUE) {
		AudioServicesPlaySystemSound(timerSoundID);
	}
	
}


- (void) captureImage{
	// NSAutoreleasePool* mainpool = [[NSAutoreleasePool alloc] init];

	NSInteger totoalShots = self.parameter.shotTimes;
	BOOL audio	= self.parameter.audioFlag;
	BOOL color = self.parameter.colorFlag;
	
	if (self.imageView.image) {
		NSLog(@"capture .... %d" , counter);
		NSLog(@"image width %f  %f \n", [self.imageView.image size].width,self.imageView.image.size.height);
		
		if (counter > totoalShots) {
			
			[captureTimer invalidate];
			captureTimer = nil;
			
			[UIView beginAnimations:@"start capture" context:nil];
			[UIView setAnimationDuration:1];
			[UIView setAnimationBeginsFromCurrentState:YES];
			
			startButton.alpha = 1;
			settingButton.alpha = 1;
			aboutButton.alpha = 1;
			[UIView commitAnimations];
			
			[startButton setEnabled:TRUE];	
			[aboutButton setEnabled:TRUE];
			[settingButton setEnabled:TRUE];
			
		}else {
			//NSLog(@"save ....");
			
			if (audio) {
				AudioServicesPlaySystemSound(shutterSoundID);
			}
					
			if (color) {
				CGImageRef currentImg = self.imageView.image.CGImage;
				CGImageRef resultImg = [self processCurrentFrame:currentImg];
				UIImage* saveImg = [UIImage imageWithCGImage:resultImg];
				CGImageRelease(resultImg);
				UIImageWriteToSavedPhotosAlbum(saveImg, nil, nil, nil);
				
			}else {
				
				UIImageWriteToSavedPhotosAlbum(self.imageView.image, nil, nil, nil);
			}

			counter = counter + 1;
			
		}
	}
	
	//[mainpool release];
}
	 
	 

#pragma mark -
#pragma mark AVCaptureSession delegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput 
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer 
	   fromConnection:(AVCaptureConnection *)connection 
{ 
	/*We create an autorelease pool because as we are not in the main_queue our code is
	 not executed in the main thread. So we have to create an autorelease pool for the thread we are in*/
	
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer); 
    /*Lock the image buffer*/
    CVPixelBufferLockBaseAddress(imageBuffer,0); 
    /*Get information about the image*/
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer); 
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer); 
    size_t width = CVPixelBufferGetWidth(imageBuffer); 
    size_t height = CVPixelBufferGetHeight(imageBuffer);  
    
    /*Create a CGImageRef from the CVImageBufferRef*/
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB(); 
    CGContextRef newContext = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGImageRef newImage = CGBitmapContextCreateImage(newContext); 
	
    /*We release some components*/
    CGContextRelease(newContext); 
    CGColorSpaceRelease(colorSpace);
    
    /*We display the result on the custom layer. All the display stuff must be done in the main thread because
	 UIKit is no thread safe, and as we are not in the main thread (remember we didn't use the main_queue)
	 we use performSelectorOnMainThread to call our CALayer and tell it to display the CGImage.*/
	//[self.customLayer performSelectorOnMainThread:@selector(setContents:) withObject: (id) self.imageData waitUntilDone:YES];
	
	
	/* do some processing */
	
	//CGImageRef newImage = [self processCurrentFrame:self.imageData]; 
	
	/*We display the result on the image view (We need to change the orientation of the image so that the video is displayed correctly).
	 Same thing as for the CALayer we are not in the main thread so ...*/
	
	UIImage *image= [UIImage imageWithCGImage:newImage scale:1.0 orientation:UIImageOrientationRight];
	
	/*We relase the CGImageRef*/
	//CGImageRelease(self.imageData);
	CGImageRelease(newImage);
	
	
	[self.imageView performSelectorOnMainThread:@selector(setImage:) withObject:image waitUntilDone:YES];
	
	/*We unlock the  image buffer*/
	CVPixelBufferUnlockBaseAddress(imageBuffer,0);
	
	[pool drain];
} 


- (CGImageRef) processCurrentFrame:(CGImageRef)currentFrame{
	
	//init pSrcImage from currentFrame 
	//create pDstImage 
	
	int width = CGImageGetWidth(currentFrame);
	int height = CGImageGetHeight(currentFrame);
	
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	if (self.pSrcImage == nil ) {
		self.pSrcImage = cvCreateImage(cvSize(width, height), IPL_DEPTH_8U, 4);
		self.pDstImage = cvCreateImage(cvSize(width, height), IPL_DEPTH_8U, 4);
	}
	
	CGContextRef contextRef = CGBitmapContextCreate(self.pSrcImage->imageData, self.pSrcImage->width, self.pSrcImage->height,
													self.pSrcImage->depth, self.pSrcImage->widthStep,
													colorSpace, kCGImageAlphaPremultipliedLast|kCGBitmapByteOrderDefault);
	CGContextDrawImage(contextRef, CGRectMake(0, 0, width, height), currentFrame);
	
	
	
	//process with OpenCV API 
	
	cvNot(self.pSrcImage, self.pDstImage);
	
	//
	
	NSData *data = [NSData dataWithBytes:self.pDstImage->imageData length:self.pDstImage->imageSize];
	CGDataProviderRef provider = CGDataProviderCreateWithCFData((CFDataRef)data);
	CGImageRef imageRef = CGImageCreate(self.pDstImage->width, self.pDstImage->height,
										self.pDstImage->depth, self.pDstImage->depth * self.pDstImage->nChannels, self.pDstImage->widthStep,
										colorSpace, kCGImageAlphaNone|kCGBitmapByteOrderDefault,
										provider, NULL, false, kCGRenderingIntentDefault);
	
	
	CGContextRelease(contextRef);
	CGColorSpaceRelease(colorSpace);
	
	return imageRef;
	
	
}

#pragma mark -
#pragma mark Memory management

- (void)viewDidUnload {
	self.imageView = nil;
	self.customLayer = nil;
	self.prevLayer = nil;
}



@end