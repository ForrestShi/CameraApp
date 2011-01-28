/*
     File: AVCamCaptureManager.m
 Abstract: Code that calls the AVCapture classes to implement the camera-specific features in the app such as recording, still image, camera exposure, white balance and so on.
  Version: 1.0
  
 */

#import "AVCamCaptureManager.h"
#import <MobileCoreServices/UTCoreTypes.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "SLImageKit.h"


enum
{
	kOneShot,       // user wants to take a delayed single shot
	kRepeatingShot  // user wants to take repeating shots
};


@interface AVCamCaptureManager (AVCaptureFileOutputRecordingDelegate) <AVCaptureFileOutputRecordingDelegate>
@end

@interface AVCamCaptureManager ()

@property (nonatomic,retain) AVCaptureSession *session;
@property (nonatomic,retain) AVCaptureDeviceInput *videoInput;
@property (nonatomic,retain) AVCaptureDeviceInput *audioInput;
@property (nonatomic,retain) AVCaptureMovieFileOutput *movieFileOutput;
@property (nonatomic,retain) AVCaptureStillImageOutput *stillImageOutput;
@property (nonatomic,retain) AVCaptureVideoDataOutput *videoDataOutput;
@property (nonatomic,retain) id deviceConnectedObserver;
@property (nonatomic,retain) id deviceDisconnectedObserver;
@property (nonatomic,assign) UIBackgroundTaskIdentifier backgroundRecordingID;

@end

@interface AVCamCaptureManager (Internal)

- (AVCaptureDevice *) cameraWithPosition:(AVCaptureDevicePosition)position;
- (AVCaptureDevice *) frontFacingCamera;
- (AVCaptureDevice *) backFacingCamera;
- (AVCaptureDevice *) audioDevice;
- (NSURL *) tempFileURL;

@end

@implementation AVCamCaptureManager

@synthesize session = _session;
@synthesize orientation = _orientation;
@dynamic audioChannel;
@dynamic sessionPreset;
@synthesize mirroringMode = _mirroringMode;
@synthesize videoInput = _videoInput;
@synthesize audioInput = _audioInput;
@dynamic flashMode;
@dynamic torchMode;
@dynamic focusMode;
@dynamic exposureMode;
@dynamic whiteBalanceMode;
@synthesize movieFileOutput = _movieFileOutput;
@synthesize stillImageOutput = _stillImageOutput;
@synthesize videoDataOutput = _videoDataOutput;
@synthesize deviceConnectedObserver = _deviceConnectedObserver;
@synthesize deviceDisconnectedObserver = _deviceDisconnectedObserver;
@synthesize backgroundRecordingID = _backgroundRecordingID;
@synthesize delegate = _delegate;
@dynamic recording;
@synthesize pSrcImage,pDstImage;
@synthesize previewImageDelegate = _previewImageDelegate;
@synthesize  panoImageArray=_panoImageArray;
@synthesize  calibratedSubImage = _calibratedSubImage;
@synthesize timerSecPerShot,tickTimer, cameraTimer;


- (id) init
{
    self = [super init];
    if (self != nil) {
        void (^deviceConnectedBlock)(NSNotification *) = ^(NSNotification *notification) {
			NSLog(@"deviceConnectedBlock");
            AVCaptureSession *session = [self session];
            AVCaptureDeviceInput *newAudioInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self audioDevice] error:nil];
            AVCaptureDeviceInput *newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self backFacingCamera] error:nil];
            
            [session beginConfiguration];
            [session removeInput:[self audioInput]];
            if ([session canAddInput:newAudioInput]) {                
                [session addInput:newAudioInput];
            }
            [session removeInput:[self videoInput]];
            if ([session canAddInput:newVideoInput]) {
                [session addInput:newVideoInput];
            }
            [session commitConfiguration];
            
            [self setAudioInput:newAudioInput];
            [newAudioInput release];
            [self setVideoInput:newVideoInput];
            [newVideoInput release];
            
            id delegate = [self delegate];
            if ([delegate respondsToSelector:@selector(deviceCountChanged)]) {
                [delegate deviceCountChanged];
            }
            
            if (![session isRunning])
                [session startRunning];
        };
        void (^deviceDisconnectedBlock)(NSNotification *) = ^(NSNotification *notification) {
			NSLog(@"deviceDisconnectedBlock");
            AVCaptureSession *session = [self session];
            
            [session beginConfiguration];
            
            if (![[[self audioInput] device] isConnected])
                [session removeInput:[self audioInput]];
            if (![[[self videoInput] device] isConnected])
                [session removeInput:[self videoInput]];
                
            [session commitConfiguration];
            
            [self setAudioInput:nil];
            
            id delegate = [self delegate];
            if ([delegate respondsToSelector:@selector(deviceCountChanged)]) {
                [delegate deviceCountChanged];
            }
            
            if (![session isRunning])
                [session startRunning];
        };
        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        [self setDeviceConnectedObserver:[notificationCenter addObserverForName:AVCaptureDeviceWasConnectedNotification object:nil queue:nil usingBlock:deviceConnectedBlock]];
        [self setDeviceDisconnectedObserver:[notificationCenter addObserverForName:AVCaptureDeviceWasDisconnectedNotification object:nil queue:nil usingBlock:deviceDisconnectedBlock]];            
  
	
		AudioServicesCreateSystemSoundID((CFURLRef)[NSURL fileURLWithPath:
                                                    [[NSBundle mainBundle] pathForResource:@"tick"
                                                                                    ofType:@"aiff"]],
                                         &tickSound);

		
	}
    return self;
}


- (void) dealloc
{
	AudioServicesDisposeSystemSoundID(tickSound);
	[cameraTimer release];
    [tickTimer release];
	
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:[self deviceConnectedObserver]];
    [notificationCenter removeObserver:[self deviceDisconnectedObserver]];
    [self setDeviceConnectedObserver:nil];
    [self setDeviceDisconnectedObserver:nil];

    [[self session] stopRunning];
    [self setSession:nil];
    [self setVideoInput:nil];
    [self setAudioInput:nil];
    [self setMovieFileOutput:nil];
    [self setStillImageOutput:nil];
	[self setVideoDataOutput:nil];
    [super dealloc];
}

-(void) setCalibratedSubImage:(IplImage*)newIpl{
	if (newIpl !=  _calibratedSubImage) {
		cvRelease(&_calibratedSubImage);
		_calibratedSubImage = newIpl;
	}
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
	//CGLayerRef layerRef = CGLayerCreateWithContext(newContext, CGSizeMake(width, height), NULL);
    /*We release some components*/
    CGContextRelease(newContext); 
    CGColorSpaceRelease(colorSpace);
    
	/* do some processing */
	
	NSLog(@"timer secs %d", timerSecPerShot);
	//NSLog(@"timer slient %d",timerSlient);
	
	
	//CGImageRef newImageProecessed = [self processCurrentFrame:newImage]; 
	//CGImageRef newImageProecessed = [self extractCalibratedImageFromOriginalImage:layerRef];
	//UIImage*	newImageProecessed = [self opencvFaceDetect:[UIImage imageWithCGImage:newImage]];
	BOOL detectFace = [self opencvFaceDetect:[UIImage imageWithCGImage:newImage]];
	//if ([_previewImageDelegate respondsToSelector:@selector(configureNewPreviewImage:)] && newImageProecessed != nil) {
	if (detectFace) {
		
		NSLog(@"set up faces ");
		//[_previewImageDelegate configureNewPreviewImage: newImageProecessed.CGImage];
		UIImageWriteToSavedPhotosAlbum([UIImage imageWithCGImage:newImage], nil, nil, nil);
										
	}
	CGImageRelease(newImage);
	//CGLayerRelease(layerRef);
	//CGImageRelease(newImageProecessed);
	/*We unlock the  image buffer*/
	CVPixelBufferUnlockBaseAddress(imageBuffer,0);
	
	[pool drain];
} 

- (CGImageRef) extractCalibratedImageFromOriginalImage:(CGLayerRef)currentFrame{
	int lWidth = CGImageGetWidth(currentFrame)/4;
	int lHeight = CGImageGetHeight(currentFrame);
	if (self->_calibratedSubImage == NULL) {
		_calibratedSubImage = cvCreateImage(cvSize(lWidth, lHeight), IPL_DEPTH_8U, 3);
	}
	
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	
	CGContextRef contextRef = CGBitmapContextCreate(_calibratedSubImage->imageData, lWidth, lHeight, _calibratedSubImage->depth,
														_calibratedSubImage->widthStep, colorSpace, 
													kCGImageAlphaPremultipliedLast|kCGBitmapByteOrderDefault);
	CGContextDrawLayerInRect(contextRef, CGRectMake(0, 0, lWidth, lHeight), currentFrame); // (contextRef, CGRectMake(0, 0, lWidth, lHeight), currentFrame);
	
	CGContextRelease(contextRef);
	CGColorSpaceRelease(colorSpace);
	return [SLImageKit CGImageFromIplImage:_calibratedSubImage];
}

- (BOOL) opencvFaceDetect:(UIImage *)faceImage  {
	if(faceImage) {
		cvSetErrMode(CV_ErrModeParent);
		
		IplImage *image = [SLImageKit CreateIplImageFromUIImage:faceImage];
		
		// Scaling down
		IplImage *small_image = cvCreateImage(cvSize(image->width/2,image->height/2), IPL_DEPTH_8U, 3);
		cvPyrDown(image, small_image, CV_GAUSSIAN_5x5);
		int scale = 2;
		
		// Load XML
		NSString *path = [[NSBundle mainBundle] pathForResource:@"haarcascade_frontalface_default" ofType:@"xml"];
		CvHaarClassifierCascade* cascade = (CvHaarClassifierCascade*)cvLoad([path cStringUsingEncoding:NSASCIIStringEncoding], NULL, NULL, NULL);
		CvMemStorage* storage = cvCreateMemStorage(0);
		
		// Detect faces and draw rectangle on them
		CvSeq* faces = cvHaarDetectObjects(small_image, cascade, storage, 1.2f, 2, CV_HAAR_DO_CANNY_PRUNING, cvSize(20, 20));
		cvReleaseImage(&small_image);
		
		// Create canvas to show the results
	//	CGImageRef imageRef = faceImage.CGImage;
//		CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
//		CGContextRef contextRef = CGBitmapContextCreate(NULL, faceImage.size.width, faceImage.size.height,
//														8, faceImage.size.width * 4,
//														colorSpace, kCGImageAlphaPremultipliedLast|kCGBitmapByteOrderDefault);
//		CGContextDrawImage(contextRef, CGRectMake(0, 0, faceImage.size.width, faceImage.size.height), imageRef);
//		
//		CGContextSetLineWidth(contextRef, 4);
//		CGContextSetRGBStrokeColor(contextRef, 0.0, 1.0, 1.0, 0.5);
//		CGRect face_rect,face_rect0;
//		UIImage* face = nil;
		BOOL returnValue = FALSE;
		// Draw results on the iamge
//		for(int i = 0; i < faces->total; i++) {
//			NSLog(@"detected face %d\n", faces->total );
//			NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
//			
//			// Calc the rect of faces
//			CvRect cvrect = *(CvRect*)cvGetSeqElem(faces, i);
//			face_rect0 = CGRectMake(cvrect.x * scale, cvrect.y * scale, cvrect.width * scale, cvrect.height * scale);
//			face_rect = CGContextConvertRectToDeviceSpace(contextRef, face_rect0);
//			
////			CGContextStrokeRect(contextRef, face_rect);
////			face = [UIImage imageWithCGImage: CGImageCreateWithImageInRect(imageRef, face_rect0)];	
////			UIImageWriteToSavedPhotosAlbum(face, nil, nil, nil);
//			returnValue = TRUE;
//			[pool release];
//		}
		
		if (faces->total > 0) {
			returnValue = TRUE;
		}
		
//		
//		
//		CGContextRelease(contextRef);
//		CGColorSpaceRelease(colorSpace);
		
		cvReleaseMemStorage(&storage);
		cvReleaseHaarClassifierCascade(&cascade);
		
		//[self hideProgressIndicator];
		return returnValue;//[face autorelease];
	}
}


- (CGImageRef) processCurrentFrame:(CGImageRef)currentFrame{
	
	//init pSrcImage from currentFrame 
	//create pDstImage 
	
	int width = CGImageGetWidth(currentFrame)/4;
	int height = CGImageGetHeight(currentFrame)/4;
	
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	if (self.pSrcImage == nil ) {
		NSLog(@"just call only one time ");
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



- (BOOL) setupSessionWithPreset:(NSString *)sessionPreset error:(NSError **)error
{
    BOOL success = NO;
    
    // Init the device inputs
    AVCaptureDeviceInput *videoInput = [[[AVCaptureDeviceInput alloc] initWithDevice:[self backFacingCamera] error:error] autorelease];
    [self setVideoInput:videoInput];
    
    AVCaptureDeviceInput *audioInput = [[[AVCaptureDeviceInput alloc] initWithDevice:[self audioDevice] error:error] autorelease];
    [self setAudioInput:audioInput];
    
    // Setup the default file outputs
    AVCaptureStillImageOutput *stillImageOutput = [[[AVCaptureStillImageOutput alloc] init] autorelease];
    NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:
                                    AVVideoCodecJPEG, AVVideoCodecKey,
                                    nil];
    [stillImageOutput setOutputSettings:outputSettings];
    [outputSettings release];
    [self setStillImageOutput:stillImageOutput];
    
    AVCaptureMovieFileOutput *movieFileOutput = [[AVCaptureMovieFileOutput alloc] init];
    [self setMovieFileOutput:movieFileOutput];
    [movieFileOutput release];

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
	[self setVideoDataOutput: captureOutput];
	[captureOutput release];
	
    
    // Add inputs and output to the capture session, set the preset, and start it running
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    
    if ([session canAddInput:videoInput]) {
        [session addInput:videoInput];
    }
    if ([session canAddInput:audioInput]) {
        [session addInput:audioInput];
    }
    if ([session canAddOutput:movieFileOutput]) {
        [session addOutput:movieFileOutput];
        [self setMirroringMode:AVCamMirroringAuto];
    }
    if ([session canAddOutput:stillImageOutput]) {
        [session addOutput:stillImageOutput];
    }
	// // issue when recording to file : AVErrorRecordingSuccessfullyFinishedKey=false
//    if ([session canAddOutput:captureOutput]) {
//		[session addOutput:captureOutput];
//	}
	
    [self setSessionPreset:sessionPreset];
    
    [self setSession:session];
    
    [session release];
    
    success = YES;
    
    id delegate = [self delegate];
    if ([delegate respondsToSelector:@selector(deviceCountChanged)]) {
        [delegate deviceCountChanged];
    }
    
    return success;
}

#pragma mark videoDataOutput
- (void) removeVideoDataOutput{
	AVCaptureSession *session = [self session];
	
	[session beginConfiguration];
	
	if (self.videoDataOutput ) {
		[session removeOutput:[self videoDataOutput]];
	}
	[session commitConfiguration];
}

- (void) addVideoDataOutput{
	AVCaptureSession *session = [self session];
	
	[session beginConfiguration];
	if (!self.videoDataOutput ) {
		[self createVideoDataOutput];
	}
	if ([session canAddOutput:self.videoDataOutput]) {
		[session addOutput:[self videoDataOutput]];
	}
	
	[session commitConfiguration];
}

- (void) createVideoDataOutput{
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
	[self setVideoDataOutput: captureOutput];
	[captureOutput release];
}


- (BOOL) isRecording
{
    return [[self movieFileOutput] isRecording];
}

- (void) startRecording
{
    if ([[UIDevice currentDevice] isMultitaskingSupported]) {
        [self setBackgroundRecordingID:[[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{}]];
    }
	[self removeVideoDataOutput];
	
    AVCaptureConnection *videoConnection = [AVCamCaptureManager connectionWithMediaType:AVMediaTypeVideo fromConnections:[[self movieFileOutput] connections]];
    if ([videoConnection isVideoOrientationSupported]) {
        [videoConnection setVideoOrientation:[self orientation]];
    }
    
    [[self movieFileOutput] startRecordingToOutputFileURL:[self tempFileURL]
                                        recordingDelegate:self];
	
}

- (void) stopRecording
{
    [[self movieFileOutput] stopRecording];
	//[self addVideoDataOutput];
}

- (void) captureStillImage
{
	AVCaptureConnection *videoConnection = [AVCamCaptureManager connectionWithMediaType:AVMediaTypeVideo fromConnections:[[self stillImageOutput] connections]];
	if ([videoConnection isVideoOrientationSupported]) {
		[videoConnection setVideoOrientation:[UIDevice currentDevice].orientation];
	}
	
	
    [[self stillImageOutput] captureStillImageAsynchronouslyFromConnection:videoConnection
                                                         completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
													
                                                             if (imageDataSampleBuffer != NULL) {
                                                                 NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                                                                 UIImage *image = [[UIImage alloc] initWithData:imageData];                                                                 
                                                                 ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
                                                                 [library writeImageToSavedPhotosAlbum:[image CGImage]
                                                                                           orientation:(ALAssetOrientation)[image imageOrientation]
                                                                                       completionBlock:^(NSURL *assetURL, NSError *error){
                                                                                           if (error) {
                                                                                               id delegate = [self delegate];
                                                                                               if ([delegate respondsToSelector:@selector(captureStillImageFailedWithError:)]) {
                                                                                                   [delegate captureStillImageFailedWithError:error];
                                                                                               }                                                                                               
                                                                                           }
                                                                                       }];
                                                                 [library release];
                                                                 [image release];
                                                             } else if (error) {
                                                                 id delegate = [self delegate];
                                                                 if ([delegate respondsToSelector:@selector(captureStillImageFailedWithError:)]) {
                                                                     [delegate captureStillImageFailedWithError:error];
                                                                 }
                                                             }
                                                         }];
}

#pragma mark Timer Camera 

// gets called by our delayed camera shot timer to play a tick noise
- (void)tickFire:(NSTimer *)timer
{
	AudioServicesPlaySystemSound(tickSound);
}

// gets called by our repettive timer to take a picture
- (void)timedPhotoFire:(NSTimer *)timer
{
    [self captureStillImage];
    
    NSInteger cameraAction = [self.cameraTimer.userInfo integerValue];
    switch (cameraAction)
    {
        case kOneShot:
        {
            // timer fired for a delayed single shot
            [self.cameraTimer invalidate];
            cameraTimer = nil;
            
            [self.tickTimer invalidate];
            tickTimer = nil;
            
            break;
        }
            
        case kRepeatingShot:
        {
            break;
        }
    }
}

// give at least 3 seconds due to reduce "busy" error 
- (NSInteger) timerSecPerShot
{
	if (timerSecPerShot < 3) {
		timerSecPerShot = 3;
	}
	return timerSecPerShot;
}

- (void)captureStillImageWithTimer
{
	id delegate = [self delegate];
	if ([delegate respondsToSelector:@selector(timerCaptureBegan)]) {
		[delegate timerCaptureBegan];
	}
	
    if (cameraTimer != nil){
        [cameraTimer invalidate];
		self.cameraTimer = nil;
	}
    cameraTimer = [NSTimer scheduledTimerWithTimeInterval:self.timerSecPerShot
                                                   target:self
                                                 selector:@selector(timedPhotoFire:)
                                                 userInfo:[NSNumber numberWithInt:kRepeatingShot]
                                                  repeats:YES];
	
    // start the timer to sound off a tick every 1 second (sound effect before a timed picture is taken)
    if (tickTimer != nil){
        [tickTimer invalidate];
		self.tickTimer = nil;
	}
    tickTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
												 target:self
											   selector:@selector(tickFire:)
											   userInfo:nil
												repeats:YES];
}

- (void) stopCaptureStillImageWithTimer
{
	id delegate = [self delegate];
	if ([delegate respondsToSelector:@selector(timerCaptureFinished)]) {
		[delegate timerCaptureFinished];
	}
	
	if (cameraTimer != nil) {
		[cameraTimer invalidate];
		cameraTimer = nil;
	}
	if (tickTimer != nil){
        [tickTimer invalidate];
		tickTimer = nil;
	}
}

- (BOOL) isCaptureStillImageWithTimer
{
	if (cameraTimer != nil && [cameraTimer isValid]) {
		return YES;
	}else {
		return NO;
	}
}


- (BOOL) hasMultiCamera
{
	return [self cameraCount]>1? YES:NO; 
}

- (int) cameraPosition
{
	AVCaptureDevicePosition position = [[[self videoInput] device] position];
	if (position == AVCaptureDevicePositionBack) {
		return 0;
	}else {
		return 1;
	}	
}

- (BOOL) cameraToggle
{
    BOOL success = NO;
    
    if ([self cameraCount] > 1) {
        NSError *error;
        AVCaptureDeviceInput *videoInput = [self videoInput];
        AVCaptureDeviceInput *newVideoInput;
        AVCaptureDevicePosition position = [[videoInput device] position];
        BOOL mirror;
        if (position == AVCaptureDevicePositionBack) {
            newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self frontFacingCamera] error:&error];
            switch ([self mirroringMode]) {
                case AVCamMirroringOff:
                    mirror = NO;
                    break;
                case AVCamMirroringOn:
                    mirror = YES;
                    break;
                case AVCamMirroringAuto:
                default:
                    mirror = NO;
                    break;
            }
        } else if (position == AVCaptureDevicePositionFront) {
            newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self backFacingCamera] error:&error];
            switch ([self mirroringMode]) {
                case AVCamMirroringOff:
                    mirror = NO;
                    break;
                case AVCamMirroringOn:
                    mirror = YES;
                    break;
                case AVCamMirroringAuto:
                default:
                    mirror = YES;
                    break;
            }
        } else {
            goto bail;
        }
        
        AVCaptureSession *session = [self session];
        if (newVideoInput != nil) {
            [session beginConfiguration];
            [session removeInput:videoInput];
            NSString *currentPreset = [session sessionPreset];
            if (![[newVideoInput device] supportsAVCaptureSessionPreset:currentPreset]) {
                [session setSessionPreset:AVCaptureSessionPresetHigh]; // default back to high, since this will always work regardless of the camera
            }
            if ([session canAddInput:newVideoInput]) {
                [session addInput:newVideoInput];
                AVCaptureConnection *connection = [AVCamCaptureManager connectionWithMediaType:AVMediaTypeVideo fromConnections:[[self movieFileOutput] connections]];
                if ([connection isVideoMirroringSupported]) {
                    [connection setVideoMirrored:mirror];
                }
                [self setVideoInput:newVideoInput];
            } else {
                [session setSessionPreset:currentPreset];
                [session addInput:videoInput];
            }
            [session commitConfiguration];
            success = YES;
            [newVideoInput release];
        } else if (error) {
            id delegate = [self delegate];
            if ([delegate respondsToSelector:@selector(someOtherError:)]) {
                [delegate someOtherError:error];
            }
        }
    }
    
bail:
    return success;
}

- (NSUInteger) cameraCount
{
    return [[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] count];
}

- (NSUInteger) micCount
{
    return [[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio] count];
}

- (BOOL) hasFlash
{
    return [[[self videoInput] device] hasFlash];
}

- (AVCaptureFlashMode) flashMode
{
    return [[[self videoInput] device] flashMode];
}

- (void) setFlashMode:(AVCaptureFlashMode)flashMode
{
    AVCaptureDevice *device = [[self videoInput] device];
    if ([device isFlashModeSupported:flashMode] && [device flashMode] != flashMode) {
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            [device setFlashMode:flashMode];
            [device unlockForConfiguration];
        } else {
            id delegate = [self delegate];
            if ([delegate respondsToSelector:@selector(acquiringDeviceLockFailedWithError:)]) {
                [delegate acquiringDeviceLockFailedWithError:error];
            }
        }    
    }
}

- (BOOL) hasTorch
{
    return [[[self videoInput] device] hasTorch];
}

- (AVCaptureTorchMode) torchMode
{
    return [[[self videoInput] device] torchMode];
}

- (void) setTorchMode:(AVCaptureTorchMode)torchMode
{
    AVCaptureDevice *device = [[self videoInput] device];
    if ([device isTorchModeSupported:torchMode] && [device torchMode] != torchMode) {
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            [device setTorchMode:torchMode];
            [device unlockForConfiguration];
        } else {
            id delegate = [self delegate];
            if ([delegate respondsToSelector:@selector(acquiringDeviceLockFailedWithError:)]) {
                [delegate acquiringDeviceLockFailedWithError:error];
            }
        }
    }
}

- (BOOL) hasFocus
{
    AVCaptureDevice *device = [[self videoInput] device];
    
    return  [device isFocusModeSupported:AVCaptureFocusModeLocked] ||
            [device isFocusModeSupported:AVCaptureFocusModeAutoFocus] ||
            [device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus];
}

- (AVCaptureFocusMode) focusMode
{
    return [[[self videoInput] device] focusMode];
}

- (void) setFocusMode:(AVCaptureFocusMode)focusMode
{
    AVCaptureDevice *device = [[self videoInput] device];
    if ([device isFocusModeSupported:focusMode] && [device focusMode] != focusMode) {
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            [device setFocusMode:focusMode];
            [device unlockForConfiguration];
        } else {
            id delegate = [self delegate];
            if ([delegate respondsToSelector:@selector(acquiringDeviceLockFailedWithError:)]) {
                [delegate acquiringDeviceLockFailedWithError:error];
            }
        }    
    }
}

- (BOOL) hasExposure
{
    AVCaptureDevice *device = [[self videoInput] device];
    
    return  [device isExposureModeSupported:AVCaptureExposureModeLocked] ||
            [device isExposureModeSupported:AVCaptureExposureModeAutoExpose] ||
            [device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure];
}

- (AVCaptureExposureMode) exposureMode
{
    return [[[self videoInput] device] exposureMode];
}

- (void) setExposureMode:(AVCaptureExposureMode)exposureMode
{
    if (exposureMode == 1) {
        exposureMode = 2;
    }
    AVCaptureDevice *device = [[self videoInput] device];
    if ([device isExposureModeSupported:exposureMode] && [device exposureMode] != exposureMode) {
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            [device setExposureMode:exposureMode];
            [device unlockForConfiguration];
        } else {
            id delegate = [self delegate];
            if ([delegate respondsToSelector:@selector(acquiringDeviceLockFailedWithError:)]) {
                [delegate acquiringDeviceLockFailedWithError:error];
            }
        }
    }
}

- (BOOL) hasWhiteBalance
{
    AVCaptureDevice *device = [[self videoInput] device];
    
    return  [device isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeLocked] ||
            [device isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeAutoWhiteBalance];
}

- (AVCaptureWhiteBalanceMode) whiteBalanceMode
{
    return [[[self videoInput] device] whiteBalanceMode];
}

- (void) setWhiteBalanceMode:(AVCaptureWhiteBalanceMode)whiteBalanceMode
{
    if (whiteBalanceMode == 1) {
        whiteBalanceMode = 2;
    }    
    AVCaptureDevice *device = [[self videoInput] device];
    if ([device isWhiteBalanceModeSupported:whiteBalanceMode] && [device whiteBalanceMode] != whiteBalanceMode) {
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            [device setWhiteBalanceMode:whiteBalanceMode];
            [device unlockForConfiguration];
        } else {
            id delegate = [self delegate];
            if ([delegate respondsToSelector:@selector(acquiringDeviceLockFailedWithError:)]) {
                [delegate acquiringDeviceLockFailedWithError:error];
            }
        }
    }
}

- (void) focusAtPoint:(CGPoint)point
{
    AVCaptureDevice *device = [[self videoInput] device];
    if ([device isFocusPointOfInterestSupported] && [device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            [device setFocusPointOfInterest:point];
            [device setFocusMode:AVCaptureFocusModeAutoFocus];
            [device unlockForConfiguration];
        } else {
            id delegate = [self delegate];
            if ([delegate respondsToSelector:@selector(acquiringDeviceLockFailedWithError:)]) {
                [delegate acquiringDeviceLockFailedWithError:error];
            }
        }        
    }
}

- (void) exposureAtPoint:(CGPoint)point
{
    AVCaptureDevice *device = [[self videoInput] device];
    if ([device isExposurePointOfInterestSupported] && [device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            [device setExposurePointOfInterest:point];
            [device setExposureMode:AVCaptureExposureModeContinuousAutoExposure];
            [device unlockForConfiguration];
        } else {
            id delegate = [self delegate];
            if ([delegate respondsToSelector:@selector(acquiringDeviceLockFailedWithError:)]) {
                [delegate acquiringDeviceLockFailedWithError:error];
            }
        }
    }    
}

- (NSString *) sessionPreset
{
    return [[self session] sessionPreset];
}

- (void) setSessionPreset:(NSString *)sessionPreset
{
    AVCaptureSession *session = [self session];
    if (![sessionPreset isEqualToString:[self sessionPreset]] && [session canSetSessionPreset:sessionPreset]) {
        [session beginConfiguration];
        [session setSessionPreset:sessionPreset];
        [session commitConfiguration];
    }
}

- (void) setConnectionWithMediaType:(NSString *)mediaType enabled:(BOOL)enabled;
{
    [[AVCamCaptureManager connectionWithMediaType:AVMediaTypeVideo fromConnections:[[self movieFileOutput] connections]] setEnabled:enabled];
}

- (void) setMirroringMode:(AVCamMirroringMode)mirroringMode
{
    AVCaptureSession *session = [self session];
    _mirroringMode = mirroringMode;
    AVCaptureConnection *fileConnection = [AVCamCaptureManager connectionWithMediaType:AVMediaTypeVideo fromConnections:[[self movieFileOutput] connections]];
    AVCaptureConnection *stillConnection = [AVCamCaptureManager connectionWithMediaType:AVMediaTypeVideo fromConnections:[[self stillImageOutput] connections]];
    [session beginConfiguration];
    switch (mirroringMode) {
        case AVCamMirroringOff:
            if ([fileConnection isVideoMirroringSupported]) {
                [fileConnection setVideoMirrored:NO];
            }
            if ([stillConnection isVideoMirroringSupported]) {
                [stillConnection setVideoMirrored:NO];
            }
            break;
        case AVCamMirroringOn:
            if ([fileConnection isVideoMirroringSupported]) {
                [fileConnection setVideoMirrored:YES];
            }
            if ([stillConnection isVideoMirroringSupported]) {
                [stillConnection setVideoMirrored:YES];
            }
            break;
        case AVCamMirroringAuto:
        {
            BOOL mirror = NO;
            AVCaptureDevicePosition position = [[[self videoInput] device] position];
            if (position == AVCaptureDevicePositionBack) {
                mirror = NO;
            } else if (position == AVCaptureDevicePositionFront) {
                mirror = YES;
            }
            if ([fileConnection isVideoMirroringSupported]) {
                [fileConnection setVideoMirrored:mirror];
            }
            if ([stillConnection isVideoMirroringSupported]) {
                [stillConnection setVideoMirrored:mirror];
            }
        }
            break;
    }
    [session commitConfiguration];
}

- (BOOL) supportsMirroring
{
    return [[AVCamCaptureManager connectionWithMediaType:AVMediaTypeVideo fromConnections:[[self movieFileOutput] connections]] isVideoMirroringSupported] ||
            [[AVCamCaptureManager connectionWithMediaType:AVMediaTypeVideo fromConnections:[[self stillImageOutput] connections]] isVideoMirroringSupported];
}

- (BOOL) supportsTimer{
	return YES;
}

- (AVCaptureAudioChannel *)audioChannel
{
    return [[[AVCamCaptureManager connectionWithMediaType:AVMediaTypeAudio fromConnections:[[self movieFileOutput] connections]] audioChannels] lastObject];
}

+ (AVCaptureConnection *)connectionWithMediaType:(NSString *)mediaType fromConnections:(NSArray *)connections;
{
	for ( AVCaptureConnection *connection in connections ) {
		for ( AVCaptureInputPort *port in [connection inputPorts] ) {
			if ( [[port mediaType] isEqual:mediaType] ) {
				return [[connection retain] autorelease];
			}
		}
	}
	return nil;
}

@end

@implementation AVCamCaptureManager (Internal)

- (AVCaptureDevice *) cameraWithPosition:(AVCaptureDevicePosition) position
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if ([device position] == position) {
            return device;
        }
    }
    return nil;
}

- (AVCaptureDevice *) frontFacingCamera
{
    return [self cameraWithPosition:AVCaptureDevicePositionFront];
}

- (AVCaptureDevice *) backFacingCamera
{
    return [self cameraWithPosition:AVCaptureDevicePositionBack];
}

- (AVCaptureDevice *) audioDevice
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio];
    if ([devices count] > 0) {
        return [devices objectAtIndex:0];
    }
    return nil;
}

- (NSURL *) tempFileURL
{
    NSString *outputPath = [[NSString alloc] initWithFormat:@"%@%@", NSTemporaryDirectory(), @"output.mov"];
    NSURL *outputURL = [[NSURL alloc] initFileURLWithPath:outputPath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:outputPath]) {
        NSError *error;
        if ([fileManager removeItemAtPath:outputPath error:&error] == NO) {
            id delegate = [self delegate];
            if ([delegate respondsToSelector:@selector(someOtherError:)]) {
                [delegate someOtherError:error];
            }            
        }
    }
    [outputPath release];
    return [outputURL autorelease];
}

@end


@implementation AVCamCaptureManager (AVCaptureFileOutputRecordingDelegate)

- (void)             captureOutput:(AVCaptureFileOutput *)captureOutput
didStartRecordingToOutputFileAtURL:(NSURL *)fileURL
                   fromConnections:(NSArray *)connections
{
    id delegate = [self delegate];
    if ([delegate respondsToSelector:@selector(recordingBegan)]) {
        [delegate recordingBegan];
    }
}

- (void)              captureOutput:(AVCaptureFileOutput *)captureOutput
didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL
                    fromConnections:(NSArray *)connections
                              error:(NSError *)error
{
    id delegate = [self delegate];
    if (error && [delegate respondsToSelector:@selector(someOtherError:)]) {
        [delegate someOtherError:error];
    }
    
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    if ([library videoAtPathIsCompatibleWithSavedPhotosAlbum:outputFileURL]) {
        [library writeVideoAtPathToSavedPhotosAlbum:outputFileURL
                                    completionBlock:^(NSURL *assetURL, NSError *error){
                                        if (error && [delegate respondsToSelector:@selector(assetLibraryError:forURL:)]) {
                                            [delegate assetLibraryError:error forURL:assetURL];
                                        }
                                    }];
    } else {
        if ([delegate respondsToSelector:@selector(cannotWriteToAssetLibrary)]) {
            [delegate cannotWriteToAssetLibrary];
        }
    }

    [library release];    
    
    if ([[UIDevice currentDevice] isMultitaskingSupported]) {
        [[UIApplication sharedApplication] endBackgroundTask:[self backgroundRecordingID]];
    }
    
    if ([delegate respondsToSelector:@selector(recordingFinished)]) {
        [delegate recordingFinished];
    }
}

@end
