/*
     File: AVCamCaptureManager.h
 Abstract: Code that calls the AVCapture classes to implement the camera-specific features in the app such as recording, still image, camera exposure, white balance and so on.
  Version: 1.0
  */

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <opencv/cv.h>


enum {
    AVCamMirroringOff   = 1,
    AVCamMirroringOn    = 2,
    AVCamMirroringAuto  = 3
};
typedef NSInteger AVCamMirroringMode;

@protocol AVCamCaptureManagerDelegate

@optional
- (void) captureStillImageFailedWithError:(NSError *)error;
- (void) acquiringDeviceLockFailedWithError:(NSError *)error;
- (void) cannotWriteToAssetLibrary;
- (void) assetLibraryError:(NSError *)error forURL:(NSURL *)assetURL;
- (void) someOtherError:(NSError *)error;
- (void) recordingBegan;
- (void) recordingFinished;
- (void) deviceCountChanged;
@end

@protocol PreviewImageViewDelegate

- (void) configureNewPreviewImage:(CGImageRef)newImage;

@end

@interface AVCamCaptureManager : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate> {
@private
    // Capture Session
    AVCaptureSession *_session;
    AVCaptureVideoOrientation _orientation;
    AVCamMirroringMode _mirroringMode;
    
    // Devic Inputs
    AVCaptureDeviceInput *_videoInput;
    AVCaptureDeviceInput *_audioInput;
    
    // Capture Outputs
    AVCaptureMovieFileOutput *_movieFileOutput;
    AVCaptureStillImageOutput *_stillImageOutput;
	AVCaptureVideoDataOutput *_videoDataOutput;
    
    // Identifiers for connect/disconnect notifications
    id _deviceConnectedObserver;
    id _deviceDisconnectedObserver;
    
    // Identifier for background completion of recording
    UIBackgroundTaskIdentifier _backgroundRecordingID; 
    
    // Capture Manager delegate
    id <AVCamCaptureManagerDelegate> _delegate;
	
	CGImageRef imageData;
	//OpenCV Image Data
	IplImage* pSrcImage;	
	IplImage* pDstImage;
	
	SystemSoundID timerSoundID;
	SystemSoundID shutterSoundID;
	
	id <PreviewImageViewDelegate> _previewImageDelegate; 
}

@property (nonatomic,readonly,retain) AVCaptureSession *session;
@property (nonatomic,assign) AVCaptureVideoOrientation orientation;
@property (nonatomic,readonly,retain) AVCaptureAudioChannel *audioChannel;
@property (nonatomic,assign) NSString *sessionPreset;
@property (nonatomic,assign) AVCamMirroringMode mirroringMode;
@property (nonatomic,readonly,retain) AVCaptureDeviceInput *videoInput;
@property (nonatomic,readonly,retain) AVCaptureDeviceInput *audioInput;
@property (nonatomic,assign) AVCaptureFlashMode flashMode;
@property (nonatomic,assign) AVCaptureTorchMode torchMode;
@property (nonatomic,assign) AVCaptureFocusMode focusMode;
@property (nonatomic,assign) AVCaptureExposureMode exposureMode;
@property (nonatomic,assign) AVCaptureWhiteBalanceMode whiteBalanceMode;
@property (nonatomic,readonly,retain) AVCaptureMovieFileOutput *movieFileOutput;
@property (nonatomic,assign) id <AVCamCaptureManagerDelegate> delegate;
@property (nonatomic,assign) id <PreviewImageViewDelegate> previewImageDelegate; 
@property (nonatomic,readonly,getter=isRecording) BOOL recording;


/*
 @ pointer to image data of current frame, used for further processing 
 */
@property (nonatomic, assign) CGImageRef imageData;

@property (nonatomic, assign) IplImage* pSrcImage;	
@property (nonatomic, assign) IplImage* pDstImage;

- (BOOL) setupSessionWithPreset:(NSString *)sessionPreset error:(NSError **)error;
- (void) startRecording;
- (void) stopRecording;
- (void) captureStillImage;
- (BOOL) cameraToggle;
- (NSUInteger) cameraCount;
- (NSUInteger) micCount;
- (BOOL) hasFlash;
- (BOOL) hasTorch;
- (BOOL) hasFocus;
- (BOOL) hasExposure;
- (BOOL) hasWhiteBalance;
- (void) focusAtPoint:(CGPoint)point;
- (void) exposureAtPoint:(CGPoint)point;
- (void) setConnectionWithMediaType:(NSString *)mediaType enabled:(BOOL)enabled;
- (BOOL) supportsMirroring;
+ (AVCaptureConnection *)connectionWithMediaType:(NSString *)mediaType fromConnections:(NSArray *)connections;

@end